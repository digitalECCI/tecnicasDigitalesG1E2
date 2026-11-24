// =============================================================================
// fsm_caja_fuerte.v - FSM de una caja fuerte con clave de 3 digitos
// -----------------------------------------------------------------------------
// * El usuario coloca un digito (0..F) en los switches y confirma con
//   enter_pulse (pulso de 1 ciclo). Se repite 3 veces.
// * Al tercer digito se compara la clave completa (no se revela cual digito
//   fallo):
//     - Correcta   -> ABIERTA  (servo_open = 1, led_green = 1)
//     - Incorrecta -> se descuenta un intento y vuelve a pedir el 1er digito
//     - Sin intentos -> BLOQUEADA (led_red = 1)
// * En ABIERTA, un enter_pulse cierra la caja y vuelve a pedir clave.
// * master_reset_pulse sale de cualquier estado (incluido BLOQUEADA) y
//   restablece los 3 intentos. reset_n (asincrono, activo en bajo) hace lo mismo.
//
// display_mode:
//   0,1,2 : ingresando digito 1, 2 o 3  (display_value = switches)
//   3     : caja abierta                (display_value = 0)
//   4     : caja bloqueada              (display_value = 0)
// =============================================================================

`timescale 1ns/1ps

module fsm_caja_fuerte #(
    parameter [3:0] CLAVE_1 = 4'h1,
    parameter [3:0] CLAVE_2 = 4'h2,
    parameter [3:0] CLAVE_3 = 4'h3
) (
    input  wire       clk,
    input  wire       reset_n,
    input  wire       enter_pulse,
    input  wire       master_reset_pulse,
    input  wire [3:0] switches,

    output reg        servo_open,
    output reg        led_green,
    output reg        led_red,
    output reg  [1:0] attempts_left,
    output reg  [2:0] display_mode,
    output reg  [3:0] display_value
);

    // Estados
    localparam [2:0] S_DIG1     = 3'd0,
                     S_DIG2     = 3'd1,
                     S_DIG3     = 3'd2,
                     S_ABIERTA  = 3'd3,
                     S_BLOQUEO  = 3'd4;

    reg [2:0] state;
    reg [3:0] dig1, dig2;   // digitos guardados (el 3ro se compara directo)

    // -------------------------------------------------------------------------
    // Logica secuencial: estado, digitos e intentos
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state         <= S_DIG1;
            dig1          <= 4'h0;
            dig2          <= 4'h0;
            attempts_left <= 2'd3;
        end else if (master_reset_pulse) begin
            state         <= S_DIG1;
            dig1          <= 4'h0;
            dig2          <= 4'h0;
            attempts_left <= 2'd3;
        end else begin
            case (state)
                S_DIG1: if (enter_pulse) begin
                    dig1  <= switches;
                    state <= S_DIG2;
                end

                S_DIG2: if (enter_pulse) begin
                    dig2  <= switches;
                    state <= S_DIG3;
                end

                S_DIG3: if (enter_pulse) begin
                    if (dig1 == CLAVE_1 && dig2 == CLAVE_2 && switches == CLAVE_3) begin
                        state         <= S_ABIERTA;
                        attempts_left <= 2'd3;
                    end else if (attempts_left <= 2'd1) begin
                        state         <= S_BLOQUEO;
                        attempts_left <= 2'd0;
                    end else begin
                        state         <= S_DIG1;
                        attempts_left <= attempts_left - 2'd1;
                    end
                end

                S_ABIERTA: if (enter_pulse) begin
                    state <= S_DIG1;   // cerrar la caja
                end

                S_BLOQUEO: begin
                    state <= S_BLOQUEO; // solo sale con master_reset o reset_n
                end

                default: state <= S_DIG1;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Salidas (Moore)
    // -------------------------------------------------------------------------
    always @(*) begin
        servo_open    = 1'b0;
        led_green     = 1'b0;
        led_red       = 1'b0;
        display_mode  = state;
        display_value = 4'h0;

        case (state)
            S_DIG1, S_DIG2, S_DIG3: display_value = switches;
            S_ABIERTA: begin
                servo_open = 1'b1;
                led_green  = 1'b1;
            end
            S_BLOQUEO: led_red = 1'b1;
            default: ;
        endcase
    end

endmodule
