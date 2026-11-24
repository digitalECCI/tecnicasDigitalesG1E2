// =============================================================================
// bin2dec.v - Binario de 10 bits -> 4 dígitos decimales en ASCII (lado TX)
// -----------------------------------------------------------------------------
// Lógica combinacional basada en el algoritmo "double dabble" (shift-and-add-3):
// se desplaza el número binario hacia los dígitos BCD 10 veces y, antes de cada
// desplazamiento, a todo dígito BCD >= 5 se le suma 3.
//
//   bin = 10'd1023  ->  ascii3..0 = "1","0","2","3"   n_dig = 4
//   bin = 10'd37    ->  ascii3..0 = "0","0","3","7"   n_dig = 2
//
// n_dig indica cuántos dígitos son significativos (sin ceros a la izquierda);
// el valor 0 se reporta con n_dig = 1 para que se imprima "0".
// =============================================================================
`timescale 1ns / 1ps

module bin2dec (
    input  wire [9:0] bin,
    output wire [7:0] ascii3,   // millares
    output wire [7:0] ascii2,   // centenas
    output wire [7:0] ascii1,   // decenas
    output wire [7:0] ascii0,   // unidades
    output reg  [2:0] n_dig
);
    // [25:22] millares | [21:18] centenas | [17:14] decenas | [13:10] unidades | [9:0] binario
    reg [25:0] sh;
    integer i;

    always @* begin
        sh = {16'd0, bin};
        for (i = 0; i < 10; i = i + 1) begin
            if (sh[13:10] >= 4'd5) sh[13:10] = sh[13:10] + 4'd3;
            if (sh[17:14] >= 4'd5) sh[17:14] = sh[17:14] + 4'd3;
            if (sh[21:18] >= 4'd5) sh[21:18] = sh[21:18] + 4'd3;
            if (sh[25:22] >= 4'd5) sh[25:22] = sh[25:22] + 4'd3;
            sh = sh << 1;
        end
    end

    wire [3:0] d3 = sh[25:22];
    wire [3:0] d2 = sh[21:18];
    wire [3:0] d1 = sh[17:14];
    wire [3:0] d0 = sh[13:10];

    // '0' = 0x30 -> ASCII = 0x30 + dígito
    assign ascii3 = {4'h3, d3};
    assign ascii2 = {4'h3, d2};
    assign ascii1 = {4'h3, d1};
    assign ascii0 = {4'h3, d0};

    always @* begin
        if      (d3 != 4'd0) n_dig = 3'd4;
        else if (d2 != 4'd0) n_dig = 3'd3;
        else if (d1 != 4'd0) n_dig = 3'd2;
        else                 n_dig = 3'd1;
    end
endmodule
