// =============================================================================
// debounce.v - Sincronizador + antirrebote + detector de flanco de un KEY
// -----------------------------------------------------------------------------
// Los KEY de la DE10-Lite son activos en bajo. El botón pasa por 2 flip-flops
// (sincronizador) y debe quedarse estable CYCLES ciclos (10 ms a 50 MHz) para
// aceptarse. Cada pulsación produce UN solo pulso "press" de 1 ciclo.
// =============================================================================
`timescale 1ns / 1ps

module debounce #(
    parameter integer CYCLES = 500_000      // 10 ms a 50 MHz
)(
    input  wire clk,
    input  wire rst_n,
    input  wire btn_n,     // activo en bajo
    output reg  press
);
    localparam integer W = (CYCLES > 1) ? $clog2(CYCLES) : 1;

    reg         s0, s1;    // sincronizador de 2 flip-flops
    reg         stable;    // estado estable del botón (1 = presionado)
    reg [W-1:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s0 <= 1'b0; s1 <= 1'b0;
            stable <= 1'b0;
            cnt <= {W{1'b0}};
            press <= 1'b0;
        end else begin
            s0    <= ~btn_n;
            s1    <= s0;
            press <= 1'b0;
            if (s1 == stable) begin
                cnt <= {W{1'b0}};
            end else if (cnt == CYCLES - 1) begin
                cnt    <= {W{1'b0}};
                stable <= s1;
                press  <= s1;          // flanco de subida = pulsación
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end
endmodule
