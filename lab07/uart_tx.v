// =============================================================================
// uart_tx.v - Transmisor UART 8-N-1
// -----------------------------------------------------------------------------
// FSM de 4 estados: IDLE -> START -> DATA (x8, LSB primero) -> STOP -> IDLE
//
// Cada estado dura exactamente un periodo de baud_tick. Cuando llega tx_start
// el byte se guarda y la trama arranca en el siguiente baud_tick, así el bit
// de start dura un bit completo aunque baud_tick corra libremente.
//
//   tx_start : pulso de 1 ciclo para pedir el envío de tx_data
//   tx_busy  : 1 mientras hay una trama pendiente o en curso
//   tx_done  : pulso de 1 ciclo al terminar el bit de stop
// =============================================================================
`timescale 1ns / 1ps

module uart_tx (
    input  wire       clk,
    input  wire       rst,
    input  wire       baud_tick,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx,
    output wire       tx_busy,
    output reg        tx_done
);
    localparam [1:0] S_IDLE  = 2'd0,
                     S_START = 2'd1,
                     S_DATA  = 2'd2,
                     S_STOP  = 2'd3;

    reg [1:0] state;
    reg [7:0] shreg;     // registro de desplazamiento con el byte a enviar
    reg [2:0] bit_cnt;   // bit de datos actual (0..7)
    reg       pend;      // hay un byte cargado esperando el próximo baud_tick

    assign tx_busy = pend | (state != S_IDLE);

    always @(posedge clk) begin
        if (rst) begin
            state   <= S_IDLE;
            shreg   <= 8'd0;
            bit_cnt <= 3'd0;
            pend    <= 1'b0;
            tx      <= 1'b1;          // línea en reposo = 1
            tx_done <= 1'b0;
        end else begin
            tx_done <= 1'b0;

            case (state)
                S_IDLE: begin
                    tx <= 1'b1;
                    if (tx_start && !pend) begin
                        shreg <= tx_data;
                        pend  <= 1'b1;
                    end else if (pend && baud_tick) begin
                        pend  <= 1'b0;
                        tx    <= 1'b0;        // bit de start
                        state <= S_START;
                    end
                end

                S_START: if (baud_tick) begin
                    tx      <= shreg[0];      // primer bit de datos (LSB)
                    shreg   <= {1'b0, shreg[7:1]};
                    bit_cnt <= 3'd0;
                    state   <= S_DATA;
                end

                S_DATA: if (baud_tick) begin
                    if (bit_cnt == 3'd7) begin
                        tx    <= 1'b1;        // bit de stop
                        state <= S_STOP;
                    end else begin
                        tx      <= shreg[0];
                        shreg   <= {1'b0, shreg[7:1]};
                        bit_cnt <= bit_cnt + 3'd1;
                    end
                end

                S_STOP: if (baud_tick) begin
                    tx_done <= 1'b1;
                    state   <= S_IDLE;
                end
            endcase
        end
    end
endmodule
