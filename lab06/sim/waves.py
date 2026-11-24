#!/usr/bin/env python3
"""
waves.py - Dibuja en SVG las formas de onda de la simulación (sin dependencias).

Uso (desde la carpeta del proyecto, después de correr la simulación):
    python sim/waves.py
Lee  sim/tb_caja_fuerte_top.vcd  y escribe las figuras en  docs/img/*.svg

El testbench usa el reloj real de 50 MHz, así que los tiempos del PWM son los
reales (20 ms, 1 ms, 2 ms). El antirrebote y la ventana de ERROR están
acortados, por eso el ingreso de la clave dura microsegundos.
"""
import os
import sys

VCD = os.path.join("sim", "tb_caja_fuerte_top.vcd")
OUT = os.path.join("docs", "img")

TB = "tb_caja_fuerte_top."
D = TB + "dut."
FSM = ["DIG1", "DIG2", "DIG3", "ABIERTA", "BLOQUEO"]
US, MS = 1_000_000, 1_000_000_000          # en ps

RED, GRN, BLUE, ORG = "#c62828", "#2e7d32", "#1565c0", "#e65100"


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
            i += 5
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


def changes(wave, t0=0, val=None):
    """Instantes > t0 en que la señal cambia (o pasa a tomar el valor val)."""
    out, prev = [], value_at(wave, t0)
    for tt, vv in wave:
        if tt <= t0:
            continue
        if vv != prev and (val is None or to_int(vv) == val):
            out.append(tt)
        prev = vv
    return out


def first_change(wave, t0=0, val=None):
    c = changes(wave, t0, val)
    return c[0] if c else None


# ----------------------------------------------------------------------------
# Dibujo
# ----------------------------------------------------------------------------
def fmt_value(v, kind):
    n = to_int(v)
    if n is None:
        return "x"
    if kind == "dec":
        return str(n)
    if kind == "hex":
        return "%X" % n
    if kind == "str":                      # vector de caracteres ASCII
        v = v.zfill((len(v) + 7) // 8 * 8)
        return '"%s"' % "".join(chr(int(v[k:k + 8], 2)) for k in range(0, len(v), 8))
    if isinstance(kind, list):
        return kind[n] if n < len(kind) else str(n)
    return v


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def render(waves, t0, t1, rows, title, out, unit, marks=None, width=1250):
    """rows: (etiqueta, señal, tipo[, color]); tipo = 'bit', 'bit:N', 'dec', 'hex',
    'str' o lista de nombres. unit = (ps por unidad, 'nombre')."""
    LBL, ROW, TOP, PAD = 170, 34, 46, 10
    plot_w = width - LBL - PAD
    h = TOP + ROW * len(rows) + 40
    X = lambda t: LBL + (t - t0) / (t1 - t0) * plot_w

    s = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
         'font-family="Consolas, monospace" font-size="12">' % (width, h),
         '<rect width="100%" height="100%" fill="#ffffff"/>',
         '<text x="10" y="22" font-size="15" font-weight="bold" '
         'font-family="Segoe UI, sans-serif">%s</text>' % esc(title)]

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
        # se juntan los tramos consecutivos con el mismo valor
        merged = []
        for p in pts:
            if not merged or merged[-1][1] != p[1]:
                merged.append(p)
        segs = [(merged[k][0], merged[k + 1][0] if k + 1 < len(merged) else t1, merged[k][1])
                for k in range(len(merged))]

        if kind == "bit":
            poly = []
            for (a, b, v) in segs:
                y = hi if v == "1" else lo
                if v == "1":
                    s.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" '
                             'fill-opacity="0.18"/>' % (X(a), hi, max(X(b) - X(a), 0.6), lo - hi, color))
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
                             'dominant-baseline="middle" fill="#1b4d1f" xml:space="preserve">%s</text>'
                             % ((xa + xb) / 2, mid, esc(txt)))

    ya = TOP + ROW * len(rows) + 8
    s.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#888"/>' % (LBL, ya, width - PAD, ya))
    upp, uname = unit
    for k in range(11):
        t = t0 + (t1 - t0) * k / 10
        x = X(t)
        s.append('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#888"/>' % (x, ya, x, ya + 4))
        s.append('<text x="%.1f" y="%d" text-anchor="middle" fill="#555" font-size="10">%.1f %s</text>'
                 % (x, ya + 16, t / upp, uname))
    s.append("</svg>")

    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(s))
    print("  ->", out)


# ----------------------------------------------------------------------------
def main():
    if not os.path.exists(VCD):
        sys.exit("No existe %s: primero corra la simulación." % VCD)
    w = read_vcd(VCD)
    os.makedirs(OUT, exist_ok=True)

    enters = changes(w[D + "enter_pulse"], 0, 1)
    t_open = first_change(w[D + "state"], 0, 3)              # primera apertura
    t_err = first_change(w[D + "error"], 0, 1)               # primer error
    t_err_end = first_change(w[D + "error"], t_err, 0)
    t_blk = first_change(w[D + "state"], 0, 4)               # bloqueo

    def enters_before(t, n=3):
        return [e for e in enters if e <= t][-n]

    # 1) Combinación correcta
    a = enters_before(t_open) - 4 * US
    render(w, a, t_open + 6 * US, [
        ("KEY0 (enter)",    TB + "KEY", "bit:0"),
        ("SW[3:0]",         TB + "SW", "hex"),
        ("enter_pulse",     D + "enter_pulse", "bit"),
        ("FSM estado",      D + "state", FSM),
        ("HEX5..HEX0",      TB + "msg", "str"),
        ("LED verde",       TB + "green", "bit", GRN),
        ("servo_open",      D + "servo_open", "bit", ORG),
    ], "Escenario 1: clave correcta 3-A-7 -> ABIERTA, LED verde y \"AccESO\"",
       os.path.join(OUT, "clave_correcta.svg"), (US, "us"),
       marks=[(t_open, "ABIERTA")])

    # 2) PWM del servo, cerrado -> abierto
    rises = changes(w[TB + "pwm"], 0, 1)
    falls = changes(w[TB + "pwm"], 0, 0)
    a, b = t_open - 22 * MS, t_open + 42 * MS
    marks = []
    for r in rises:
        if a <= r <= b:
            f = next(x for x in falls if x > r)
            marks.append((r, "pulso %.3f ms" % ((f - r) / MS)))
    render(w, a, b, [
        ("FSM estado",      D + "state", FSM),
        ("servo_open",      D + "servo_open", "bit", ORG),
        ("ancho (cuentas)", D + "u_pwm.width", "dec"),
        ("PWM (GPIO[0])",   TB + "pwm", "bit", BLUE),
    ], "PWM del servo: 1 ms (cerrado) -> 2 ms (abierto), periodo 20 ms",
       os.path.join(OUT, "pwm_servo.svg"), (MS, "ms"), marks=marks)

    # 3) Combinación incorrecta
    a = enters_before(t_err) - 4 * US
    render(w, a, t_err_end + 8 * US, [
        ("KEY0 (enter)",    TB + "KEY", "bit:0"),
        ("SW[3:0]",         TB + "SW", "hex"),
        ("enter_pulse",     D + "enter_pulse", "bit"),
        ("FSM estado",      D + "state", FSM),
        ("intentos",        D + "attempts_left", "dec"),
        ("error",           D + "error", "bit", RED),
        ("HEX5..HEX0",      TB + "msg", "str"),
        ("LED rojo",        TB + "red", "bit", RED),
    ], "Escenario 2: clave 1-2-3 errada -> intentos 3 -> 2, \"Int.  2\" y LED rojo (KEY0 ignorado)",
       os.path.join(OUT, "clave_incorrecta.svg"), (US, "us"),
       marks=[(t_err, "error"), (t_err_end, "fin del aviso")])

    # 4) Bloqueo
    a = enters_before(t_blk) - 4 * US
    render(w, a, t_blk + 260 * US, [
        ("KEY0 (enter)",    TB + "KEY", "bit:0"),
        ("SW[3:0]",         TB + "SW", "hex"),
        ("FSM estado",      D + "state", FSM),
        ("intentos",        D + "attempts_left", "dec"),
        ("HEX5..HEX0",      TB + "msg", "str"),
        ("LED rojo",        TB + "red", "bit", RED),
        ("LED verde",       TB + "green", "bit", GRN),
    ], "Escenario 3: tercer fallo -> BLOQUEO, \"bLOquE\", LED rojo intermitente; 3-A-7 ya no abre",
       os.path.join(OUT, "bloqueo.svg"), (US, "us"), marks=[(t_blk, "BLOQUEO")])


if __name__ == "__main__":
    main()
