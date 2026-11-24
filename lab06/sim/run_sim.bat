@echo off
REM ==========================================================================
REM  Simulacion con Icarus Verilog. Ejecutar desde la carpeta del proyecto:
REM      sim\run_sim.bat          (simula y genera las figuras SVG)
REM      sim\run_sim.bat wave     (ademas abre GTKWave)
REM ==========================================================================
cd /d "%~dp0\.."

REM 1) Testbench de la FSM sola (tb_caja_fuerte.v)
iverilog -g2005 -o sim\tb_fsm.vvp tb_caja_fuerte.v
if errorlevel 1 exit /b 1
pushd sim
vvp -n tb_fsm.vvp
popd

REM 2) Testbench del sistema completo (FSM + PWM + displays + LEDs)
iverilog -g2005 -Wall -o sim\tb_top.vvp tb_caja_fuerte_top.v
if errorlevel 1 exit /b 1
pushd sim
vvp -n tb_top.vvp
set ERR=%errorlevel%
popd
if not "%ERR%"=="0" exit /b 1

python -I sim\waves.py

if /i "%1"=="wave" start gtkwave sim\tb_caja_fuerte_top.vcd sim\tb_caja_fuerte_top.gtkw
