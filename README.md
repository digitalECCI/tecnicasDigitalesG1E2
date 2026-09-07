# Informe Lab 01: Introducción a lógica combinacional

**Universidad ECCI**
**Facultad de Ingeniería — Electrónica Digital**

**Autor:** Wilmar Andrey Gil
**Correo:** wilmaran.gilcu@ecci.edu.co
**Autor:** Carlos 
**Correo:** 
**Autor:** 
**Correo:** 

---

## Tabla de contenido

1. [Introducción](#1-introducción)
2. [Objetivos](#2-objetivos)
3. [Marco teórico](#3-marco-teórico)
4. [Desarrollo de la actividad](#4-desarrollo-de-la-actividad)
   - [4.1 Parte 1: Compuertas lógicas](#41-parte-1-compuertas-lógicas)
   - [4.2 Parte 2: Diseño de circuito combinacional](#42-parte-2-diseño-de-circuito-combinacional)
   - [4.3 Parte 3: Sumador de 1 bit](#43-parte-3-sumador-de-1-bit)
5. [Implementación en hardware](#5-implementación-en-hardware)
6. [Resultados y evidencias](#6-resultados-y-evidencias)
7. [Conclusiones](#7-conclusiones)
8. [Estructura del repositorio](#8-estructura-del-repositorio)

---

## 1. Introducción

Este informe documenta el desarrollo del Laboratorio 01 del curso de Electrónica Digital, cuyo propósito es introducir los conceptos fundamentales de la lógica combinacional mediante su descripción, simulación e implementación en hardware utilizando lenguajes de descripción de hardware (HDL). Se aborda el diseño de compuertas lógicas básicas, un circuito detector de números primos y un sumador completo de 1 bit, empleando Verilog como lenguaje de descripción y la tarjeta de desarrollo **DE10-Lite (Intel MAX 10)** como plataforma de implementación física, bajo el entorno de diseño **Quartus Prime**.

## 2. Objetivos

- Diseñar y construir sistemas digitales basados en lógica combinacional, enfocándose en la implementación de sumadores.
- Diseñar, construir e instanciar módulos utilizando lenguajes de descripción de hardware (HDL).
- Familiarizarse con el flujo completo de diseño e implementación en hardware, desde la especificación inicial hasta la síntesis e implementación en FPGA.
- Verificar y validar el funcionamiento del diseño en un entorno de simulación, identificando y corrigiendo errores antes de la implementación física en hardware.
- Explorar la implementación de diseños digitales en una tarjeta de desarrollo basada en FPGA.

## 3. Marco teórico

Un sumador de 1 bit (o sumador completo) es un circuito combinacional que realiza la suma de dos bits de entrada (A y B) junto con un bit de acarreo de entrada (Ci), produciendo un bit de suma (So) y un bit de acarreo de salida (Co). Es uno de los bloques fundamentales para la construcción de sumadores de mayor tamaño, esenciales en las unidades aritméticas de procesadores y sistemas digitales.

**Tabla de verdad del sumador completo:**

| A | B | Ci | Co | So |
|---|---|----|----|----|
| 0 | 0 | 0  | 0  | 0  |
| 0 | 0 | 1  | 0  | 1  |
| 0 | 1 | 0  | 0  | 1  |
| 0 | 1 | 1  | 1  | 0  |
| 1 | 0 | 0  | 0  | 1  |
| 1 | 0 | 1  | 1  | 0  |
| 1 | 1 | 0  | 1  | 0  |
| 1 | 1 | 1  | 1  | 1  |

A partir de la simplificación por maxtérminos se obtienen las ecuaciones que definen el comportamiento del sumador:

```
So = A ⊕ B ⊕ Ci
Co = (A·B) + (Ci·(A⊕B))
```

**Implementación en HDL:** en Verilog, un circuito combinacional puede describirse de forma **estructural**, instanciando explícitamente compuertas mediante operadores lógicos (`&`, `|`, `~`, `^`) que el sintetizador mapea a hardware, o mediante **primitivas** (`and`, `or`, `not`, `xor`, `xnor`), que representan bloques de hardware predefinidos y más cercanos a la implementación física real.

## 4. Desarrollo de la actividad

### 4.1 Parte 1: Compuertas lógicas

Se realizó la descripción en Verilog de las compuertas **NOT, AND, OR, XOR y XNOR**, cada una en dos versiones: mediante primitivas y mediante comportamiento estructural con operadores lógicos. Cada compuerta fue verificada mediante simulación, comprobando su tabla de verdad correspondiente con un testbench dedicado.



### 4.2 Parte 2: Diseño de circuito combinacional

Se diseñó un circuito combinacional capaz de determinar si un número binario de 3 bits corresponde a un número primo. Los números primos considerados dentro del rango representable (0–7) son **2, 3, 5 y 7**. El circuito fue descrito en Verilog y validado mediante simulación recorriendo las 8 combinaciones posibles de entrada.


### 4.3 Parte 3: Sumador de 1 bit

Se implementó de forma estructural el sumador completo de 1 bit descrito en el marco teórico, a partir de las ecuaciones de So y Co. El diseño fue verificado mediante simulación, comprobando las 8 combinaciones posibles de A, B y Ci contra la tabla de verdad, y posteriormente sintetizado e implementado en la tarjeta DE10-Lite.


## 5. Implementación en hardware

El sumador completo de 1 bit (Parte 3) fue sintetizado e implementado sobre la tarjeta de desarrollo **DE10-Lite (Intel MAX 10)** utilizando el entorno **Quartus Prime**. Se realizó la asignación de pines correspondiente a las entradas (A, B, Ci) y salidas (So, Co) del circuito, empleando los switches y LEDs disponibles en la tarjeta como periféricos de entrada/salida.



## 6. Resultados y evidencias

Las capturas de las formas de onda (waveforms) de cada simulación, así como las evidencias fotográficas/video del funcionamiento en hardware, se encuentran documentadas en las respectivas carpetas `sim/` de cada parte y en `docs/images/`.

## 7. Conclusiones

*(Espacio para completar con las conclusiones propias del desarrollo del laboratorio: aprendizajes obtenidos sobre lógica combinacional, diferencias entre descripción estructural y por primitivas, dificultades encontradas durante la síntesis/implementación en la DE10-Lite, y posibles mejoras al diseño.)*

## 8. Estructura del repositorio

```
Lab01-Logica-Combinacional/
├── README.md                          # Este informe
├── docs/
│   └── images/                        # Figuras, tablas de verdad, capturas, diagramas RTL
├── Parte1_CompuertasLogicas/
│   ├── src/
│   │   ├── primitivas/                # Implementación con primitivas Verilog
│   │   └── estructural/               # Implementación con operadores lógicos
│   ├── tb/                            # Testbenches de cada compuerta
│   └── sim/                           # Evidencias de simulación
├── Parte2_DetectorPrimos/
│   ├── src/                           # Módulo detector de número primo de 3 bits
│   ├── tb/                            # Testbench del detector
│   └── sim/                           # Evidencias de simulación
├── Parte3_SumadorCompleto/
│   ├── src/                           # Módulo full adder (sumador de 1 bit)
│   ├── tb/                            # Testbench del sumador
│   ├── sim/                           # Evidencias de simulación
│   └── quartus/                       # Proyecto Quartus, pin assignments, evidencia en hardware
└── LICENSE
```

## Herramientas utilizadas

- **HDL:** Verilog
- **Simulación:** ModelSim / Questa (o el simulador integrado en Quartus)
- **Síntesis e implementación:** Intel Quartus Prime
- **Tarjeta de desarrollo:** DE10-Lite (Intel MAX 10)





