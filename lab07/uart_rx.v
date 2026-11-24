// =============================================================================
// uart_rx.v - Receptor UART 8-N-1 con sobremuestreo x16
// -----------------------------------------------------------------------------
// FSM de 4 estados: IDLE -> START -> DATA (x8) -> STOP -> IDLE
//
//  * La entrada rx es asíncrona: se pasa por 2 flip-flops (sincronizador)
//    antes de usarla, para evitar metaestabilidad.
//  * IDLE : espera el flanco de bajada (inicio del bit de start).
//  * START: cuenta 8 os_tick (medio bit) y confirma que la línea sigue en 0;
//           si volvió a 1 era un pulso de ruido y regresa a IDLE.
//  * DATA : a partir del centro del start, cada 16 os_tick (un bit) está en
//           el centro del siguiente bit de datos -> lo muestrea (LSB primero).
//  * STOP : muestrea el centro del bit de stop. Si vale 1 entrega el byte
//           (rx_done); si vale 0 hay error de trama (frame_err): el byte se
//           descarta y no se acepta otro start hasta que la línea vuelva a 1
//           (si no, el resto del stop en 0 parecería un start falso).
// =============================================================================
`timescale 1ns / 1ps

module uart_rx #(
    parameter OVERSAMPLE = 16
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       os_tick,
    input  wire       rx,          // línea serial asíncrona
    output reg  [7:0] rx_data,
    output reg        rx_done,     // pulso de 1 ciclo: byte válido
    output reg        frame_err    // pulso de 1 ciclo: stop inválido
);
    localparam [1:0] S_IDLE  = 2'd0,
                     S_START = 2'd1,
                     S_DATA  = 2'd2,
                     S_STOP  = 2'd3;

    localparam integer MID  = OVERSAMPLE/2 - 1;   // 7  -> centro del start
    localparam integer FULL = OVERSAMPLE - 1;     // 15 -> un bit completo

    // ---- Sincronizador de 2 flip-flops (reposo = 1) ------------------------
    reg rx_meta, rx_s;
    always @(posedge clk) begin
        if (rst) begin
            rx_meta <= 1'b1;
            rx_s    <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_s    <= rx_meta;
        end
    end

    // ---- FSM de recepción ---------------------------------------------------
    reg [1:0] state;
    reg [3:0] os_cnt;    // cuenta de os_tick dentro del bit
    reg [2:0] bit_cnt;   // bit de datos actual
    reg [7:0] shreg;
    reg       wait_high; // tras un error de trama: esperar línea en reposo

    always @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            os_cnt    <= 4'd0;
            bit_cnt   <= 3'd0;
            shreg     <= 8'd0;
            rx_data   <= 8'd0;
            rx_done   <= 1'b0;
            frame_err <= 1'b0;
            wait_high <= 1'b0;
        end else begin
            rx_done   <= 1'b0;
            frame_err <= 1'b0;

            case (state)
                S_IDLE: begin
                    os_cnt <= 4'd0;
                    if (wait_high) begin
                        // la línea sigue en 0 (stop inválido / break):
                        // no se acepta un start hasta que vuelva a 1
                        if (rx_s == 1'b1) wait_high <= 1'b0;
                    end else if (rx_s == 1'b0) begin  // flanco de bajada: posible start
                        state <= S_START;
                    end
                end

                S_START: if (os_tick) begin
                    if (os_cnt == MID) begin
                        os_cnt <= 4'd0;
                        if (rx_s == 1'b0) begin  // start confirmado en su centro
                            bit_cnt <= 3'd0;
                            state   <= S_DATA;
                        end else begin
                            state   <= S_IDLE;   // glitch: se descarta
                        end
                    end else begin
                        os_cnt <= os_cnt + 4'd1;
                    end
                end

                S_DATA: if (os_tick) begin
                    if (os_cnt == FULL) begin
                        os_cnt <= 4'd0;
                        shreg  <= {rx_s, shreg[7:1]};   // entra por el MSB: LSB primero
                        if (bit_cnt == 3'd7)
                            state <= S_STOP;
                        else
                            bit_cnt <= bit_cnt + 3'd1;
                    end else begin
                        os_cnt <= os_cnt + 4'd1;
                    end
                end

                S_STOP: if (os_tick) begin
                    if (os_cnt == FULL) begin
                        os_cnt <= 4'd0;
                        if (rx_s == 1'b1) begin
                            rx_data <= shreg;
                            rx_done <= 1'b1;
                        end else begin
                            frame_err <= 1'b1;   // stop en 0 -> error de trama
                            wait_high <= 1'b1;   // se descarta el byte y se resincroniza
                        end
                        state <= S_IDLE;
                    end else begin
                        os_cnt <= os_cnt + 4'd1;
                    end
                end
            endcase
        end
    end
endmodule
