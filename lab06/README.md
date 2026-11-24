# FSM Caja Fuerte con clave de 3 dígitos

**Universidad ECCI**
**Facultad de Ingeniería — Electrónica Digital**

**Autor:** Carlos Rafael Herrera Gamarra

---

## 1. Descripción

Máquina de estados finitos (Moore) que controla una caja fuerte con clave de 3 dígitos hexadecimales (0..F):

- El usuario coloca un dígito en los switches y lo confirma con `enter_pulse` (pulso de 1 ciclo). Se repite 3 veces.
- Al tercer dígito se compara la clave completa (sin revelar cuál dígito falló):
  - **Correcta** → `ABIERTA` (`servo_open = 1`, `led_green = 1`).
  - **Incorrecta** → se descuenta un intento y vuelve a pedir el primer dígito.
  - **Sin intentos** → `BLOQUEADA` (`led_red = 1`).
- En `ABIERTA`, un `enter_pulse` cierra la caja y vuelve a pedir clave.
- `master_reset_pulse` o `reset_n` (asíncrono, activo en bajo) salen de cualquier estado y restablecen los 3 intentos.

La clave se configura con los parámetros `CLAVE_1`, `CLAVE_2` y `CLAVE_3`.

## 2. Estados

| Estado | `display_mode` | `display_value` | Salidas |
|---|---|---|---|
| `S_DIG1` | 0 | switches | — |
| `S_DIG2` | 1 | switches | — |
| `S_DIG3` | 2 | switches | — |
| `S_ABIERTA` | 3 | 0 | `servo_open`, `led_green` |
| `S_BLOQUEO` | 4 | 0 | `led_red` |

## 3. Estructura

```
fsm_caja_fuerte.v   Módulo de la FSM
tb_caja_fuerte.v    Testbench (incluye fsm_caja_fuerte.v)
```

## 4. Simulación

Con Icarus Verilog:

```
iverilog -o build/tb.out tb_caja_fuerte.v
vvp build/tb.out
gtkwave caja_fuerte.vcd
```

El testbench usa la clave `3-A-7` y verifica:

| Prueba | Entrada | Resultado esperado |
|---|---|---|
| 1 | `3-A-7` | Caja abierta |
| 2 | `1-2-3` | Quedan 2 intentos |
| 3 | `1-2-3` | Queda 1 intento |
| 4 | `1-2-3` | Caja bloqueada |

Salida obtenida:

```
PRUEBA 1: CLAVE CORRECTA
CORRECTO: CAJA ABIERTA
PRUEBA 2: PRIMER ERROR
CORRECTO: QUEDAN 2 INTENTOS
PRUEBA 3: SEGUNDO ERROR
CORRECTO: QUEDA 1 INTENTO
PRUEBA 4: TERCER ERROR
CORRECTO: CAJA BLOQUEADA
FIN DE LAS PRUEBAS
```
