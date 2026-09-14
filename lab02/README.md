# Sumador/Restador de 4 bits mediante instancias en Verilog

Laboratorio de Electrónica Digital — Diseño estructural con reutilización del sumador de 1 bit para implementar operaciones de suma y resta en un sumador de 4 bits, usando la tarjeta de desarrollo DE10-Lite y la IDE Quartus.

## Integrantes

| Nombre completo | Código |
|---|---|
| Wilmar Andrey Gil | 127037|
| Andres Felipe Martin Torres |136881  |
|  |  |
|  |  |

## 1. Objetivos de aprendizaje

- Reutilizar un sumador de 4 bits para operaciones de resta mediante instancias.
- Aprender a verificar y validar el funcionamiento del diseño en un entorno de simulación, identificando y corrigiendo errores antes de la implementación física en hardware.

## 2. Fundamento teórico

### 2.1 Sumador de 4 bits

Para crear un sumador de 4 bits se utilizan cuatro sumadores de 1 bit conectados en serie: el acarreo de salida de un sumador de 1 bit se convierte en el acarreo de entrada del siguiente sumador, mientras que cada bit de los dos números que se están sumando se procesa en paralelo.

Para construir el sumador de 4 bits utilizando el sumador de 1 bit como módulo base, se instancian varios módulos del sumador de 1 bit y se conectan sus entradas y salidas de manera que se propague correctamente el acarreo entre cada posición.

Un sumador de 4 bits toma dos números de 4 bits (`A[3:0]` y `B[3:0]`) y produce una suma de 4 bits (`So[3:0]`) junto con un acarreo de salida (`Co`). Cada uno de los 4 sumadores de 1 bit maneja una posición de `So` (0 a 3) y el acarreo hacia la siguiente posición.

Esta implementación mediante instancias del sumador de 1 bit es un ejemplo de **diseño estructural** en HDL, donde un módulo previamente definido se reutiliza como bloque de construcción de un diseño más grande y de mayor jerarquía.

**Funcionamiento:**

- Cada instancia del sumador de 1 bit toma un bit de `A`, un bit de `B` y un acarreo de entrada `Ci`. Calcula la suma de estos bits y produce una suma de un bit `So` y un acarreo de salida `Co`.
- El acarreo de salida de un sumador de 1 bit se usa como acarreo de entrada del siguiente sumador de 1 bit en la cadena.
- El sumador de 4 bits produce una salida final `So` de 4 bits y un acarreo de salida final `Co`.

### 2.2 De sumador a restador: reutilización mediante instancias

Para reutilizar el sumador de 4 bits como restador sin crear un módulo nuevo desde cero, se aplica el principio de la **resta por complemento a 2**:

```
A - B = A + (~B) + 1
```

Esto se logra agregando al diseño estructural:

1. Una compuerta XOR en cada bit de `B`, controlada por una señal `Sub`. Cuando `Sub = 0`, `B` pasa sin cambios (modo suma). Cuando `Sub = 1`, cada bit de `B` se invierte (complemento a 1).
2. La misma señal `Sub` se conecta como acarreo de entrada (`Ci`) de la primera instancia del sumador de 1 bit, inyectando el "+1" necesario para completar el complemento a 2 cuando se resta.

De esta manera, **el mismo módulo `full_adder` se reutiliza sin modificaciones**; el cambio de comportamiento (suma o resta) se logra únicamente con lógica adicional alrededor de las instancias, cumpliendo con el objetivo de reutilizar el sumador mediante instancias para realizar operaciones de resta.

### 2.3 Concepto de instancia en HDL

En el contexto de diseño digital y descripción HDL, una **instancia** se refiere a la creación de un módulo a partir de una definición previamente declarada. Instanciar un módulo significa utilizarlo como un bloque dentro de un diseño más grande, proporcionando conexiones específicas para sus entradas y salidas.

En Verilog se utiliza la siguiente sintaxis:

```verilog
module_name instance_name(.port_0(signal_0), ..., .port_n(signal_n));
```

Donde:

- `module_name`: nombre del módulo que se desea instanciar.
- `instance_name`: nombre de la instancia a nivel local.
- `port_0 ... port_n`: nombres de los puertos declarados como entrada o salida en el prototipo del módulo instanciado.
- `signal_0 ... signal_n`: nombres de las señales del módulo actual que se conectan a dichos puertos.

## 3. Descripción de hardware (RTL)

### 3.1 Diagrama de bloques

```
                Sub
                 │
        ┌────────┼────────┬────────┬────────┐
        │        │         │        │
      B[0]─XOR B[1]─XOR  B[2]─XOR B[3]─XOR
        │        │         │        │
 A[0] ┌─▼─┐  A[1]┌─▼─┐ A[2]┌─▼─┐ A[3]┌─▼─┐
 ────►│FA0│─Co─►│FA1│─Co─►│FA2│─Co─►│FA3│───► Co (final)
 Sub─►│Ci │      │Ci │      │Ci │      │Ci │
      └─┬─┘      └─┬─┘      └─┬─┘      └─┬─┘
        │So[0]     │So[1]     │So[2]     │So[3]
```

### 3.2 Módulo base: `full_adder` (sumador completo de 1 bit)

Archivo: [`src/full_adder.v`](src/full_adder.v)

```verilog
module full_adder(
    input  wire A,
    input  wire B,
    input  wire Ci,
    output wire So,
    output wire Co
);
    assign So = A ^ B ^ Ci;
    assign Co = (A & B) | (B & Ci) | (A & Ci);
endmodule
```

### 3.3 Módulo estructural: `adder_subtractor_4bit`

Archivo: [`src/adder_subtractor_4bit.v`](src/adder_subtractor_4bit.v)

Este módulo instancia 4 veces `full_adder` y agrega las compuertas XOR de control de resta descritas en la sección 2.2:

```verilog
module adder_subtractor_4bit(
    input  wire [3:0] A,
    input  wire [3:0] B,
    input  wire       Sub,
    output wire [3:0] So,
    output wire       Co
);
    wire c0, c1, c2;
    wire [3:0] B_xor = B ^ {4{Sub}};

    full_adder FA0 (.A(A[0]), .B(B_xor[0]), .Ci(Sub), .So(So[0]), .Co(c0));
    full_adder FA1 (.A(A[1]), .B(B_xor[1]), .Ci(c0),  .So(So[1]), .Co(c1));
    full_adder FA2 (.A(A[2]), .B(B_xor[2]), .Ci(c1),  .So(So[2]), .Co(c2));
    full_adder FA3 (.A(A[3]), .B(B_xor[3]), .Ci(c2),  .So(So[3]), .Co(Co));
endmodule
```

## 4. Simulación

El testbench se encuentra en [`testbench/tb_adder_subtractor_4bit.v`](testbench/tb_adder_subtractor_4bit.v). Recorre exhaustivamente las 16×16 combinaciones de `A` y `B` en modo suma (`Sub=0`) y luego en modo resta (`Sub=1`), comparando cada resultado del DUT contra el valor esperado calculado por el propio testbench, e imprime `OK` o `<-- ERROR` en cada caso.

### 4.1 Cómo simular

**Opción A — ModelSim/Questa/Quartus:**

1. Crear un proyecto nuevo en Quartus y agregar `src/full_adder.v`, `src/adder_subtractor_4bit.v` y `testbench/tb_adder_subtractor_4bit.v`.
2. Configurar `tb_adder_subtractor_4bit` como módulo top de simulación.
3. Ejecutar la simulación funcional (RTL) y revisar la consola/waveform.

**Opción B — Icarus Verilog (línea de comandos):**

```bash
iverilog -o sim.out src/full_adder.v src/adder_subtractor_4bit.v testbench/tb_adder_subtractor_4bit.v
vvp sim.out
```

### 4.2 Evidencias de simulación

> Agregar aquí las capturas de pantalla de la consola y/o formas de onda (waveform) de la simulación, guardadas en `docs/imagenes/`.


### 4.3 Casos de prueba relevantes

| A | B | Sub | So esperado | Co esperado | Observación |
|---|---|-----|-------------|-------------|-------------|
| 0011 (3) | 0010 (2) | 0 | 0101 (5) | 0 | Suma simple |
| 1111 (15) | 0001 (1) | 0 | 0000 (0) | 1 | Overflow / acarreo de salida |
| 0101 (5) | 0011 (3) | 1 | 0010 (2) | 1 | Resta sin préstamo (A > B) |
| 0011 (3) | 0101 (5) | 1 | 1110 (-2 en C2) | 0 | Resta con préstamo (A < B) |

## 5. Implementación en hardware (DE10-Lite / Quartus)

- **Tarjeta de desarrollo:** DE10-Lite (FPGA Intel MAX 10).
- **IDE:** Quartus Prime.
- **Entradas sugeridas:** interruptores `SW[7:0]` para `A[3:0]` y `B[3:0]`, `SW[8]` o un pulsador `KEY` para `Sub`.
- **Salidas sugeridas:** LEDs para `So[3:0]` y `Co`, o visualización en display de 7 segmentos.

> Agregar aquí la asignación de pines (`Pin Planner`), fotografías o video del funcionamiento en la tarjeta física.


## 6. Estructura del repositorio

```
lab02/
├── README.md
├── src/
│   ├── full_adder.v
│   └── adder_subtractor_4bit.v
├── testbench/
│   └── tb_adder_subtractor_4bit.v
└── docs/
    └── imagenes/
```

## 7. Conclusiones

- El diseño estructural del sumador/restador de 4 bits funcionó tal como se planteó en la etapa de programación: los resultados obtenidos en simulación coincidieron con los valores esperados tanto en modo suma (`Sub = 0`) como en modo resta (`Sub = 1`), validando que la lógica de complemento a 2 aplicada mediante las compuertas XOR y el acarreo de entrada era correcta.
- Se comprobó en la práctica el concepto de **instanciación**: bastó con reutilizar cuatro veces el mismo módulo `full_adder` (sumador de 1 bit), sin modificar su descripción interna, para construir un módulo de mayor jerarquía capaz de sumar y restar números de 4 bits. Esto evidencia la ventaja del diseño estructural frente a describir toda la lógica de manera plana: un bloque base bien verificado puede reutilizarse tantas veces como sea necesario simplemente conectando sus puertos.
- La simulación exhaustiva (recorriendo todas las combinaciones posibles de `A` y `B` en ambos modos) permitió verificar el funcionamiento del diseño antes de pasar a la tarjeta física, cumpliendo con el objetivo de detectar y corregir errores en un entorno controlado en lugar de depender únicamente de pruebas en hardware.
- El uso de una sola señal de control (`Sub`) para alternar entre suma y resta demuestra que, con una modificación mínima alrededor de las instancias existentes, un mismo bloque de hardware puede ampliar su funcionalidad sin duplicar lógica.

<img width="1093" height="1280" alt="image" src="https://github.com/user-attachments/assets/6d52e8da-7d28-49aa-b69a-781ff6e4c980" />
<img width="720" height="1280" alt="image" src="https://github.com/user-attachments/assets/08203dc2-86cd-4a38-9878-ec81cd9babd9" />

<img width="591" height="1280" alt="image" src="https://github.com/user-attachments/assets/336805d6-f7fc-42ca-8a91-a4c3bbd1c53e" />
