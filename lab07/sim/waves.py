#!/usr/bin/env python3
"""
waves.py - Dibuja en SVG las formas de onda de la simulación (sin dependencias).

Uso (desde la carpeta del proyecto, después de correr la simulación):
    python sim/waves.py
Lee  sim/tb_proyecto_uart.vcd  y escribe las figuras en  docs/img/*.svg
"""
import os
import sys

VCD = os.path.join("sim", "tb_proyecto_uart.vcd")
OUT = os.path.join("docs", "img")
BIT_PS = 1e12 / 9600          # duración de un bit en ps

TB = "tb_proyecto_uart."
FSM_TX = ["IDLE", "START", "DATA", "STOP"]
FSM_RX = ["IDLE", "START", "DATA", "STOP"]
FSM_SEQ = ["IDLE", "LOAD", "SEND", "WAIT"]


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


def first_negedge(wave, t0):
    prev = value_at(wave, t0)
    for tt, vv in wave:
        if tt <= t0:
            continue
        if prev == "1" and vv == "0":
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
    if kind == "hex":
        return "%02X" % n
    if kind == "bin":
        return v.zfill(10)
    if kind == "ascii":
        names = {0x0D: "\\r", 0x0A: "\\n", 0x7F: "DEL"}
        return names.get(n, "'%s'" % chr(n) if 32 <= n < 127 else "%02X" % n)
    if isinstance(kind, list):
        return kind[n] if n < len(kind) else str(n)
    return v


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def render(waves, t0, t1, rows, title, out, marks=None, width=1250):
    LBL, ROW, TOP, PAD = 190, 34, 46, 10
    plot_w = width - LBL - PAD
    h = TOP + ROW * len(rows) + 40
    X = lambda t: LBL + (t - t0) / (t1 - t0) * plot_w

    s = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
         'font-family="Consolas, monospace" font-size="12">' % (width, h),
         '<rect width="100%" height="100%" fill="#ffffff"/>',
         '<text x="10" y="22" font-size="15" font-weight="bold" '
         'font-family="Segoe UI, sans-serif">%s</text>' % esc(title)]

    # marcas verticales (centros de bit, eventos)
    for (tm, txt) in (marks or []):
        if t0 <= tm <= t1:
            x = X(tm)
            s.append('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#d0d7e2" '
                     'stroke-dasharray="3,3"/>' % (x, TOP - 6, x, h - 30))
            s.append('<text x="%.1f" y="%d" text-anchor="middle" fill="#5a6b85" '
                     'font-size="10">%s</text>' % (x, TOP - 9, esc(txt)))

    for r, (label, name, kind) in enumerate(rows):
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
                poly += ["%.1f,%.1f" % (X(a), y), "%.1f,%.1f" % (X(b), y)]
            s.append('<polyline points="%s" fill="none" stroke="#1565c0" stroke-width="1.6"/>'
                     % " ".join(poly))
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

    # eje de tiempo
    ya = TOP + ROW * len(rows) + 8
    s.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#888"/>' % (LBL, ya, width - PAD, ya))
    span = t1 - t0
    for k in range(11):
        t = t0 + span * k / 10
        x = X(t)
        s.append('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#888"/>' % (x, ya, x, ya + 4))
        lbl = "%.3f ms" % (t / 1e9) if span > 2e9 else "%.1f us" % (t / 1e6)
        s.append('<text x="%.1f" y="%d" text-anchor="middle" fill="#555" font-size="10">%s</text>'
                 % (x, ya + 16, lbl))
    s.append("</svg>")

    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(s))
    print("  ->", out)


def frame_marks(t_start):
    names = ["START"] + ["D%d" % i for i in range(8)] + ["STOP"]
    return [(t_start + (i + 0.5) * BIT_PS, n) for i, n in enumerate(names)]


# ----------------------------------------------------------------------------
def main():
    if not os.path.exists(VCD):
        sys.exit("No existe %s: primero corra la simulación." % VCD)
    w = read_vcd(VCD)
    os.makedirs(OUT, exist_ok=True)
    D = TB + "dut."

    # Instantes de referencia buscados en el propio VCD
    t_tx = w[D + "send_press"][1][0]                  # 1er pulso de KEY0 (SW = 1023)
    t_rx = first_negedge(w[TB + "GPIO_RX"], 0)        # start del '5' de "512\r"

    # 1) FPGA -> PC: mensaje completo "1023\r\n"
    render(w, 0, t_tx + 6.5e9, [
        ("KEY0 (enviar)",      TB + "KEY", "bit:0"),
        ("SW (decimal)",       TB + "SW", "dec"),
        ("send_press",         D + "send_press", "bit"),
        ("tx_value",           D + "tx_value", "dec"),
        ("FSM secuenciador",   D + "q_state", FSM_SEQ),
        ("idx (byte)",         D + "idx", "dec"),
        ("tx_data",            D + "tx_data", "ascii"),
        ("tx_start",           D + "tx_start", "bit"),
        ("tx_done",            D + "tx_done", "bit"),
        ("FSM uart_tx",        D + "u_tx.state", FSM_TX),
        ("GPIO_TX",            TB + "GPIO_TX", "bit"),
    ], "FPGA -> PC: SW = 1023, se pulsa KEY0 y se transmite \"1023\\r\\n\"",
       os.path.join(OUT, "tx_mensaje.svg"))

    # 2) FPGA -> PC: zoom a la trama del primer byte '1' = 0x31
    tf = first_negedge(w[TB + "GPIO_TX"], t_tx)
    render(w, tf - 0.5 * BIT_PS, tf + 10.6 * BIT_PS, [
        ("baud_tick",          D + "baud_tick", "bit"),
        ("FSM uart_tx",        D + "u_tx.state", FSM_TX),
        ("bit_cnt",            D + "u_tx.bit_cnt", "dec"),
        ("tx_data",            D + "tx_data", "ascii"),
        ("GPIO_TX",            TB + "GPIO_TX", "bit"),
    ], "Trama TX del carácter '1' (0x31 = 0011 0001, LSB primero)",
       os.path.join(OUT, "tx_trama.svg"), marks=frame_marks(tf))

    # 3) PC -> FPGA: se escribe "512" + Enter
    render(w, t_rx - 0.15e9, t_rx + 5.6e9, [
        ("GPIO_RX",            TB + "GPIO_RX", "bit"),
        ("FSM uart_rx",        D + "u_rx.state", FSM_RX),
        ("rx_data",            D + "rx_data", "ascii"),
        ("rx_done",            D + "rx_done", "bit"),
        ("acc (dec2bin)",      D + "u_dec2bin.acc", "dec"),
        ("rx_valid",           D + "rx_valid", "bit"),
        ("LEDR (decimal)",     TB + "LEDR", "dec"),
        ("LEDR (binario)",     TB + "LEDR", "bin"),
    ], "PC -> FPGA: se escribe \"512\" + Enter en PuTTY y aparece 1000000000 en los LEDs",
       os.path.join(OUT, "rx_mensaje.svg"))

    # 4) PC -> FPGA: zoom a la trama de '5' = 0x35 con muestreo en el centro
    render(w, t_rx - 0.5 * BIT_PS, t_rx + 10.6 * BIT_PS, [
        ("GPIO_RX",            TB + "GPIO_RX", "bit"),
        ("rx_s (sincroniz.)",  D + "u_rx.rx_s", "bit"),
        ("FSM uart_rx",        D + "u_rx.state", FSM_RX),
        ("bit_cnt",            D + "u_rx.bit_cnt", "dec"),
        ("rx_done",            D + "rx_done", "bit"),
        ("rx_data",            D + "rx_data", "ascii"),
    ], "Trama RX del carácter '5' (0x35 = 0011 0101): cada bit se muestrea en su centro",
       os.path.join(OUT, "rx_trama.svg"), marks=frame_marks(t_rx))

    # 5) Full duplex: ambos sentidos a la vez
    t_fd = w[D + "send_press"][-1][0]
    render(w, t_fd - 0.3e9, t_fd + 5.0e9, [
        ("SW (decimal)",       TB + "SW", "dec"),
        ("tx_data",            D + "tx_data", "ascii"),
        ("GPIO_TX",            TB + "GPIO_TX", "bit"),
        ("GPIO_RX",            TB + "GPIO_RX", "bit"),
        ("rx_data",            D + "rx_data", "ascii"),
        ("LEDR (decimal)",     TB + "LEDR", "dec"),
    ], "Full duplex: se transmite \"999\" mientras se recibe \"640\"",
       os.path.join(OUT, "full_duplex.svg"))


if __name__ == "__main__":
    main()
