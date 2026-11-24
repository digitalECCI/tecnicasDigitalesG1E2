// =============================================================================
// tb_caja_fuerte_top.v - Testbench autoverificable del sistema completo
// -----------------------------------------------------------------------------
// Prueba caja_fuerte.v (FSM + PWM + displays + LEDs) con los 3 escenarios de
// la guía y mide el ancho del pulso PWM en milisegundos.
//
// El reloj es el real (50 MHz) para que el PWM tenga sus tiempos reales
// (20 ms / 1 ms / 2 ms). Solo se acortan el antirrebote, la ventana de ERROR y
// el parpadeo, que en la placa duran milisegundos o segundos.
//
//   iverilog -g2005 -o sim\tb_top.vvp tb_caja_fuerte_top.v
//   vvp sim\tb_top.vvp
// =============================================================================
`timescale 1ns / 1ps
`include "caja_fuerte.v"
`timescale 1ns / 1ps

module tb_caja_fuerte_top;

    localparam integer DEB   = 20;      // antirrebote (ciclos)
    localparam integer ERR   = 3000;    // ventana de ERROR (ciclos) = 60 us
    localparam integer BLINK = 50_000;  // tick cada 1000 ciclos -> parpadeo de 40 us

    reg        clk = 1'b0;
    reg  [1:0] KEY = 2'b11;
    reg  [9:0] SW  = 10'd0;
    wire [9:0] LEDR;
    wire [7:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    wire [2:0] GPIO;

    caja_fuerte #(
        .DEBOUNCE_CYCLES(DEB),
        .ERROR_CYCLES(ERR),
        .BLINK_TICK_HZ(BLINK)
    ) dut (
        .MAX10_CLK1_50(clk), .KEY(KEY), .SW(SW), .LEDR(LEDR),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
        .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5),
        .GPIO(GPIO)
    );

    always #10 clk = ~clk;              // 50 MHz

    wire pwm   = GPIO[0];
    wire green = GPIO[1];
    wire red   = GPIO[2];

    // ---- Decodificador de los displays a texto (para leer y verificar) -----
    function [7:0] seg2ch;
        input [7:0] hex;                // activo en bajo
        case (~hex[6:0])
            7'h00: seg2ch = " ";  7'h40: seg2ch = "-";
            7'h77: seg2ch = "A";  7'h7C: seg2ch = "b";  7'h58: seg2ch = "c";
            7'h5E: seg2ch = "d";  7'h79: seg2ch = "E";  7'h30: seg2ch = "I";
            7'h38: seg2ch = "L";  7'h54: seg2ch = "n";  7'h3F: seg2ch = "O";
            7'h67: seg2ch = "q";  7'h6D: seg2ch = "S";  7'h78: seg2ch = "t";
            7'h1C: seg2ch = "u";  7'h06: seg2ch = "1";  7'h5B: seg2ch = "2";
            7'h4F: seg2ch = "3";  7'h66: seg2ch = "4";  7'h7D: seg2ch = "6";
            7'h07: seg2ch = "7";  7'h7F: seg2ch = "8";  7'h6F: seg2ch = "9";
            7'h39: seg2ch = "C";  7'h71: seg2ch = "F";
            default: seg2ch = "?";
        endcase
    endfunction

    reg [8*6-1:0] msg;                  // texto de HEX5..HEX0 (se ve en GTKWave)
    always @(*) msg = {seg2ch(HEX5), seg2ch(HEX4), seg2ch(HEX3),
                       seg2ch(HEX2), seg2ch(HEX1), seg2ch(HEX0)};

    // ---- Utilidades --------------------------------------------------------
    integer pass = 0, fail = 0;

    task check;
        input       ok;
        input [8*56-1:0] what;
        begin
            if (ok) begin pass = pass + 1; $display("%0s  PASS", what); end
            else    begin fail = fail + 1; $display("%0s  ** FALLA **", what); end
        end
    endtask

    task press;                         // pulsa y suelta un KEY (activo en bajo)
        input integer k;
        begin
            KEY[k] = 1'b0;
            repeat (DEB * 3) @(posedge clk);
            KEY[k] = 1'b1;
            repeat (DEB * 3) @(posedge clk);
        end
    endtask

    task digit;                         // fija SW3..SW0 y confirma con KEY0
        input [3:0] d;
        begin
            SW[3:0] = d;
            repeat (10) @(posedge clk);
            press(0);
        end
    endtask

    task clave;
        input [3:0] d1, d2, d3;
        begin digit(d1); digit(d2); digit(d3); end
    endtask

    real t_rise, t_fall, t_next, w_ms, p_ms;
    task measure_pwm;                   // ancho y periodo del siguiente pulso
        begin
            @(posedge pwm); t_rise = $realtime;
            @(negedge pwm); t_fall = $realtime;
            @(posedge pwm); t_next = $realtime;
            w_ms = (t_fall - t_rise) / 1.0e6;
            p_ms = (t_next - t_rise) / 1.0e6;
            $display("   PWM: pulso = %0.3f ms, periodo = %0.3f ms", w_ms, p_ms);
        end
    endtask

    function near;                      // |a - b| < 1 us
        input real a, b;
        near = (a - b < 0.001) && (b - a < 0.001);
    endfunction

    integer toggles;
    reg     red_prev;

    // ---- Pruebas -----------------------------------------------------------
    initial begin
        $dumpfile("tb_caja_fuerte_top.vcd");
        $dumpvars(0, KEY, SW, msg, pwm, green, red, LEDR,
                  dut.state, dut.attempts_left, dut.error, dut.enter_pulse,
                  dut.key0_press, dut.key1_press, dut.servo_open, dut.u_pwm.width);

        SW[3:0] = 4'h0;
        repeat (50) @(posedge clk);

        $display("=== Encendido ===");
        check(dut.state == 0 && dut.attempts_left == 3 && LEDR[2:0] == 3'b111,
              "Inicia esperando el digito 1 con 3 intentos");
        check(msg == "d1 O  ", "Display: \"d1 X\" con el valor de los switches");
        measure_pwm;
        check(near(w_ms, 1.0) && near(p_ms, 20.0), "Servo CERRADO: pulso de 1 ms cada 20 ms");

        // ------------------------------------------------------------------
        $display("=== Escenario 1: combinacion correcta 3-A-7 ===");
        digit(4'h3);
        SW[3:0] = 4'hA; repeat (10) @(posedge clk);
        check(dut.state == 1 && msg == "d2 -A ", "Digito 1 capturado, se oculta con \"-\"");
        press(0);
        SW[3:0] = 4'h7; repeat (10) @(posedge clk);
        check(dut.state == 2 && msg == "d3 --7", "Digito 2 capturado");
        press(0);
        check(dut.state == 3 && msg == "AccESO", "Estado ABIERTO con mensaje \"AccESO\"");
        check(green && !red && LEDR[7], "LED verde encendido, LED rojo apagado");
        measure_pwm;
        check(near(w_ms, 2.0) && near(p_ms, 20.0), "Servo ABIERTO: pulso de 2 ms cada 20 ms");

        press(1);
        check(dut.state == 0 && !green && dut.attempts_left == 3, "KEY1 cierra la caja y vuelve al inicio");
        measure_pwm;
        check(near(w_ms, 1.0), "El servo vuelve a CERRADO (1 ms)");

        // ------------------------------------------------------------------
        $display("=== Escenario 2: combinacion incorrecta 1-2-3 ===");
        clave(4'h1, 4'h2, 4'h3);
        check(dut.error && red && !green, "ERROR: LED rojo encendido");
        check(dut.attempts_left == 2 && LEDR[2:0] == 3'b011, "Se descuenta un intento (quedan 2)");
        check(msg == "Int  2" && !HEX3[7], "Display \"Int.  2\"");
        press(0);
        check(dut.state == 0, "KEY0 se ignora mientras se muestra el error");
        wait (!dut.error);
        repeat (5) @(posedge clk);
        check(!red && dut.state == 0 && msg[8*6-1:8*4] == "d1", "Termina el aviso y pide de nuevo el digito 1");

        clave(4'h1, 4'h2, 4'h3);
        check(dut.attempts_left == 1 && msg == "Int  1" && red, "Segundo error: \"Int.  1\"");
        wait (!dut.error);
        repeat (5) @(posedge clk);

        // ------------------------------------------------------------------
        $display("=== Escenario 3: tres fallos ===");
        clave(4'h1, 4'h2, 4'h3);
        check(dut.state == 4 && dut.attempts_left == 0 && msg == "bLOquE",
              "Estado BLOQUEO con mensaje \"bLOquE\"");
        toggles = 0; red_prev = red;
        repeat (10_000) begin
            @(posedge clk);
            if (red != red_prev) toggles = toggles + 1;
            red_prev = red;
        end
        check(toggles >= 8 && !green, "LED rojo parpadea en BLOQUEO");
        clave(4'h3, 4'hA, 4'h7);
        check(dut.state == 4, "En BLOQUEO ni la clave correcta abre");
        measure_pwm;
        check(near(w_ms, 1.0), "Servo sigue CERRADO (1 ms)");

        press(1);
        check(dut.state == 0 && dut.attempts_left == 3 && !red, "KEY1 (reset maestro) sale de BLOQUEO");
        clave(4'h3, 4'hA, 4'h7);
        check(dut.state == 3 && green, "Tras el reset la clave correcta abre de nuevo");

        // ------------------------------------------------------------------
        $display("--------------------------------------------------------------");
        if (fail == 0) $display(" RESULTADO: %0d pruebas, TODAS PASARON", pass);
        else           $display(" RESULTADO: %0d pasaron, %0d FALLARON", pass, fail);
        #1000;
        $finish;
    end
endmodule
