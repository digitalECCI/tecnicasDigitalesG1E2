# Reloj de 50 MHz de la DE10-Lite
create_clock -name MAX10_CLK1_50 -period 20.000 [get_ports MAX10_CLK1_50]
derive_clock_uncertainty

# Entradas/salidas asíncronas (botones, switches, UART): se sincronizan en el
# diseño, así que no se analizan como rutas temporizadas.
set_false_path -from [get_ports {KEY[*] SW[*] GPIO_RX}]
set_false_path -to   [get_ports {LEDR[*] GPIO_TX}]
