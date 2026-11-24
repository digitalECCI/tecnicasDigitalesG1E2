// Incluye el diseño: basta con compilar este archivo
//   iverilog -o build\tb.out tb_caja_fuerte.v   y luego   vvp build\tb.out
`include "fsm_caja_fuerte.v"

`timescale 1ns/1ps

module tb_caja_fuerte;

    reg clk;
    reg reset_n;
    reg enter_pulse;
    reg master_reset_pulse;
    reg [3:0] switches;

    wire servo_open;
    wire led_green;
    wire led_red;
    wire [1:0] attempts_left;
    wire [2:0] display_mode;
    wire [3:0] display_value;

    // Instancia de la FSM
    fsm_caja_fuerte #(
        .CLAVE_1(4'h3),
        .CLAVE_2(4'hA),
        .CLAVE_3(4'h7)
    ) DUT (
        .clk(clk),
        .reset_n(reset_n),
        .enter_pulse(enter_pulse),
        .master_reset_pulse(master_reset_pulse),
        .switches(switches),
        .servo_open(servo_open),
        .led_green(led_green),
        .led_red(led_red),
        .attempts_left(attempts_left),
        .display_mode(display_mode),
        .display_value(display_value)
    );

    // Generador de reloj
    always #10 clk = ~clk;

    // Generador de pulso de confirmacion
    task presionar_enter;
        begin
            @(negedge clk);
            enter_pulse = 1'b1;
            @(negedge clk);
            enter_pulse = 1'b0;
            @(negedge clk);
        end
    endtask

    // Ingreso de los tres digitos
    task ingresar_clave;
        input [3:0] d1;
        input [3:0] d2;
        input [3:0] d3;
        begin
            switches = d1;
            presionar_enter();

            switches = d2;
            presionar_enter();

            switches = d3;
            presionar_enter();

            repeat (3) @(negedge clk);
        end
    endtask

    // Pruebas
    initial begin

        // Crear archivo de formas de onda
        $dumpfile("caja_fuerte.vcd");
        $dumpvars(0, tb_caja_fuerte);

        clk = 0;
        reset_n = 0;
        enter_pulse = 0;
        master_reset_pulse = 0;
        switches = 0;

        // Reinicio inicial
        repeat (3) @(negedge clk);
        reset_n = 1;

        // PRUEBA 1: clave correcta
        $display("PRUEBA 1: CLAVE CORRECTA");

        ingresar_clave(4'h3, 4'hA, 4'h7);

        if (servo_open && led_green && !led_red)
            $display("CORRECTO: CAJA ABIERTA");
        else
            $display("ERROR: NO ABRIO");

        // Reinicio para probar los errores
        @(negedge clk);
        reset_n = 0;
        repeat (2) @(negedge clk);
        reset_n = 1;

        // PRUEBA 2: primer error
        $display("PRUEBA 2: PRIMER ERROR");

        ingresar_clave(4'h1, 4'h2, 4'h3);

        if (attempts_left == 2)
            $display("CORRECTO: QUEDAN 2 INTENTOS");
        else
            $display("ERROR EN EL CONTADOR");

        // PRUEBA 3: segundo error
        $display("PRUEBA 3: SEGUNDO ERROR");

        ingresar_clave(4'h1, 4'h2, 4'h3);

        if (attempts_left == 1)
            $display("CORRECTO: QUEDA 1 INTENTO");
        else
            $display("ERROR EN EL CONTADOR");

        // PRUEBA 4: tercer error
        $display("PRUEBA 4: TERCER ERROR");

        ingresar_clave(4'h1, 4'h2, 4'h3);

        if (led_red && !servo_open && attempts_left == 0)
            $display("CORRECTO: CAJA BLOQUEADA");
        else
            $display("ERROR: NO SE BLOQUEO");

        $display("FIN DE LAS PRUEBAS");

        #100;
        $finish;

    end

endmodule