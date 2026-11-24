// =============================================================================
// servo_pwm.v - Generador PWM de 50 Hz para el servomotor SG90 (cerrojo)
// -----------------------------------------------------------------------------
// Con el reloj de 50 MHz (20 ns):
//   Periodo 20 ms -> 20 ms / 20 ns = 1 000 000 cuentas  (contador de 20 bits)
//   Pulso   1 ms  ->  1 ms / 20 ns =    50 000 cuentas  (~0°,  CERRADO)
//   Pulso   2 ms  ->  2 ms / 20 ns =   100 000 cuentas  (~90°, ABIERTO)
//
// pwm = 1 mientras cnt < width. El ancho solo se actualiza al empezar un nuevo
// periodo, así nunca se genera un pulso recortado cuando cambia 'open'.
// =============================================================================
`timescale 1ns / 1ps

module servo_pwm #(
    parameter integer CLK_HZ    = 50_000_000,
    parameter integer PERIOD_US = 20_000,      // 20 ms -> 50 Hz
    parameter integer CLOSED_US = 1_000,       // 1 ms  -> cerrado
    parameter integer OPEN_US   = 2_000        // 2 ms  -> abierto
)(
    input  wire clk,
    input  wire rst_n,
    input  wire open,       // 1 = cerrojo abierto
    output reg  pwm
);
    localparam integer CYC_US   = CLK_HZ / 1_000_000;    // 50 ciclos por us
    localparam integer PERIOD   = CYC_US * PERIOD_US;    // 1 000 000
    localparam integer W_CLOSED = CYC_US * CLOSED_US;    //    50 000
    localparam integer W_OPEN   = CYC_US * OPEN_US;      //   100 000
    localparam integer W        = $clog2(PERIOD);        // 20 bits

    reg [W-1:0] cnt;
    reg [W-1:0] width;      // ancho del pulso del periodo actual (en cuentas)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt   <= {W{1'b0}};
            width <= W_CLOSED[W-1:0];
            pwm   <= 1'b0;
        end else begin
            if (cnt == PERIOD - 1) begin
                cnt   <= {W{1'b0}};
                width <= open ? W_OPEN[W-1:0] : W_CLOSED[W-1:0];
            end else begin
                cnt <= cnt + 1'b1;
            end
            pwm <= (cnt < width);
        end
    end
endmodule
