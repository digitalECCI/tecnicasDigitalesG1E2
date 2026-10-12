# Laboratorio 03: Implementación de display de 7 segmentos

**Asignatura:** Sistemas Digitales / Lógica Digital  
**Tarjeta de desarrollo:** Intel/Altera DE10-Lite  
**Herramienta:** Quartus Prime y simulador HDL  
**Estudiante(s):** Wilmar Andrey Gil 127037 - Andres Felipe Martn Torres 136881

## 1. Objetivos

### Objetivo general
Implementar en Verilog HDL la decodificación de un display de siete segmentos y visualizar el resultado de la suma de dos números binarios de tres bits en la tarjeta DE10-Lite.

### Objetivos específicos
- Visualizar los dígitos del 0 al 9 en un display, usando los switches como entrada.
- Modificar el decodificador para mostrar los símbolos hexadecimales del 0 al F.
- Implementar un sumador de dos operandos de tres bits y representar su resultado en hexadecimal.
- Simular los diseños y comprobar su funcionamiento antes de programar la FPGA.

## 2. Fundamento teórico

### 2.1. BCD y representación hexadecimal

BCD (*Binary Coded Decimal*, decimal codificado en binario) representa cada dígito decimal mediante cuatro bits. En BCD son válidas las combinaciones de `0000` a `1001`, correspondientes a los dígitos del 0 al 9. Las combinaciones de `1010` a `1111` no representan dígitos BCD válidos.

En cambio, un número de cuatro bits puede representar los 16 valores hexadecimales del 0 al F:

| Decimal | Hexadecimal | Binario |
|---:|:---:|:---:|
| 0 | 0 | 0000 |
| 1 | 1 | 0001 |
| 2 | 2 | 0010 |
| 3 | 3 | 0011 |
| 4 | 4 | 0100 |
| 5 | 5 | 0101 |
| 6 | 6 | 0110 |
| 7 | 7 | 0111 |
| 8 | 8 | 1000 |
| 9 | 9 | 1001 |
| 10 | A | 1010 |
| 11 | B | 1011 |
| 12 | C | 1100 |
| 13 | D | 1101 |
| 14 | E | 1110 |
| 15 | F | 1111 |

### 2.2. Display de siete segmentos

Un display de siete segmentos contiene siete elementos luminosos identificados como `a`, `b`, `c`, `d`, `e`, `f` y `g`. Al activar diferentes combinaciones se representan números y algunos caracteres hexadecimales.

La DE10-Lite utiliza displays de siete segmentos con señales activas en nivel bajo: un bit `0` enciende el segmento y un bit `1` lo apaga. Por eso, en el código se usa una tabla de patrones activa en bajo. El orden de bits adoptado en este informe es `{g,f,e,d,c,b,a}`; se debe conservar este orden al asignar los pines.

### 2.3. Sumador de tres bits

Cada operando tiene tres bits y puede tomar valores entre 0 y 7. La suma máxima es:

`7 + 7 = 14`

Por tanto, el resultado necesita cuatro bits. Un resultado de cuatro bits representa directamente un valor hexadecimal entre 0 y E, que se puede mostrar en un solo display.

## 3. Descripción del hardware

### Parte 1. Decodificador de siete segmentos

- **Entradas:** `SW[3:0]`, que seleccionan un valor entre 0 y 15.
- **Salida:** `HEX0[6:0]`, que controla los siete segmentos del primer display.
- **Modo decimal:** se muestran los valores 0–9; para las entradas A–F se apaga el display.
- **Modo hexadecimal:** se muestran los valores 0–F.

Para elegir el modo se usa `SW[9]`: en `0` se selecciona el modo decimal y en `1` el modo hexadecimal.

### Parte 2. Sumador de dos números de tres bits

- **Primer operando:** `SW[2:0]`.
- **Segundo operando:** `SW[5:3]`.
- **Resultado:** suma de cuatro bits mostrada en `HEX0[6:0]`.

Los switches de la tarjeta son las entradas físicas y `HEX0` es la salida visual. Las asignaciones de pines deben corresponder al archivo de restricciones de la DE10-Lite utilizado en Quartus.

## 4. Implementación HDL

Guarde los siguientes módulos en archivos `.v` independientes o adapte los nombres a la estructura de su proyecto.

### 4.1. Decodificador decimal/hexadecimal (`display_7seg.v`)

```verilog
module display_7seg (
    input  wire [3:0] x,
    input  wire       modo_hex, // 0: decimal (0-9), 1: hexadecimal (0-F)
    output reg  [6:0] HEX0
);

    // Orden de bits: {g,f,e,d,c,b,a}. Salidas activas en bajo.
    always @(*) begin
        if (!modo_hex && x > 4'd9) begin
            HEX0 = 7'b1111111; // Apagar el display en modo decimal para A-F
        end else begin
            case (x)
                4'h0: HEX0 = 7'b1000000;
                4'h1: HEX0 = 7'b1111001;
                4'h2: HEX0 = 7'b0100100;
                4'h3: HEX0 = 7'b0110000;
                4'h4: HEX0 = 7'b0011001;
                4'h5: HEX0 = 7'b0010010;
                4'h6: HEX0 = 7'b0000010;
                4'h7: HEX0 = 7'b1111000;
                4'h8: HEX0 = 7'b0000000;
                4'h9: HEX0 = 7'b0010000;
                4'hA: HEX0 = 7'b0001000;
                4'hB: HEX0 = 7'b0000011;
                4'hC: HEX0 = 7'b1000110;
                4'hD: HEX0 = 7'b0100001;
                4'hE: HEX0 = 7'b0000110;
                4'hF: HEX0 = 7'b0001110;
                default: HEX0 = 7'b1111111;
            endcase
        end
    end

endmodule
```

### 4.2. Sumador de dos operandos de tres bits (`sumador_3bits.v`)

```verilog
module sumador_3bits (
    input  wire [2:0] A,
    input  wire [2:0] B,
    output wire [3:0] S,
    output reg  [6:0] HEX0
);

    assign S = {1'b0, A} + {1'b0, B};

    // Orden de bits: {g,f,e,d,c,b,a}. Salidas activas en bajo.
    always @(*) begin
        case (S)
            4'h0: HEX0 = 7'b1000000;
            4'h1: HEX0 = 7'b1111001;
            4'h2: HEX0 = 7'b0100100;
            4'h3: HEX0 = 7'b0110000;
            4'h4: HEX0 = 7'b0011001;
            4'h5: HEX0 = 7'b0010010;
            4'h6: HEX0 = 7'b0000010;
            4'h7: HEX0 = 7'b1111000;
            4'h8: HEX0 = 7'b0000000;
            4'h9: HEX0 = 7'b0010000;
            4'hA: HEX0 = 7'b0001000;
            4'hB: HEX0 = 7'b0000011;
            4'hC: HEX0 = 7'b1000110;
            4'hD: HEX0 = 7'b0100001;
            4'hE: HEX0 = 7'b0000110;
            default: HEX0 = 7'b1111111;
        endcase
    end

endmodule
```

## 5. Procedimiento

1. Crear un proyecto en Quartus Prime y seleccionar la FPGA correspondiente a la tarjeta DE10-Lite.
2. Crear el archivo Verilog del decodificador y definirlo como módulo superior para la Parte 1.
3. Asignar `SW[3:0]`, `SW[9]` y `HEX0[6:0]` a los pines físicos correctos usando el archivo de asignaciones de la DE10-Lite.
4. Compilar el diseño y corregir los errores reportados por Quartus.
5. Simular las entradas de 0 a 9 en modo decimal y de 0 a F en modo hexadecimal.
6. Crear el módulo del sumador, definirlo como módulo superior para la Parte 2 y asignar `SW[5:0]` y `HEX0[6:0]`.
7. Simular varias combinaciones, incluyendo `000 + 000`, `001 + 010`, `011 + 100` y `111 + 111`.
8. Programar la FPGA y comprobar las salidas con los switches y el display de la tarjeta.

## 6. Pruebas y resultados

**Importante:** sustituya esta sección por los resultados reales de su simulación y de la prueba física. No marque una prueba como exitosa sin haberla ejecutado.

### 6.1. Parte 1: decodificador

| Modo | Entrada | Resultado esperado |
|---|---|---|
| Decimal | `0000`–`1001` | Muestra 0–9 |
| Decimal | `1010`–`1111` | Display apagado |
| Hexadecimal | `0000`–`1111` | Muestra 0–F |

**Evidencia de simulación — Parte 1**

Agregue aquí una captura de la forma de onda del simulador donde se observen las entradas `x`, `modo_hex` y la salida `HEX0`.

`![Simulación Parte 1](evidencias/parte1_simulacion.png)`

**Evidencia en la tarjeta — Parte 1**

Agregue una fotografía del display mostrando algunos valores de prueba.

`![Prueba física Parte 1](evidencias/parte1_tarjeta.jpg)`

### 6.2. Parte 2: sumador

| A | B | Suma decimal | Resultado hexadecimal |
|---:|---:|---:|:---:|
| 000 | 000 | 0 | 0 |
| 001 | 010 | 3 | 3 |
| 011 | 100 | 7 | 7 |
| 101 | 010 | 7 | 7 |
| 111 | 111 | 14 | E |

**Evidencia de simulación — Parte 2**

Agregue aquí una captura de la forma de onda del simulador con `A`, `B`, `S` y `HEX0`.

`![Simulación Parte 2](evidencias/parte2_simulacion.png)`

**Evidencia en la tarjeta — Parte 2**

Agregue una fotografía de la FPGA mostrando un resultado de prueba.

`![Prueba física Parte 2](evidencias/parte2_tarjeta.jpg)`

## 7. Análisis

El decodificador convierte una entrada binaria de cuatro bits en una combinación de segmentos que permite representar números. En el modo decimal solo son válidos los códigos de 0 a 9; en el modo hexadecimal se aprovechan las 16 combinaciones posibles.

El sumador combina dos operandos de tres bits y genera un resultado de cuatro bits. Como el valor máximo es 14, un único display puede mostrar toda la suma en hexadecimal. La polaridad activa en bajo debe considerarse al definir los patrones de salida para la DE10-Lite.

Complete este análisis con las observaciones obtenidas en las simulaciones y en la prueba sobre la tarjeta.

## 8. Conclusiones

- Se describe la conversión de un número binario a señales para un display de siete segmentos.
- Se distingue entre la representación decimal BCD y la representación hexadecimal de cuatro bits.
- El sumador de dos operandos de tres bits requiere cuatro bits para representar el resultado máximo de 14.
- La validación final depende de comprobar las formas de onda, las asignaciones de pines y el funcionamiento real en la DE10-Lite.

## 9. Estructura sugerida del repositorio

```text
Lab03-7-segmentos/
├── README.md
├── src/
│   ├── display_7seg.v
│   └── sumador_3bits.v
└── evidencias/
    ├── parte1_simulacion.png
    ├── parte1_tarjeta.jpg
    ├── parte2_simulacion.png
    └── parte2_tarjeta.jpg
```
