// =============================================================================
// caja_fuerte.v - Módulo superior: caja fuerte digital con servo | DE10-Lite
// -----------------------------------------------------------------------------
//   SW[3:0] -> dígito de la clave (0..F)
//   KEY[0]  -> enter: confirma el dígito (también cierra la caja si está abierta)
//   KEY[1]  -> reset maestro: vuelve al inicio con 3 intentos (sale de BLOQUEO)
//
//   GPIO[0] -> señal PWM del servo (cable naranja del SG90)
//   GPIO[1] -> LED verde externo (acceso concedido)
//   GPIO[2] -> LED rojo externo  (fijo en ERROR, parpadea a 1 Hz en BLOQUEO)
//
//   LEDR[9] -> copia del LED rojo     LEDR[8] -> copia del LED verde
//   LEDR[7] -> servo abierto          LEDR[2:0] -> intentos restantes (barra)
//   HEX5..HEX0 -> mensajes (ver msg_display.v)
//
// La FSM (fsm_caja_fuerte.v) no se modifica. Este módulo le agrega lo que va
// alrededor: antirrebote de los botones, sincronización de los switches, PWM
// del servo, mensajes en los displays, parpadeo del LED rojo y la indicación de
// ERROR ("Int. n" + LED rojo durante ERROR_CYCLES después de una clave errada).
// =============================================================================
`timescale 1ns / 1ps
// Con Icarus Verilog (__ICARUS__) se incluyen los submódulos para poder
// compilar este archivo solo. Quartus no define __ICARUS__: allí los archivos
// se toman del .qsf.
`ifdef __ICARUS__
`include "fsm_caja_fuerte.v"
`include "servo_pwm.v"
`include "msg_display.v"
`include "debounce.v"
`include "clk_divider.v"
`endif
`timescale 1ns / 1ps

module caja_fuerte #(
    parameter integer CLK_HZ          = 50_000_000,
    parameter integer DEBOUNCE_CYCLES = CLK_HZ / 100,   // 10 ms
    parameter integer ERROR_CYCLES    = 2 * CLK_HZ,     // 2 s mostrando "Int. n"
    parameter integer BLINK_TICK_HZ   = 2,              // 2 cambios/s -> 1 Hz
    // Combinación secreta: 3 - A - 7
    parameter [3:0]   CLAVE_1         = 4'h3,
    parameter [3:0]   CLAVE_2         = 4'hA,
    parameter [3:0]   CLAVE_3         = 4'h7
)(
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,
    input  wire [9:0] SW,
    output wire [9:0] LEDR,
    output wire [7:0] HEX0,
    output wire [7:0] HEX1,
    output wire [7:0] HEX2,
    output wire [7:0] HEX3,
    output wire [7:0] HEX4,
    output wire [7:0] HEX5,
    output wire [2:0] GPIO
);
    wire clk = MAX10_CLK1_50;

    // ---- Reset de encendido (power-on reset) -------------------------------
    reg [3:0] por = 4'd0;
    always @(posedge clk)
        if (!por[3]) por <= por + 4'd1;
    wire rst_n = por[3];

    // ---- Entradas del usuario ----------------------------------------------
    wire key0_press, key1_press;
    debounce #(.CYCLES(DEBOUNCE_CYCLES)) u_deb_enter (
        .clk(clk), .rst_n(rst_n), .btn_n(KEY[0]), .press(key0_press)
    );
    debounce #(.CYCLES(DEBOUNCE_CYCLES)) u_deb_reset (
        .clk(clk), .rst_n(rst_n), .btn_n(KEY[1]), .press(key1_press)
    );

    reg [3:0] sw_s0, sw_s1;                  // sincronizador de 2 flip-flops
    always @(posedge clk) begin
        sw_s0 <= SW[3:0];
        sw_s1 <= sw_s0;
    end

    // ---- Máquina de estados (sin cambios) ----------------------------------
    wire       servo_open, led_green, led_red;
    wire [1:0] attempts_left;
    wire [2:0] display_mode;
    wire [3:0] display_value;
    reg        error;
    wire       enter_pulse = key0_press & ~error;   // KEY0 se ignora en ERROR

    fsm_caja_fuerte #(
        .CLAVE_1(CLAVE_1), .CLAVE_2(CLAVE_2), .CLAVE_3(CLAVE_3)
    ) u_fsm (
        .clk(clk),
        .reset_n(rst_n),
        .enter_pulse(enter_pulse),
        .master_reset_pulse(key1_press),
        .switches(sw_s1),
        .servo_open(servo_open),
        .led_green(led_green),
        .led_red(led_red),
        .attempts_left(attempts_left),
        .display_mode(display_mode),
        .display_value(display_value)
    );

    // Alias para la simulación y para el informe
    wire [2:0] state = display_mode;        // display_mode = código de estado

    // ---- Indicación de ERROR -----------------------------------------------
    // Cuando attempts_left baja (clave errada) y aún quedan intentos, se
    // muestra "Int. n" con el LED rojo encendido durante ERROR_CYCLES.
    localparam integer WE = $clog2(ERROR_CYCLES + 1);
    reg [1:0]    att_prev;
    reg [WE-1:0] err_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            att_prev <= 2'd3;
            error    <= 1'b0;
            err_cnt  <= {WE{1'b0}};
        end else begin
            att_prev <= attempts_left;
            if (key1_press) begin
                error   <= 1'b0;
                err_cnt <= {WE{1'b0}};
            end else if (attempts_left < att_prev && attempts_left != 2'd0) begin
                error   <= 1'b1;
                err_cnt <= {WE{1'b0}};
            end else if (error) begin
                if (err_cnt == ERROR_CYCLES - 1) error <= 1'b0;
                else                             err_cnt <= err_cnt + 1'b1;
            end
        end
    end

    // ---- Parpadeo de 1 Hz para el LED rojo en BLOQUEO -----------------------
    wire tick;
    reg  blink;
    clk_divider #(.CLK_HZ(CLK_HZ), .TICK_HZ(BLINK_TICK_HZ)) u_div (
        .clk(clk), .rst_n(rst_n), .tick(tick)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)    blink <= 1'b1;
        else if (tick) blink <= ~blink;
    end

    // ---- Servo -------------------------------------------------------------
    wire servo_pwm_out;
    servo_pwm #(.CLK_HZ(CLK_HZ)) u_pwm (
        .clk(clk), .rst_n(rst_n), .open(servo_open), .pwm(servo_pwm_out)
    );

    // ---- Displays ----------------------------------------------------------
    msg_display u_msg (
        .display_mode(display_mode),
        .display_value(display_value),
        .attempts_left(attempts_left),
        .error(error),
        .hex5(HEX5), .hex4(HEX4), .hex3(HEX3),
        .hex2(HEX2), .hex1(HEX1), .hex0(HEX0)
    );

    // ---- Salidas -----------------------------------------------------------
    wire red   = error | (led_red & blink);
    wire green = led_green;

    assign GPIO[0] = servo_pwm_out;
    assign GPIO[1] = green;
    assign GPIO[2] = red;

    assign LEDR[9]   = red;
    assign LEDR[8]   = green;
    assign LEDR[7]   = servo_open;
    assign LEDR[6:3] = 4'b0000;
    assign LEDR[2:0] = { attempts_left == 2'd3,
                         attempts_left >= 2'd2,
                         attempts_left >= 2'd1 };
endmodule
