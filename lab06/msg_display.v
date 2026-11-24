// =============================================================================
// msg_display.v - Mensajes de la caja fuerte en HEX5..HEX0 (DE10-Lite)
// -----------------------------------------------------------------------------
// Displays activos en BAJO. Cada salida es {dp, g, f, e, d, c, b, a}.
//
//   Ingreso de clave (display_mode 0,1,2): "d1 X  " / "d2 -X " / "d3 --X"
//       HEX4 = número del dígito que se está ingresando
//       HEX2..HEX0 = un guion por cada dígito ya capturado (oculto, como un
//                    PIN) y el valor actual de SW3..SW0 en la posición actual
//   Error (error = 1)            : "Int.  n"   n = intentos restantes
//   Abierta (display_mode = 3)   : "AccESO"
//   Bloqueada (display_mode = 4) : "bLOquE"
// =============================================================================
`timescale 1ns / 1ps

module msg_display (
    input  wire [2:0] display_mode,   // de fsm_caja_fuerte
    input  wire [3:0] display_value,  // de fsm_caja_fuerte (SW3..SW0)
    input  wire [1:0] attempts_left,  // de fsm_caja_fuerte
    input  wire       error,          // mostrando "Int. n" tras una clave errada
    output wire [7:0] hex5, hex4, hex3, hex2, hex1, hex0
);
    // Patrones activos en ALTO {dp,g,f,e,d,c,b,a}
    localparam [7:0] CH_BLANK = 8'h00,
                     CH_DASH  = 8'h40,
                     CH_A     = 8'h77,
                     CH_b     = 8'h7C,
                     CH_c     = 8'h58,
                     CH_d     = 8'h5E,
                     CH_E     = 8'h79,
                     CH_I     = 8'h30,
                     CH_L     = 8'h38,
                     CH_n     = 8'h54,
                     CH_O     = 8'h3F,
                     CH_q     = 8'h67,
                     CH_S     = 8'h6D,
                     CH_t     = 8'h78,
                     CH_u     = 8'h1C,
                     DP       = 8'h80;

    function [7:0] hexdig;            // 0..F en 7 segmentos (activo en alto)
        input [3:0] v;
        case (v)
            4'h0: hexdig = 8'h3F;  4'h1: hexdig = 8'h06;
            4'h2: hexdig = 8'h5B;  4'h3: hexdig = 8'h4F;
            4'h4: hexdig = 8'h66;  4'h5: hexdig = 8'h6D;
            4'h6: hexdig = 8'h7D;  4'h7: hexdig = 8'h07;
            4'h8: hexdig = 8'h7F;  4'h9: hexdig = 8'h6F;
            4'hA: hexdig = 8'h77;  4'hB: hexdig = 8'h7C;
            4'hC: hexdig = 8'h39;  4'hD: hexdig = 8'h5E;
            4'hE: hexdig = 8'h79;  default: hexdig = 8'h71;  // F
        endcase
    endfunction

    reg [7:0] c5, c4, c3, c2, c1, c0;

    always @(*) begin
        {c5, c4, c3, c2, c1, c0} = {6{CH_BLANK}};
        if (error) begin
            // "Int.  n"
            c5 = CH_I; c4 = CH_n; c3 = CH_t | DP;
            c0 = hexdig({2'b00, attempts_left});
        end else begin
            case (display_mode)
                3'd0: begin c5 = CH_d; c4 = hexdig(4'd1);
                            c2 = hexdig(display_value); end
                3'd1: begin c5 = CH_d; c4 = hexdig(4'd2);
                            c2 = CH_DASH; c1 = hexdig(display_value); end
                3'd2: begin c5 = CH_d; c4 = hexdig(4'd3);
                            c2 = CH_DASH; c1 = CH_DASH; c0 = hexdig(display_value); end
                3'd3: begin c5 = CH_A; c4 = CH_c; c3 = CH_c;        // AccESO
                            c2 = CH_E; c1 = CH_S; c0 = CH_O; end
                3'd4: begin c5 = CH_b; c4 = CH_L; c3 = CH_O;        // bLOquE
                            c2 = CH_q; c1 = CH_u; c0 = CH_E; end
                default: {c5, c4, c3, c2, c1, c0} = {6{CH_DASH}};
            endcase
        end
    end

    // La DE10-Lite enciende el segmento con 0
    assign hex5 = ~c5;
    assign hex4 = ~c4;
    assign hex3 = ~c3;
    assign hex2 = ~c2;
    assign hex1 = ~c1;
    assign hex0 = ~c0;
endmodule
