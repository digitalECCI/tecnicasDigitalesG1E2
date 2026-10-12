# Lab 04: Contador Digital en Display de 7 Segmentos

## 1. Objetivo

Diseñar e implementar un contador digital de cuatro dígitos mediante Verilog HDL, utilizando la FPGA DE10-Lite y sus displays de siete segmentos. El sistema permite seleccionar cuatro velocidades de conteo mediante dos switches y reiniciar el contador con un botón.

## 2. Descripción del diseño

El sistema utiliza el reloj de 50 MHz integrado en la FPGA. Un divisor de frecuencia genera un pulso de habilitación que determina cada cuánto se incrementa el contador.

El contador presenta cuatro dígitos decimales y recorre la secuencia de `0000` a `9999`, reiniciándose al alcanzar el valor máximo.

### Entradas

- `MAX10_CLK1_50`: reloj principal de 50 MHz.
- `SW[1:0]`: selección de la velocidad.
- `KEY[0]`: botón de reinicio activo en bajo.

### Salidas

- `HEX0`: dígito menos significativo.
- `HEX1`: segundo dígito.
- `HEX2`: tercer dígito.
- `HEX3`: dígito más significativo.

## 3. Selección de velocidad

| Switches | Intervalo de conteo |
|---|---|
| `00` | 1 segundo |
| `01` | 0,1 segundos |
| `10` | 0,01 segundos |
| `11` | 0,001 segundos |

## 4. Funcionamiento

El diseño utiliza lógica secuencial para almacenar el estado de cada dígito. Cuando se alcanza el valor establecido por el divisor de frecuencia, el contador avanza una unidad.

El acarreo decimal permite que, cuando un dígito llega a 9, vuelva a cero y aumente el dígito siguiente. Cuando los cuatro dígitos alcanzan `9999`, el sistema vuelve a `0000`.

La función decodificadora transforma cada valor decimal en las señales necesarias para representar los números del 0 al 9 en los displays de siete segmentos.

## 5. Archivos del proyecto

- `cronometro_7seg.v`: descripción del hardware en Verilog HDL.
- `README.md`: documentación del laboratorio.
- `simulacion/`: archivos de simulación y testbench.
- `evidencias/`: capturas de las simulaciones y de la implementación física.

## 6. Simulación

La simulación debe comprobar:

1. El conteo ascendente de los cuatro dígitos.
2. El acarreo entre dígitos al pasar de 9 a 0.
3. El reinicio al presionar `KEY[0]`.
4. El cambio de velocidad al modificar `SW[1:0]`.
5. El retorno a `0000` después de `9999`.

### Evidencias

**Simulación en ModelSim o Questa**

Agregar aquí la captura de las formas de onda.

![Simulación del contador](evidencias/simulacion.png)

**Implementación en la FPGA DE10-Lite**

Agregar aquí una fotografía del circuito funcionando.

![Implementación física](evidencias/implementacion_fpga.jpg)

## 7. Implementación en Quartus Prime

1. Crear un proyecto nuevo en Quartus Prime.
2. Seleccionar el dispositivo correspondiente a la tarjeta DE10-Lite.
3. Agregar `cronometro_7seg.v` al proyecto.
4. Establecer `cronometro_7seg` como entidad de nivel superior (*Top-Level Entity*).
5. Asignar los pines según el manual de la DE10-Lite.
6. Compilar el diseño.
7. Programar la FPGA y comprobar los displays, los switches y el botón de reset.

## 8. Conclusiones

- La lógica secuencial permite implementar contadores capaces de conservar y actualizar su estado.
- El divisor de frecuencia permite controlar la velocidad del conteo a partir del reloj principal de la FPGA.
- El decodificador de siete segmentos permite visualizar los valores almacenados como dígitos decimales.
- Los switches permiten seleccionar la velocidad y el botón de reset restablece el estado inicial.


