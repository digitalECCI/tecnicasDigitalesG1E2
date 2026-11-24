@echo off
REM ==========================================================================
REM  Simulacion con Icarus Verilog. Ejecutar desde la carpeta del proyecto:
REM      sim\run_sim.bat          (simula y genera las figuras SVG)
REM      sim\run_sim.bat wave     (ademas abre GTKWave)
REM ==========================================================================
cd /d "%~dp0\.."

iverilog -g2005 -Wall -o sim\tb.vvp tb_semaforo.v
if errorlevel 1 exit /b 1

REM se ejecuta dentro de sim\ para que el VCD quede en sim\tb_semaforo.vcd
pushd sim
vvp -n tb.vvp
set ERR=%errorlevel%
popd
if not "%ERR%"=="0" exit /b 1

python -I sim\waves.py

if /i "%1"=="wave" start gtkwave sim\tb_semaforo.vcd sim\tb_semaforo.gtkw
