// =============================================================================
// debounce.v - Sincronizador + antirrebote + detector de flanco para un botón
// -----------------------------------------------------------------------------
// Los KEY de la DE10-Lite son activos en bajo (presionado = 0).
//  1. Dos flip-flops sincronizan la señal asíncrona con el reloj.
//  2. El estado estable solo cambia si la entrada se mantiene distinta durante
//     DEBOUNCE_CYC ciclos (por defecto 10 ms a 50 MHz).
//  3. 'press' es un pulso de 1 ciclo en el instante en que el botón pasa a
//     presionado: una pulsación = un pulso, sin importar cuánto dure.
// =============================================================================
`timescale 1ns / 1ps

module debounce #(
    parameter integer DEBOUNCE_CYC = 500_000   // 10 ms @ 50 MHz
)(
    input  wire clk,
    input  wire rst,
    input  wire btn_n,     // botón crudo, activo en bajo
    output reg  pressed,   // nivel estable: 1 = presionado
    output reg  press      // pulso de 1 ciclo al presionar
);
    reg s0, s1;
    always @(posedge clk) begin
        if (rst) begin
            s0 <= 1'b1;
            s1 <= 1'b1;
        end else begin
            s0 <= btn_n;
            s1 <= s0;
        end
    end

    wire btn = ~s1;   // 1 = presionado (ya sincronizado)

    reg [19:0] cnt;
    always @(posedge clk) begin
        if (rst) begin
            cnt     <= 20'd0;
            pressed <= 1'b0;
            press   <= 1'b0;
        end else begin
            press <= 1'b0;
            if (btn == pressed) begin
                cnt <= 20'd0;                 // sin cambio: reinicia la cuenta
            end else if (cnt == DEBOUNCE_CYC - 1) begin
                cnt     <= 20'd0;
                pressed <= btn;               // cambio estable aceptado
                press   <= btn;               // flanco de subida -> pulso
            end else begin
                cnt <= cnt + 20'd1;
            end
        end
    end
endmodule
