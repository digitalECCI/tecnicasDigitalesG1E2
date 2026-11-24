// =============================================================================
// tb_proyecto_uart.v - Testbench del enlace UART (ambos sentidos)
// -----------------------------------------------------------------------------
// Simula con los parámetros reales: reloj de 50 MHz y 9600 baudios.
// Solo se acorta el antirrebote para no simular 10 ms por pulsación.
//
// El testbench hace de "PC":
//   * Monitor : decodifica GPIO_TX como lo haría PuTTY e imprime los bytes.
//   * Driver  : escribe tramas en GPIO_RX como si se tecleara en PuTTY.
// Al final informa PASS/FAIL de cada prueba.
// =============================================================================
// Incluye el diseño completo: basta con compilar este archivo
//   iverilog -o build\tb.out tb_proyecto_uart.v   y luego   vvp build\tb.out
`include "proyecto_uart.v"

`timescale 1ns/1ps

module tb_proyecto_uart;

    localparam CLK_FREQ = 50_000_000;
    localparam BAUD     = 9600;
    localparam real CLK_PERIOD = 20.0;                 // 50 MHz
    localparam real BIT_NS     = 1.0e9 / BAUD;         // 104 166.7 ns
    localparam [7:0] CR = 8'h0D;   // Enter ("\r" no existe en Verilog-2005)
    localparam [7:0] LF = 8'h0A;

    reg        clk = 1'b0;
    reg  [1:0] KEY = 2'b11;          // botones sueltos (activos en bajo)
    reg  [9:0] SW  = 10'd0;
    wire [9:0] LEDR;
    wire       GPIO_TX;
    reg        GPIO_RX = 1'b1;       // línea en reposo

    always #(CLK_PERIOD/2) clk = ~clk;

    proyecto_uart #(
        .CLK_FREQ(CLK_FREQ), .BAUD(BAUD), .DEBOUNCE_CYC(1000)   // 20 us
    ) dut (
        .MAX10_CLK1_50(clk), .KEY(KEY), .SW(SW), .LEDR(LEDR),
        .GPIO_TX(GPIO_TX), .GPIO_RX(GPIO_RX)
    );

    integer errors = 0;
    integer tests  = 0;

    // -------------------------------------------------------------------------
    // Monitor de GPIO_TX (lado PC): guarda los bytes recibidos en pc_log
    // -------------------------------------------------------------------------
    reg [7:0] pc_log [0:255];
    integer   pc_cnt = 0;
    reg [7:0] mon_byte;
    integer   k;

    always begin
        @(negedge GPIO_TX);                 // flanco de bajada = bit de start
        #(BIT_NS * 1.5);                    // centro del bit D0
        for (k = 0; k < 8; k = k + 1) begin
            mon_byte[k] = GPIO_TX;
            #(BIT_NS);
        end
        if (GPIO_TX !== 1'b1) begin         // centro del bit de stop
            $display("[%0t] MONITOR: error de trama en GPIO_TX", $time);
            errors = errors + 1;
        end
        pc_log[pc_cnt] = mon_byte;
        pc_cnt = pc_cnt + 1;
    end

    // -------------------------------------------------------------------------
    // Driver de GPIO_RX (lado PC)
    // -------------------------------------------------------------------------
    task pc_send_byte(input [7:0] b, input stop_ok);
        integer i;
        begin
            GPIO_RX = 1'b0;                 // start
            #(BIT_NS);
            for (i = 0; i < 8; i = i + 1) begin
                GPIO_RX = b[i];             // LSB primero
                #(BIT_NS);
            end
            GPIO_RX = stop_ok;              // stop (0 = trama corrupta)
            #(BIT_NS);
            GPIO_RX = 1'b1;
            #(BIT_NS);                      // un bit de reposo entre bytes
        end
    endtask

    // Envía una cadena de hasta 8 caracteres (el primer carácter va en los bits altos)
    task pc_send_string(input [8*8-1:0] s, input integer len);
        integer i;
        begin
            for (i = len - 1; i >= 0; i = i - 1)
                pc_send_byte(s[i*8 +: 8], 1'b1);
        end
    endtask

    // -------------------------------------------------------------------------
    // Prueba FPGA -> PC: fija los switches, pulsa KEY0 y verifica el texto
    // -------------------------------------------------------------------------
    task test_tx(input [9:0] value);
        reg [8*6-1:0] exp;
        reg [7:0] c3, c2, c1, c0;
        integer exp_len, start, i, ok, t;
        begin
            tests = tests + 1;
            // texto esperado: dígitos decimales + "\r\n"
            c3 = 8'h30 + value / 1000;
            c2 = 8'h30 + (value / 100) % 10;
            c1 = 8'h30 + (value / 10) % 10;
            c0 = 8'h30 + value % 10;
            if      (value >= 1000) begin exp_len = 6; exp = {c3, c2, c1, c0, 8'h0D, 8'h0A}; end
            else if (value >= 100)  begin exp_len = 5; exp = {8'h00, c2, c1, c0, 8'h0D, 8'h0A}; end
            else if (value >= 10)   begin exp_len = 4; exp = {16'h0, c1, c0, 8'h0D, 8'h0A}; end
            else                    begin exp_len = 3; exp = {24'h0, c0, 8'h0D, 8'h0A}; end

            start = pc_cnt;
            SW = value;
            #(5_000);
            KEY[0] = 1'b0;                  // presionar
            #(200_000);                     // 200 us
            KEY[0] = 1'b1;                  // soltar

            // esperar el mensaje completo (máx. 10 ms)
            t = 0;
            while (pc_cnt < start + exp_len && t < 10_000) begin
                #(1_000); t = t + 1;
            end
            #(2 * BIT_NS);

            ok = (pc_cnt == start + exp_len);
            for (i = 0; i < exp_len && ok; i = i + 1)
                if (pc_log[start + i] !== exp[(exp_len-1-i)*8 +: 8]) ok = 0;

            $write("[%0t] TX  SW=%4d -> PuTTY recibe \"", $time, value);
            for (i = start; i < pc_cnt; i = i + 1)
                if (pc_log[i] == 8'h0D)      $write("\\r");
                else if (pc_log[i] == 8'h0A) $write("\\n");
                else                         $write("%c", pc_log[i]);
            if (ok) $display("\"  PASS");
            else begin $display("\"  FAIL"); errors = errors + 1; end
        end
    endtask

    // -------------------------------------------------------------------------
    // Prueba PC -> FPGA: verifica el valor mostrado en los LEDs
    // -------------------------------------------------------------------------
    task check_leds(input [9:0] expected, input [8*24-1:0] desc);
        begin
            tests = tests + 1;
            #(BIT_NS);
            if (LEDR === expected)
                $display("[%0t] RX  %0s -> LEDR=%b (%4d)  PASS", $time, desc, LEDR, LEDR);
            else begin
                $display("[%0t] RX  %0s -> LEDR=%b (%4d), esperado %4d  FAIL",
                         $time, desc, LEDR, LEDR, expected);
                errors = errors + 1;
            end
        end
    endtask

    // Cuenta los pulsos de error de trama del receptor
    integer frame_errs = 0;
    always @(posedge clk) if (dut.frame_err) frame_errs = frame_errs + 1;

    // -------------------------------------------------------------------------
    // Secuencia de pruebas
    // -------------------------------------------------------------------------
    integer fe_before;
    initial begin
        // Se crea en la carpeta desde donde se ejecuta la simulación
        // (build\ con la extensión de VS Code, sim\ con run_sim.bat)
        $dumpfile("tb_proyecto_uart.vcd");
        // Solo las señales útiles para el informe (los contadores de baudios
        // cambian en cada ciclo y harían el VCD de cientos de MB)
        // puertos de la tarjeta (sin el reloj: a 9600 baudios no se ve y
        // multiplicaría el tamaño del archivo)
        $dumpvars(0, KEY, SW, LEDR, GPIO_TX, GPIO_RX);
        $dumpvars(0, dut.send_press, dut.tx_value, dut.q_state, dut.idx,
                     dut.tx_start, dut.tx_data, dut.tx_busy, dut.tx_done,
                     dut.baud_tick);
        $dumpvars(0, dut.u_tx.state, dut.u_tx.bit_cnt);
        $dumpvars(0, dut.u_rx.rx_s, dut.u_rx.state, dut.u_rx.bit_cnt,
                     dut.rx_data, dut.rx_done, dut.frame_err);
        $dumpvars(0, dut.u_dec2bin.acc, dut.rx_value, dut.rx_valid, dut.rx_overflow);

        // reset con KEY1
        KEY[1] = 1'b0;
        #(1_000);
        KEY[1] = 1'b1;
        #(1_000);

        $display("=== Sentido FPGA -> PC (switches + KEY0) ===");
        test_tx(10'd1023);
        test_tx(10'd0);
        test_tx(10'd37);
        test_tx(10'd512);
        test_tx(10'd5);

        $display("=== Sentido PC -> FPGA (PuTTY -> LEDs) ===");
        pc_send_string({"512", CR}, 4);       check_leds(10'd512,  "\"512\\r\"");
        pc_send_string({"1023", CR}, 5);      check_leds(10'd1023, "\"1023\\r\"");
        pc_send_string({"0", CR, LF}, 3);     check_leds(10'd0,    "\"0\\r\\n\"");
        pc_send_string({"7", CR}, 2);         check_leds(10'd7,    "\"7\\r\"");
        pc_send_string({"341", CR}, 4);       check_leds(10'd341,  "\"341\\r\"");
        pc_send_string({"2048", CR}, 5);      check_leds(10'd1023, "\"2048\\r\" (satura)");
        pc_send_string({"12", 8'h7F, "5", CR}, 5);
                                              check_leds(10'd15,   "\"12<DEL>5\\r\"");
        pc_send_string({CR, LF}, 2);          check_leds(10'd15,   "linea vacia");

        // trama corrupta: stop = 0 -> el byte se descarta y LEDs no cambian
        tests = tests + 1;
        fe_before = frame_errs;
        pc_send_byte("9", 1'b0);
        pc_send_byte(8'h0D, 1'b1);
        #(BIT_NS);
        if (frame_errs == fe_before + 1 && LEDR == 10'd15)
            $display("[%0t] RX  trama con stop=0 -> frame_err detectado, LEDs sin cambio  PASS", $time);
        else begin
            $display("[%0t] RX  trama con stop=0 -> frame_errs=%0d LEDR=%0d  FAIL",
                     $time, frame_errs - fe_before, LEDR);
            errors = errors + 1;
        end

        $display("=== Full duplex: ambos sentidos al mismo tiempo ===");
        fork
            test_tx(10'd999);
            begin
                pc_send_string({"640", CR}, 4);
                check_leds(10'd640, "\"640\\r\" (simultaneo)");
            end
        join

        $display("==============================================");
        if (errors == 0) $display(" RESULTADO: %0d pruebas, TODAS PASARON", tests);
        else             $display(" RESULTADO: %0d errores en %0d pruebas", errors, tests);
        $display("==============================================");
        $finish;
    end

endmodule
