// Con Icarus Verilog (__ICARUS__) se incluyen los submódulos para poder
// compilar este archivo solo, p. ej. con el botón de la extensión de VS Code.
// Quartus no define __ICARUS__: allí los archivos se toman del .qsf.
`ifdef __ICARUS__
`include "baud_gen.v"
`include "uart_tx.v"
`include "uart_rx.v"
`include "bin2dec.v"
`include "dec2bin.v"
`include "debounce.v"
`endif

`timescale 1ns / 1ps

module proyecto_uart #(
    parameter CLK_FREQ     = 50_000_000,
    parameter BAUD         = 9600,
    parameter DEBOUNCE_CYC = 500_000          // 10 ms @ 50 MHz
)(
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,                    // KEY0 = enviar, KEY1 = reset
    input  wire [9:0] SW,
    output wire [9:0] LEDR,
    output wire       GPIO_TX,                // FPGA -> RX del adaptador USB-TTL
    input  wire       GPIO_RX                 // FPGA <- TX del adaptador USB-TTL
);
    wire clk = MAX10_CLK1_50;

    // ---------------------------------------------------------------------
    // Reset sincronizado (KEY1, activo en bajo)
    // ---------------------------------------------------------------------
    reg [1:0] rst_sync = 2'b11;
    always @(posedge clk) rst_sync <= {rst_sync[0], ~KEY[1]};
    wire rst = rst_sync[1];

    // ---------------------------------------------------------------------
    // Sincronización de switches (2 flip-flops) y botón KEY0
    // ---------------------------------------------------------------------
    reg [9:0] sw_meta, sw_s;
    always @(posedge clk) begin
        sw_meta <= SW;
        sw_s    <= sw_meta;
    end

    wire send_press;
    debounce #(.DEBOUNCE_CYC(DEBOUNCE_CYC)) u_key0 (
        .clk(clk), .rst(rst), .btn_n(KEY[0]),
        .pressed(), .press(send_press)
    );

    // ---------------------------------------------------------------------
    // Generador de baudios
    // ---------------------------------------------------------------------
    wire baud_tick, os_tick;
    baud_gen #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD), .OVERSAMPLE(16)) u_baud (
        .clk(clk), .rst(rst), .baud_tick(baud_tick), .os_tick(os_tick)
    );

    // =====================================================================
    // SENTIDO FPGA -> PC
    // =====================================================================
    reg  [9:0] tx_value;                 // valor capturado al pulsar KEY0
    wire [7:0] a3, a2, a1, a0;
    wire [2:0] n_dig;

    bin2dec u_bin2dec (
        .bin(tx_value), .ascii3(a3), .ascii2(a2), .ascii1(a1), .ascii0(a0),
        .n_dig(n_dig)
    );

    // Mensaje: [0..3] dígitos, [4] '\r', [5] '\n'. Se empieza en 4-n_dig
    // para omitir los ceros a la izquierda.
    reg [2:0] idx;
    reg [7:0] msg_byte;
    always @* begin
        case (idx)
            3'd0:    msg_byte = a3;
            3'd1:    msg_byte = a2;
            3'd2:    msg_byte = a1;
            3'd3:    msg_byte = a0;
            3'd4:    msg_byte = 8'h0D;   // '\r'
            default: msg_byte = 8'h0A;   // '\n'
        endcase
    end

    // FSM secuenciadora: entrega los bytes del mensaje al transmisor
    localparam [1:0] Q_IDLE = 2'd0,
                     Q_LOAD = 2'd1,
                     Q_SEND = 2'd2,
                     Q_WAIT = 2'd3;

    reg  [1:0] q_state;
    reg        tx_start;
    reg  [7:0] tx_data;
    wire       tx_busy, tx_done;

    always @(posedge clk) begin
        if (rst) begin
            q_state  <= Q_IDLE;
            tx_value <= 10'd0;
            idx      <= 3'd0;
            tx_start <= 1'b0;
            tx_data  <= 8'd0;
        end else begin
            tx_start <= 1'b0;
            case (q_state)
                Q_IDLE: if (send_press) begin
                    tx_value <= sw_s;            // captura los switches
                    q_state  <= Q_LOAD;
                end
                Q_LOAD: begin                    // bin2dec ya tiene el resultado
                    idx     <= 3'd4 - n_dig;
                    q_state <= Q_SEND;
                end
                Q_SEND: if (!tx_busy) begin
                    tx_data  <= msg_byte;
                    tx_start <= 1'b1;
                    q_state  <= Q_WAIT;
                end
                Q_WAIT: if (tx_done) begin
                    if (idx == 3'd5) begin
                        q_state <= Q_IDLE;       // '\n' enviado: mensaje completo
                    end else begin
                        idx     <= idx + 3'd1;
                        q_state <= Q_SEND;
                    end
                end
            endcase
        end
    end

    uart_tx u_tx (
        .clk(clk), .rst(rst), .baud_tick(baud_tick),
        .tx_start(tx_start), .tx_data(tx_data),
        .tx(GPIO_TX), .tx_busy(tx_busy), .tx_done(tx_done)
    );

    // =====================================================================
    // SENTIDO PC -> FPGA
    // =====================================================================
    wire [7:0] rx_data;
    wire       rx_done, frame_err;

    uart_rx #(.OVERSAMPLE(16)) u_rx (
        .clk(clk), .rst(rst), .os_tick(os_tick), .rx(GPIO_RX),
        .rx_data(rx_data), .rx_done(rx_done), .frame_err(frame_err)
    );

    wire [9:0] rx_value;
    wire       rx_valid, rx_overflow;

    dec2bin u_dec2bin (
        .clk(clk), .rst(rst), .rx_done(rx_done), .rx_data(rx_data),
        .value(rx_value), .value_valid(rx_valid), .overflow(rx_overflow)
    );

    assign LEDR = rx_value;   // el valor se mantiene hasta el próximo Enter

endmodule
