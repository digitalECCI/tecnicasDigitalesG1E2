// =============================================================================
// semaforo.v - Módulo superior: semáforo vehicular + peatonal | DE10-Lite
// -----------------------------------------------------------------------------
//   KEY[1]  -> reset (activo en bajo)
//   KEY[0]  -> botón peatonal (bonus)
//
//   GPIO[0] -> rojo vehicular        GPIO[3] -> rojo peatonal
//   GPIO[1] -> amarillo vehicular    GPIO[4] -> verde peatonal
//   GPIO[2] -> verde vehicular       GPIO[5] -> buzzer PASIVO (tono)
//                                    GPIO[6] -> buzzer ACTIVO (on/off)
//
//   LEDR[9:7] -> R Y G vehicular (copia en los LEDs de la placa)
//   LEDR[1:0] -> R G peatonal
//   LEDR[4]   -> solicitud peatonal pendiente
//   LEDR[3]   -> alarma sonando
//   HEX1:HEX0 -> segundos restantes del estado actual
// =============================================================================
`timescale 1ns / 1ps
// Con Icarus Verilog (__ICARUS__) se incluyen los submódulos para poder
// compilar este archivo solo, p. ej. con el botón de la extensión de VS Code.
// Quartus no define __ICARUS__: allí los archivos se toman del .qsf.
`ifdef __ICARUS__
`include "clk_divider.v"
`include "traffic_light.v"
`include "debounce.v"
`include "ped_alarm.v"
`include "display7seg.v"
`endif
`timescale 1ns / 1ps

module semaforo #(
    parameter integer CLK_HZ          = 50_000_000,
    parameter integer DEBOUNCE_CYCLES = CLK_HZ / 100,   // 10 ms
    parameter integer TONE_HZ         = 2000,
    parameter integer BEEP_HZ         = 4
)(
    input  wire        MAX10_CLK1_50,
    input  wire [1:0]  KEY,
    output wire [9:0]  LEDR,
    output wire [7:0]  HEX0,
    output wire [7:0]  HEX1,
    output wire [6:0]  GPIO
);
    wire clk = MAX10_CLK1_50;

    // ---- Reset: asíncrono al activar, síncrono al liberar ------------------
    reg [1:0] rst_sync;
    always @(posedge clk or negedge KEY[1]) begin
        if (!KEY[1]) rst_sync <= 2'b00;
        else         rst_sync <= {rst_sync[0], 1'b1};
    end
    wire rst_n = rst_sync[1];

    // ---- Base de tiempo de 1 s ---------------------------------------------
    wire tick;
    clk_divider #(.CLK_HZ(CLK_HZ), .TICK_HZ(1)) u_div (
        .clk(clk), .rst_n(rst_n), .tick(tick)
    );

    // ---- Máquina de estados ------------------------------------------------
    wire car_r, car_y, car_g, ped_r, ped_g;
    wire [1:0] state;
    wire [4:0] remaining;
    traffic_light u_fsm (
        .clk(clk), .rst_n(rst_n), .tick(tick),
        .car_r(car_r), .car_y(car_y), .car_g(car_g),
        .ped_r(ped_r), .ped_g(ped_g),
        .state_o(state), .remaining(remaining)
    );

    // ---- Bonus: botón peatonal + alarma ------------------------------------
    wire press, req, tone, beep;
    debounce #(.CYCLES(DEBOUNCE_CYCLES)) u_btn (
        .clk(clk), .rst_n(rst_n), .btn_n(KEY[0]), .press(press)
    );
    ped_alarm #(.CLK_HZ(CLK_HZ), .TONE_HZ(TONE_HZ), .BEEP_HZ(BEEP_HZ)) u_alarm (
        .clk(clk), .rst_n(rst_n), .press(press), .ped_g(ped_g),
        .req(req), .tone(tone), .beep(beep)
    );

    // ---- Salidas -----------------------------------------------------------
    assign GPIO = {beep, tone, ped_g, ped_r, car_g, car_y, car_r};
    assign LEDR = {car_r, car_y, car_g, 1'b0, 1'b0, req, req & ped_g, 1'b0, ped_r, ped_g};

    // Display: segundos restantes (00..31)
    wire [4:0] tens5  = remaining / 5'd10;
    wire [4:0] units5 = remaining % 5'd10;
    display7seg u_hex0 (.d(units5[3:0]), .blank(1'b0),            .seg(HEX0[6:0]));
    display7seg u_hex1 (.d(tens5[3:0]),  .blank(tens5 == 5'd0),   .seg(HEX1[6:0]));
    assign HEX0[7] = 1'b1;   // punto decimal apagado
    assign HEX1[7] = 1'b1;
endmodule
