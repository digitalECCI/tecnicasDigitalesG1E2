// =============================================================================
// tb_semaforo.v - Testbench autoverificable del semáforo vehicular + peatonal
// -----------------------------------------------------------------------------
// Para no simular 50 millones de ciclos por segundo se usa CLK_HZ = 20:
// 1 segundo del semáforo = 20 ciclos de reloj (200 ns simulados). La lógica
// es idéntica a la de la placa; solo cambian los parámetros de los divisores.
//
// Verifica:
//   1. Secuencia VERDE -> AMARILLO -> ROJO -> AMARILLO -> VERDE
//   2. Duraciones 10 s / 3 s / 10 s / 3 s
//   3. Seguridad (en cada ciclo): una sola luz por semáforo y verde peatonal
//      solo con rojo vehicular
//   4. Bonus: sin botón no suena; con botón suena solo en el verde peatonal
// =============================================================================
// Incluye el diseño completo: basta con compilar este archivo
//   iverilog -o build\tb.out tb_semaforo.v   y luego   vvp build\tb.out
`include "semaforo.v"

`timescale 1ns/1ps

module tb_semaforo;

    localparam integer CLK_HZ = 20;                 // 1 s = 20 ciclos
    localparam integer DEB    = 4;                  // antirrebote corto
    localparam integer T_V = 10, T_A = 3, T_R = 10;
    localparam integer CICLO = (T_V + T_A + T_R + T_A) * CLK_HZ;   // ciclos por vuelta

    reg        clk = 1'b0;
    reg  [1:0] KEY = 2'b11;          // botones sueltos (activos en bajo)
    wire [9:0] LEDR;
    wire [7:0] HEX0, HEX1;
    wire [6:0] GPIO;

    always #5 clk = ~clk;            // periodo 10 ns

    semaforo #(
        .CLK_HZ(CLK_HZ), .DEBOUNCE_CYCLES(DEB), .TONE_HZ(5), .BEEP_HZ(1)
    ) dut (
        .MAX10_CLK1_50(clk), .KEY(KEY), .LEDR(LEDR),
        .HEX0(HEX0), .HEX1(HEX1), .GPIO(GPIO)
    );

    wire car_r = GPIO[0], car_y = GPIO[1], car_g = GPIO[2];
    wire ped_r = GPIO[3], ped_g = GPIO[4];
    wire tone  = GPIO[5], beep  = GPIO[6];

    integer errors     = 0;   // errores totales
    integer tests      = 0;   // pruebas ejecutadas
    integer fails      = 0;   // pruebas fallidas
    integer ticks      = 0;   // segundos transcurridos en el estado actual
    integer seconds    = 0;   // tiempo total en segundos
    integer cambios    = 0;
    integer tone_edges = 0;
    integer err_mark;
    reg     checking   = 1'b0;
    reg [2:0] prev_car;
    reg       last_was_green;  // último color no amarillo: 1 = verde, 0 = rojo
    reg       tone_d = 1'b0;

    function [8*8-1:0] nombre(input [2:0] c);   // c = {r, y, g}
        case (c)
            3'b001: nombre = "VERDE";
            3'b010: nombre = "AMARILLO";
            3'b100: nombre = "ROJO";
            default: nombre = "INVALIDO";
        endcase
    endfunction

    function integer duracion(input [2:0] c);
        case (c)
            3'b001: duracion = T_V;
            3'b100: duracion = T_R;
            default: duracion = T_A;
        endcase
    endfunction

    task report(input [8*60-1:0] txt, input ok);
        begin
            tests = tests + 1;
            if (!ok) fails = fails + 1;
            $display("%0s  %0s", txt, ok ? "PASS" : "FAIL");
        end
    endtask

    // ---- Monitor: se evalúa en cada flanco de reloj -------------------------
    always @(posedge clk) if (checking) begin
        // 3. Invariantes de seguridad
        if ((car_r + car_y + car_g) != 1) begin
            errors = errors + 1;
            $display("  ERROR t=%0d s: vehicular no one-hot (R=%b Y=%b G=%b)", seconds, car_r, car_y, car_g);
        end
        if ((ped_r + ped_g) != 1) begin
            errors = errors + 1;
            $display("  ERROR t=%0d s: peatonal invalido", seconds);
        end
        if (ped_g && !car_r) begin
            errors = errors + 1;
            $display("  ERROR t=%0d s: verde peatonal sin rojo vehicular", seconds);
        end
        if (beep && !ped_g) begin
            errors = errors + 1;
            $display("  ERROR t=%0d s: alarma fuera del verde peatonal", seconds);
        end

        // 1 y 2. Secuencia y duraciones
        if ({car_r, car_y, car_g} != prev_car) begin
            cambios = cambios + 1;
            if (ticks != duracion(prev_car)) begin
                errors = errors + 1;
                $display("  ERROR: %0s duro %0d s (esperado %0d s)", nombre(prev_car), ticks, duracion(prev_car));
            end
            case (prev_car)
                3'b001, 3'b100:
                    if ({car_r, car_y, car_g} != 3'b010) begin
                        errors = errors + 1;
                        $display("  ERROR: tras %0s no vino AMARILLO", nombre(prev_car));
                    end
                3'b010:
                    if ({car_r, car_y, car_g} != (last_was_green ? 3'b100 : 3'b001)) begin
                        errors = errors + 1;
                        $display("  ERROR: tras AMARILLO vino %0s", nombre({car_r, car_y, car_g}));
                    end
            endcase
            if (car_g) last_was_green = 1'b1;
            if (car_r) last_was_green = 1'b0;
            $display("t=%3d s  vehicular=%-8s peatonal=%-5s (el anterior duro %0d s)",
                     seconds, nombre({car_r, car_y, car_g}), ped_g ? "VERDE" : "ROJO", ticks);
            prev_car = {car_r, car_y, car_g};
            ticks = 0;
        end
        if (dut.tick) begin
            ticks   = ticks + 1;
            seconds = seconds + 1;
        end

        // flancos de subida del tono del buzzer
        if (tone && !tone_d) tone_edges = tone_edges + 1;
        tone_d = tone;
    end

    // ---- Estímulos ----------------------------------------------------------
    initial begin
        $dumpfile("tb_semaforo.vcd");
        $dumpvars(0, KEY, LEDR, GPIO, HEX0, HEX1);
        $dumpvars(0, car_r, car_y, car_g, ped_r, ped_g, tone, beep);
        $dumpvars(0, dut.rst_n, dut.tick, dut.state, dut.remaining);
        $dumpvars(0, dut.u_fsm.timer, dut.u_fsm.done, dut.u_fsm.next_state);
        $dumpvars(0, dut.press, dut.req, dut.u_alarm.alarm_en);

        // Reset
        KEY[1] = 1'b0;
        repeat (5) @(posedge clk);
        KEY[1] = 1'b1;
        repeat (3) @(posedge clk);
        prev_car       = {car_r, car_y, car_g};
        last_was_green = car_g;
        report("Reset -> inicia en VERDE vehicular / ROJO peatonal       ", car_g && ped_r);
        checking = 1'b1;

        // Prueba 1: dos ciclos completos sin presionar el botón
        $display("=== Ciclo normal (2 vueltas, sin boton) ===");
        err_mark = errors;
        repeat (2 * CICLO) @(posedge clk);
        report("Secuencia, duraciones y seguridad en 2 vueltas           ", errors == err_mark);
        report("Sin boton la alarma no suena                             ", tone_edges == 0);

        // Prueba 2: el peatón presiona KEY0 durante el verde vehicular
        $display("=== Bonus: boton peatonal ===");
        wait (car_g);
        repeat (3 * CLK_HZ) @(posedge clk);
        $display("t=%3d s  >> el peaton presiona KEY0", seconds);
        KEY[0] = 1'b0;
        repeat (3 * DEB) @(posedge clk);
        KEY[0] = 1'b1;
        repeat (2) @(posedge clk);
        report("Se registra la solicitud (req = 1)                       ", dut.req === 1'b1);
        report("No suena antes del verde peatonal                        ", tone_edges == 0);

        wait (ped_g);
        wait (!ped_g);
        repeat (2) @(posedge clk);   // ped_alarm ve el flanco un ciclo después
        $display("t=%3d s  flancos de tono durante el verde peatonal: %0d", seconds, tone_edges);
        report("La alarma suena durante el verde peatonal                ", tone_edges > 0);
        report("Al terminar el verde se borra la solicitud               ", dut.req === 1'b0);

        // Prueba 3: una vuelta más sin botón -> silencio
        tone_edges = 0;
        err_mark   = errors;
        repeat (CICLO) @(posedge clk);
        report("Siguiente vuelta sin boton: silencio                     ", tone_edges == 0);
        report("Sin errores de seguridad en toda la simulacion           ", errors == 0);

        $display("--------------------------------------------------------------");
        $display("Cambios de estado verificados: %0d", cambios);
        if (fails == 0) $display(" RESULTADO: %0d pruebas, TODAS PASARON", tests);
        else            $display(" RESULTADO: %0d de %0d pruebas FALLARON", fails, tests);
        $finish;
    end

    initial begin
        #(20 * CICLO * 10);
        $display("ERROR: timeout");
        $finish;
    end
endmodule
