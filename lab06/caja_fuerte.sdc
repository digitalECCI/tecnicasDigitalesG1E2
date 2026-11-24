# Reloj de 50 MHz de la DE10-Lite
create_clock -name MAX10_CLK1_50 -period 20.000 [get_ports MAX10_CLK1_50]
derive_clock_uncertainty

# Entradas/salidas asíncronas (botones, switches, LEDs, displays, servo): se
# sincronizan en el diseño, así que no se analizan como rutas temporizadas.
set_false_path -from [get_ports {KEY[*] SW[*]}]
set_false_path -to   [get_ports {LEDR[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*] HEX4[*] HEX5[*] GPIO[*]}]
