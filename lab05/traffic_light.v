// =============================================================================
// traffic_light.v - FSM Moore: semáforo vehicular + semáforo peatonal
// -----------------------------------------------------------------------------
//   Estado            Código  Vehicular (R Y G)  Peatonal (R G)  Duración
//   S_VERDE           2'b00       0 0 1              1 0          T_VERDE
//   S_AMAR_A_ROJO     2'b01       0 1 0              1 0          T_AMARILLO
//   S_ROJO            2'b10       1 0 0              0 1          T_ROJO
//   S_AMAR_A_VERDE    2'b11       0 1 0              1 0          T_AMARILLO
//
// El peatón solo tiene verde cuando el vehicular está en rojo. En los dos
// amarillos ve rojo (margen para despejar el cruce).
//
// Tres bloques separados (evita latches inferidos):
//   1) registro de estado      always @(posedge clk)
//   2) lógica de siguiente est. always @(*)
//   3) lógica de salida Moore  always @(*)   -> depende SOLO del estado
// =============================================================================
`timescale 1ns / 1ps

module traffic_light #(
    parameter [4:0] T_VERDE    = 5'd10,
    parameter [4:0] T_AMARILLO = 5'd3,
    parameter [4:0] T_ROJO     = 5'd10
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick,        // pulso de 1 ciclo cada segundo
    output reg        car_r,
    output reg        car_y,
    output reg        car_g,
    output reg        ped_r,
    output reg        ped_g,
    output wire [1:0] state_o,
    output wire [4:0] remaining    // segundos que faltan en el estado actual
);
    localparam [1:0] S_VERDE        = 2'b00,
                     S_AMAR_A_ROJO  = 2'b01,
                     S_ROJO         = 2'b10,
                     S_AMAR_A_VERDE = 2'b11;

    reg [1:0] state, next_state;
    reg [4:0] timer;      // segundos transcurridos en el estado actual
    reg [4:0] duration;   // duración del estado actual

    // Duración de cada estado
    always @(*) begin
        case (state)
            S_VERDE: duration = T_VERDE;
            S_ROJO:  duration = T_ROJO;
            default: duration = T_AMARILLO;
        endcase
    end

    // Condición de transición: se cumplió el tiempo del estado
    wire done = tick && (timer == duration - 5'd1);

    // ---- 1) Registro de estado (secuencial) --------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_VERDE;
        else
            state <= next_state;
    end

    // Contador de segundos dentro del estado (secuencial)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            timer <= 5'd0;
        else if (done)
            timer <= 5'd0;
        else if (tick)
            timer <= timer + 5'd1;
    end

    // ---- 2) Lógica de siguiente estado (combinacional) ---------------------
    always @(*) begin
        next_state = state;               // por defecto: permanecer
        if (done) begin
            case (state)
                S_VERDE:        next_state = S_AMAR_A_ROJO;
                S_AMAR_A_ROJO:  next_state = S_ROJO;
                S_ROJO:         next_state = S_AMAR_A_VERDE;
                S_AMAR_A_VERDE: next_state = S_VERDE;
                default:        next_state = S_ROJO;
            endcase
        end
    end

    // ---- 3) Lógica de salida Moore (combinacional) -------------------------
    always @(*) begin
        // valor por defecto seguro: todo en rojo
        car_r = 1'b1; car_y = 1'b0; car_g = 1'b0;
        ped_r = 1'b1; ped_g = 1'b0;
        case (state)
            S_VERDE: begin
                car_r = 1'b0; car_y = 1'b0; car_g = 1'b1;
                ped_r = 1'b1; ped_g = 1'b0;
            end
            S_AMAR_A_ROJO, S_AMAR_A_VERDE: begin
                car_r = 1'b0; car_y = 1'b1; car_g = 1'b0;
                ped_r = 1'b1; ped_g = 1'b0;
            end
            S_ROJO: begin
                car_r = 1'b1; car_y = 1'b0; car_g = 1'b0;
                ped_r = 1'b0; ped_g = 1'b1;
            end
            default: ;
        endcase
    end

    assign state_o   = state;
    assign remaining = duration - timer;
endmodule
