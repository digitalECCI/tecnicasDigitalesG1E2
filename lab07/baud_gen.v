// =============================================================================
// baud_gen.v - Generador de baudios (divisor de frecuencia)
// -----------------------------------------------------------------------------
// Produce dos trenes de pulsos de 1 ciclo de reloj:
//   baud_tick : 1 pulso por bit          -> lo usa el transmisor (TX)
//   os_tick   : OVERSAMPLE pulsos por bit -> lo usa el receptor (RX) para
//               sobremuestrear y leer cada bit en su centro.
//
//   DIV_BAUD = f_clk / baud              = 50 000 000 / 9600        ~ 5208
//   DIV_OS   = f_clk / (baud*OVERSAMPLE) = 50 000 000 / (9600*16)   ~ 326
// =============================================================================
`timescale 1ns / 1ps

module baud_gen #(
    parameter CLK_FREQ   = 50_000_000,
    parameter BAUD       = 9600,
    parameter OVERSAMPLE = 16
)(
    input  wire clk,
    input  wire rst,
    output reg  baud_tick,
    output reg  os_tick
);
    // División redondeada al entero más cercano
    localparam integer DIV_BAUD = (CLK_FREQ + BAUD/2) / BAUD;
    localparam integer DIV_OS   = (CLK_FREQ + (BAUD*OVERSAMPLE)/2) / (BAUD*OVERSAMPLE);

    reg [15:0] cnt_baud;
    reg [15:0] cnt_os;

    always @(posedge clk) begin
        if (rst) begin
            cnt_baud  <= 16'd0;
            cnt_os    <= 16'd0;
            baud_tick <= 1'b0;
            os_tick   <= 1'b0;
        end else begin
            // Contador de bit completo (TX)
            if (cnt_baud == DIV_BAUD - 1) begin
                cnt_baud  <= 16'd0;
                baud_tick <= 1'b1;
            end else begin
                cnt_baud  <= cnt_baud + 16'd1;
                baud_tick <= 1'b0;
            end

            // Contador de sobremuestreo (RX)
            if (cnt_os == DIV_OS - 1) begin
                cnt_os  <= 16'd0;
                os_tick <= 1'b1;
            end else begin
                cnt_os  <= cnt_os + 16'd1;
                os_tick <= 1'b0;
            end
        end
    end
endmodule
