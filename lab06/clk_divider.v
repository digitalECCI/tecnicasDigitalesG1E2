// =============================================================================
// clk_divider.v - Divisor de frecuencia: 50 MHz -> pulso de 1 Hz
// -----------------------------------------------------------------------------
// Entrega un pulso "tick" de UN ciclo de reloj cada 1/TICK_HZ segundos.
//
//   DIV = f_clk / f_tick = 50 000 000 / 1 = 50 000 000 cuentas (0..49 999 999)
//   Ancho del contador = ceil(log2(50 000 000)) = 26 bits
//
// Se genera un pulso de habilitación y no un "reloj lento": todo el diseño
// sigue en un solo dominio de reloj (50 MHz), como se recomienda en FPGA.
// =============================================================================
`timescale 1ns / 1ps

module clk_divider #(
    parameter integer CLK_HZ  = 50_000_000,
    parameter integer TICK_HZ = 1
)(
    input  wire clk,
    input  wire rst_n,
    output reg  tick
);
    localparam integer DIV = CLK_HZ / TICK_HZ;
    localparam integer W   = (DIV > 1) ? $clog2(DIV) : 1;

    reg [W-1:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt  <= {W{1'b0}};
            tick <= 1'b0;
        end else if (cnt == DIV - 1) begin
            cnt  <= {W{1'b0}};
            tick <= 1'b1;
        end else begin
            cnt  <= cnt + 1'b1;
            tick <= 1'b0;
        end
    end
endmodule
