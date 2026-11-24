// =============================================================================
// dec2bin.v - Dígitos ASCII recibidos -> valor binario de 10 bits (lado RX)
// -----------------------------------------------------------------------------
// Por cada byte recibido (rx_done):
//   '0'..'9'        : acc = acc*10 + dígito
//   Enter (CR / LF) : si se recibió al menos un dígito, publica el valor en
//                     'value' (pulso value_valid) y reinicia el acumulador.
//                     Una línea vacía (p. ej. el LF de un CR+LF) se ignora.
//   Backspace (BS / DEL) : borra el último dígito (acc = acc/10)
//   Otro carácter   : se ignora
//
// Si el número escrito supera 1023 se satura a 1023 y se activa 'overflow'.
// acc*10 se calcula como (acc<<3) + (acc<<1).
// =============================================================================
`timescale 1ns / 1ps

module dec2bin (
    input  wire       clk,
    input  wire       rst,
    input  wire       rx_done,
    input  wire [7:0] rx_data,
    output reg  [9:0] value,
    output reg        value_valid,
    output reg        overflow
);
    localparam [7:0] CH_0  = 8'h30,  // '0'
                     CH_9  = 8'h39,  // '9'
                     CH_CR = 8'h0D,  // Enter (retorno de carro)
                     CH_LF = 8'h0A,  // salto de línea
                     CH_BS = 8'h08,  // backspace
                     CH_DEL= 8'h7F;  // tecla "borrar" de PuTTY

    localparam [10:0] MAX_VAL = 11'd1023;

    // acc nunca supera 1024: al pasarse de 1023 queda fijo en 1024 (saturado)
    reg  [10:0] acc;
    reg  [3:0]  n_digits;   // dígitos escritos en la línea actual
    wire [3:0]  digit  = rx_data[3:0];
    wire [14:0] acc_x10 = ({4'd0, acc} << 3) + ({4'd0, acc} << 1) + {11'd0, digit};

    always @(posedge clk) begin
        if (rst) begin
            acc         <= 11'd0;
            n_digits    <= 4'd0;
            value       <= 10'd0;
            value_valid <= 1'b0;
            overflow    <= 1'b0;
        end else begin
            value_valid <= 1'b0;

            if (rx_done) begin
                if (rx_data >= CH_0 && rx_data <= CH_9) begin
                    // acumular dígito (saturando en 1024 = "fuera de rango")
                    if (acc > MAX_VAL || acc_x10 > {4'd0, MAX_VAL})
                        acc <= MAX_VAL + 11'd1;
                    else
                        acc <= acc_x10[10:0];
                    if (n_digits != 4'd15)
                        n_digits <= n_digits + 4'd1;
                end
                else if (rx_data == CH_CR || rx_data == CH_LF) begin
                    if (n_digits != 4'd0) begin
                        if (acc > MAX_VAL) begin
                            value    <= MAX_VAL[9:0];
                            overflow <= 1'b1;
                        end else begin
                            value    <= acc[9:0];
                            overflow <= 1'b0;
                        end
                        value_valid <= 1'b1;
                    end
                    acc      <= 11'd0;
                    n_digits <= 4'd0;
                end
                else if (rx_data == CH_BS || rx_data == CH_DEL) begin
                    if (n_digits != 4'd0) begin
                        // si estaba saturado no se puede recuperar el valor: se reinicia
                        acc      <= (acc > MAX_VAL) ? 11'd0 : acc / 11'd10;
                        n_digits <= (acc > MAX_VAL) ? 4'd0  : n_digits - 4'd1;
                    end
                end
                // cualquier otro carácter se ignora
            end
        end
    end
endmodule
