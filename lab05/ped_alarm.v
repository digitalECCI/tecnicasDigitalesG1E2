// =============================================================================
// ped_alarm.v - (BONUS) Botón peatonal + alarma sonora
// -----------------------------------------------------------------------------
// Al presionar el botón se guarda la solicitud (req). Cuando el semáforo
// peatonal pasa a verde, suena la alarma (pitidos intermitentes) durante todo
// el verde peatonal. Al terminar el verde la solicitud se borra.
//
//   tone : onda cuadrada de TONE_HZ modulada por los pitidos -> buzzer PASIVO
//   beep : nivel alto/bajo de los pitidos, sin tono         -> buzzer ACTIVO
//
//   Medio periodo del tono   = 50 000 000 / (2*2000) = 12 500 cuentas
//   Medio periodo del pitido = 50 000 000 / (2*4)    = 6 250 000 cuentas
// =============================================================================
`timescale 1ns / 1ps

module ped_alarm #(
    parameter integer CLK_HZ  = 50_000_000,
    parameter integer TONE_HZ = 2000,
    parameter integer BEEP_HZ = 4            // pitidos por segundo
)(
    input  wire clk,
    input  wire rst_n,
    input  wire press,     // pulso del botón ya filtrado
    input  wire ped_g,     // verde peatonal
    output reg  req,
    output wire tone,
    output wire beep
);
    localparam integer TONE_HALF = CLK_HZ / (2 * TONE_HZ);
    localparam integer BEEP_HALF = CLK_HZ / (2 * BEEP_HZ);
    localparam integer WT = (TONE_HALF > 1) ? $clog2(TONE_HALF) : 1;
    localparam integer WB = (BEEP_HALF > 1) ? $clog2(BEEP_HALF) : 1;

    // ---- Solicitud del peatón ----------------------------------------------
    reg ped_g_d;
    wire ped_g_fall = ped_g_d & ~ped_g;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req     <= 1'b0;
            ped_g_d <= 1'b0;
        end else begin
            ped_g_d <= ped_g;
            if (ped_g_fall)
                req <= 1'b0;            // terminó el verde: solicitud atendida
            else if (press)
                req <= 1'b1;
        end
    end

    wire alarm_en = req & ped_g;

    // ---- Generador de tono -------------------------------------------------
    reg [WT-1:0] tcnt;
    reg          tsq;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tcnt <= {WT{1'b0}}; tsq <= 1'b0;
        end else if (!alarm_en) begin
            tcnt <= {WT{1'b0}}; tsq <= 1'b0;
        end else if (tcnt == TONE_HALF - 1) begin
            tcnt <= {WT{1'b0}}; tsq <= ~tsq;
        end else begin
            tcnt <= tcnt + 1'b1;
        end
    end

    // ---- Envolvente de pitidos (on/off) ------------------------------------
    reg [WB-1:0] bcnt;
    reg          bsq;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bcnt <= {WB{1'b0}}; bsq <= 1'b0;
        end else if (!alarm_en) begin
            bcnt <= {WB{1'b0}}; bsq <= 1'b1;   // empieza sonando
        end else if (bcnt == BEEP_HALF - 1) begin
            bcnt <= {WB{1'b0}}; bsq <= ~bsq;
        end else begin
            bcnt <= bcnt + 1'b1;
        end
    end

    assign beep = alarm_en & bsq;
    assign tone = beep & tsq;
endmodule
