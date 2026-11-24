// =============================================================================
// display7seg.v - Decodificador BCD -> 7 segmentos (DE10-Lite, activo en BAJO)
// -----------------------------------------------------------------------------
// seg[6:0] = {g, f, e, d, c, b, a}.  blank = 1 apaga el dígito.
// =============================================================================
`timescale 1ns / 1ps

module display7seg (
    input  wire [3:0] d,
    input  wire       blank,
    output reg  [6:0] seg
);
    always @(*) begin
        if (blank) seg = 7'b1111111;
        else case (d)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b0111111;   // guion
        endcase
    end
endmodule
