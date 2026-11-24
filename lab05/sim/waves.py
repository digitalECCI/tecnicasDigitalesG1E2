#!/usr/bin/env python3
"""
waves.py - Dibuja en SVG las formas de onda de la simulación (sin dependencias).

Uso (desde la carpeta del proyecto, después de correr la simulación):
    python sim/waves.py
Lee  sim/tb_semaforo.vcd  y escribe las figuras en  docs/img/*.svg

El testbench usa CLK_HZ = 20 con periodo de 10 ns: 1 s del semáforo equivale a
200 ns simulados. El eje de tiempo se muestra en segundos del semáforo.
"""
import os
import sys

VCD = os.path.join("sim", "tb_semaforo.vcd")
OUT = os.path.join("docs", "img")
SEC_PS = 20 * 10_000          # 1 s del semáforo = 20 ciclos x 10 ns, en ps

TB = "tb_semaforo."
D = TB + "dut."
FSM = ["VERDE", "AMAR→ROJO", "ROJO", "AMAR→VERDE"]

RED, YEL, GRN, BLUE = "#c62828", "#f9a825", "#2e7d32", "#1565c0"


# ----------------------------------------------------------------------------
# Lectura del VCD
# ----------------------------------------------------------------------------
def read_vcd(path):
    ids, waves, scope, t, unit = {}, {}, [], 0, 1
    with open(path) as f:
        tokens = f.read().split()
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok == "$timescale":
            spec = tokens[i + 1]
            num = int("".join(c for c in spec if c.isdigit()) or 1)
            mult = {"s": 1e12, "ms": 1e9, "us": 1e6, "ns": 1e3, "ps": 1, "fs": 1e-3}
            unit = num * mult["".join(c for c in spec if c.isalpha())]
            i += 2
        elif tok == "$scope":
            scope.append(tokens[i + 2]); i += 4
        elif tok == "$upscope":
            scope.pop(); i += 2
        elif tok == "$var":
            code, name = tokens[i + 3], tokens[i + 4]
            full = ".".join(scope + [name])
            ids.setdefault(code, []).append(full)
            waves[full] = []
            i += 6 if tokens[i + 5] != "$end" else 5
            while tokens[i - 1] != "$end":
                i += 1
        elif tok.startswith("#"):
            t = int(tok[1:]) * unit; i += 1
        elif tok[0] in "bB":
            val, code = tok[1:], tokens[i + 1]
            for n in ids.get(code, []):
                waves[n].append((t, val))
            i += 2
        elif tok[0] in "01xXzZ" and len(tok) > 1:
            for n in ids.get(tok[1:], []):
                waves[n].append((t, tok[0]))
            i += 1
        else:
            i += 1
    return waves


def value_at(wave, t):
    v = "x"
    for tt, vv in wave:
        if tt > t:
            break
        v = vv
    return v


def to_int(v):
    try:
        return int(v, 2)
    except ValueError:
        return None


def first_change(wave, t0, val=None):
    """Primer instante > t0 en que la señal cambia (o toma el valor val)."""
    prev = value_at(wave, t0)
    for tt, vv in wave:
        if tt <= t0:
            continue
        if vv != prev and (val is None or vv == val):
            return tt
        prev = vv
    return None


# ----------------------------------------------------------------------------
# Dibujo
# ----------------------------------------------------------------------------
def fmt_value(v, kind):
    n = to_int(v)
    if n is None:
        return "x"
    if kind == "dec":
        return str(n)
    if isinstance(kind, list):
        return kind[n] if n < len(kind) else str(n)
    return v


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def render(waves, t0, t1, rows, title, out, marks=None, width=1250):
    """rows: (etiqueta, señal, tipo[, color]); tipo = 'bit', 'dec' o lista de nombres."""
    LBL, ROW, TOP, PAD = 190, 34, 46, 10
    plot_w = width - LBL - PAD
    h = TOP + ROW * len(rows) + 40
    X = lambda t: LBL + (t - t0) / (t1 - t0) * plot_w

    s = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
         'font-family="Consolas, monospace" font-size="12">' % (width, h),
         '<rect width="100%" height="100%" fill="#ffffff"/>',
         '<text x="10" y="22" font-size="15" font-weight="bold" '
         'font-family="Segoe UI, sans-serif">%s</text>' % esc(title)]

    # marcas verticales (eventos)
    for (tm, txt) in (marks or []):
        if t0 <= tm <= t1:
            x = X(tm)
            s.append('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#d0d7e2" '
                     'stroke-dasharray="3,3"/>' % (x, TOP - 6, x, h - 30))
            s.append('<text x="%.1f" y="%d" text-anchor="middle" fill="#5a6b85" '
                     'font-size="10">%s</text>' % (x, TOP - 9, esc(txt)))

    for r, row in enumerate(rows):
        label, name, kind = row[:3]
        color = row[3] if len(row) > 3 else BLUE
        y0 = TOP + r * ROW
        hi, lo, mid = y0 + 6, y0 + ROW - 8, y0 + ROW / 2 - 1
        fill = "#f5f7fb" if r % 2 == 0 else "#ffffff"
        s.append('<rect x="0" y="%d" width="%d" height="%d" fill="%s"/>' % (y0, width, ROW, fill))
        s.append('<text x="10" y="%.1f" dominant-baseline="middle" fill="#1f2a3d">%s</text>'
                 % (mid, esc(label)))
        wave = waves[name]
        if isinstance(kind, str) and kind.startswith("bit:"):
            n = int(kind[4:])
            wave = [(t, (v.zfill(n + 1)[-(n + 1)] if v[0] in "01" else "x")) for t, v in wave]
            kind = "bit"
        pts = [(t0, value_at(wave, t0))] + [(t, v) for t, v in wave if t0 < t < t1]
        segs = [(pts[k][0], pts[k + 1][0] if k + 1 < len(pts) else t1, pts[k][1])
                for k in range(len(pts))]

        if kind == "bit":
            poly = []
            for (a, b, v) in segs:
                y = hi if v == "1" else lo
                if v == "1":   # relleno suave cuando la luz está encendida
                    s.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" '
                             'fill-opacity="0.18"/>' % (X(a), hi, X(b) - X(a), lo - hi, color))
                poly += ["%.1f,%.1f" % (X(a), y), "%.1f,%.1f" % (X(b), y)]
            s.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="1.6"/>'
                     % (" ".join(poly), color))
        else:
            for (a, b, v) in segs:
                xa, xb = X(a), X(b)
                e = min(3, (xb - xa) / 2)
                s.append('<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f" '
                         'fill="#e3f0e8" stroke="#2e7d32" stroke-width="1"/>'
                         % (xa, mid, xa + e, hi, xb - e, hi, xb, mid, xb - e, lo, xa + e, lo))
                txt = fmt_value(v, kind)
                if (xb - xa) > 7.2 * len(txt) + 6:
                    s.append('<text x="%.1f" y="%.1f" text-anchor="middle" '
                             'dominant-baseline="middle" fill="#1b4d1f">%s</text>'
                             % ((xa + xb) / 2, mid, esc(txt)))

    # eje de tiempo (segundos del semáforo)
    ya = TOP + ROW * len(rows) + 8
    s.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#888"/>' % (LBL, ya, width - PAD, ya))
    span = t1 - t0
    for k in range(11):
        t = t0 + span * k / 10
        x = X(t)
        s.append('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#888"/>' % (x, ya, x, ya + 4))
        lbl = "%.1f s" % (t / SEC_PS) if span > 5 * SEC_PS else "%.2f s" % (t / SEC_PS)
        s.append('<text x="%.1f" y="%d" text-anchor="middle" fill="#555" font-size="10">%s</text>'
                 % (x, ya + 16, lbl))
    s.append("</svg>")

    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(s))
    print("  ->", out)


def state_marks(w, t0, t1):
    marks, prev = [], value_at(w[D + "state"], t0)
    for t, v in w[D + "state"]:
        if t0 < t < t1 and v != prev:
            marks.append((t, "%.0f s" % (t / SEC_PS)))
        prev = v
    return marks


# ----------------------------------------------------------------------------
def main():
    if not os.path.exists(VCD):
        sys.exit("No existe %s: primero corra la simulación." % VCD)
    w = read_vcd(VCD)
    os.makedirs(OUT, exist_ok=True)

    t_rst = first_change(w[D + "rst_n"], 0, "1")            # se libera el reset
    t_v2a = first_change(w[D + "state"], t_rst)             # VERDE -> AMARILLO (10 s)
    t_press = first_change(w[D + "press"], 0, "1")          # pulsación de KEY0
    t_pg = first_change(w[TB + "ped_g"], t_press, "1")      # verde peatonal atendido
    t_pg_end = first_change(w[TB + "ped_g"], t_pg, "0")

    # 1) Ciclo completo del semáforo
    t1 = t_rst + 27 * SEC_PS
    render(w, 0, t1, [
        ("KEY1 (reset)",       TB + "KEY", "bit:1"),
        ("tick (1 Hz)",        D + "tick", "bit"),
        ("FSM estado",         D + "state", FSM),
        ("seg. restantes",     D + "remaining", "dec"),
        ("Vehicular ROJO",     TB + "car_r", "bit", RED),
        ("Vehicular AMARILLO", TB + "car_y", "bit", YEL),
        ("Vehicular VERDE",    TB + "car_g", "bit", GRN),
        ("Peatonal ROJO",      TB + "ped_r", "bit", RED),
        ("Peatonal VERDE",     TB + "ped_g", "bit", GRN),
    ], "Ciclo completo: VERDE 10 s -> AMARILLO 3 s -> ROJO 10 s -> AMARILLO 3 s",
       os.path.join(OUT, "ciclo.svg"), marks=state_marks(w, 0, t1))

    # 2) Zoom a la transición VERDE -> AMARILLO
    render(w, t_v2a - 2.4 * SEC_PS, t_v2a + 1.6 * SEC_PS, [
        ("tick (1 Hz)",        D + "tick", "bit"),
        ("timer",              D + "u_fsm.timer", "dec"),
        ("done",               D + "u_fsm.done", "bit"),
        ("next_state",         D + "u_fsm.next_state", FSM),
        ("state",              D + "state", FSM),
        ("Vehicular VERDE",    TB + "car_g", "bit", GRN),
        ("Vehicular AMARILLO", TB + "car_y", "bit", YEL),
    ], "Transición VERDE -> AMARILLO: con timer = 9 y tick, done = 1 y el estado cambia en el siguiente flanco",
       os.path.join(OUT, "transicion.svg"), marks=[(t_v2a, "cambio de estado")])

    # 3) Bonus: botón peatonal + alarma
    render(w, t_press - 1 * SEC_PS, t_pg_end + 1.5 * SEC_PS, [
        ("KEY0 (peatón)",      TB + "KEY", "bit:0"),
        ("press",              D + "press", "bit"),
        ("req (solicitud)",    D + "req", "bit"),
        ("FSM estado",         D + "state", FSM),
        ("Peatonal VERDE",     TB + "ped_g", "bit", GRN),
        ("alarm_en",           D + "u_alarm.alarm_en", "bit"),
        ("beep (buzzer act.)", TB + "beep", "bit"),
        ("tone (buzzer pas.)", TB + "tone", "bit"),
    ], "Bonus: se presiona KEY0 en verde vehicular; la alarma suena durante el verde peatonal",
       os.path.join(OUT, "bonus_alarma.svg"),
       marks=[(t_press, "press"), (t_pg, "verde peatonal"), (t_pg_end, "fin")])


if __name__ == "__main__":
    main()
