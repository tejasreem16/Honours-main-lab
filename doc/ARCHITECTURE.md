# RISC-V Based Smart Control SoC — Architecture & Design Specification

**Project:** RISC-V Based Smart Control SoC with PWM, SPI and Seven-Segment Display
**Document type:** Architecture Specification (feed this to Kiro CLI / Antigravity CLI as the primary spec)
**Status:** Draft v1.0

> **Note to AI coding agent (Kiro / Antigravity):** This document is the single source of truth for the
> RTL, testbench, and register implementation of this SoC. Do not assume undocumented behavior. If a
> signal, register, timing requirement, or error condition is not explicitly defined here, treat it as
> **out of scope** and flag it rather than inventing a default. Section numbers below map 1:1 to the
> sections required in the project's architecture-document checklist.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Block Diagram](#2-block-diagram)
3. [Memory Map](#3-memory-map)
4. [Signal List](#4-signal-list)
5. [Register Description](#5-register-description)
6. [Control Paths](#6-control-paths)
7. [Data Paths](#7-data-paths)
8. [Interrupts](#8-interrupts)
9. [Error Cases](#9-error-cases)
10. [Application](#10-application-brief--full-detail-in-section-11)
11. [Application — Full Detail](#11-application-full-detail)
12. [Verification Plan](#12-verification-plan)
13. [Repository / Directory Structure](#13-repository--directory-structure)

---

## 1. Introduction

Modern embedded systems must control multiple hardware peripherals — displays, communication
interfaces, and actuators — at once. Handling all of this purely in software increases processor
workload and reduces system efficiency. This project implements a compact, programmable
**System-on-Chip (SoC)** that integrates a RISC-V processor, instruction/data memory, standard
peripherals, and three dedicated hardware IPs (PWM Generator, SPI Controller, Seven-Segment Display
Controller) behind a single memory-mapped bus.

The processor configures and drives every peripheral purely through **memory-mapped registers** — one
address space, one access mechanism (read/write), no bespoke instructions per device. Dedicated
hardware handles all time-critical work (PWM waveform generation, SPI clocking/shifting, 7-segment
multiplexing) independently of the processor once configured.

The application (see [Section 11](#11-application-full-detail) for full detail) initializes all
peripherals, drives a PWM output, performs an SPI transaction, displays a live value on the
seven-segment display, and reports status over UART.

The system is verified through RTL simulation and demonstrated on FPGA hardware.

---

## 2. Block Diagram

```
                                   +------------------------+
                                   |     RISC-V Processor    |
                                   |   (provided core, e.g.   |
                                   |   RV32I, single-issue)   |
                                   +-----------+--------------+
                                               |
                              imem_* |         | dmem_* / periph bus
                    +------------------+       |
                    |                  |       |
            +-------v------+   +-------v------+|
            | Instruction  |   |  Data Memory  ||
            |   Memory     |   |    (SRAM)     ||
            +--------------+   +---------------+
                                               |
                                   (SPB - Simple Peripheral Bus)
                                               |
                    +--------------------------v---------------------------+
                    |               Bus Interconnect / Decoder              |
                    |   decodes p_addr[31:0] -> one-hot p_sel[7:0]         |
                    +---+------+------+------+------+------+------+---+----+
                        |      |      |      |      |      |      |
                     sel[0] sel[1] sel[2] sel[3] sel[4] sel[5] sel[6]
                        |      |      |      |      |      |      |
                  +-----v--+ +-v----+ +v-----+ +v-----+ +v-----+ +v------+
                  |  UART  | |Timer | | GPIO | | PWM  | | SPI  | |7-SEG  |
                  |        | |      | |      | | Gen  | |Ctrl  | |Ctrl   |
                  +--+--+--+ +--+---+ +--+---+ +--+---+ +--+-+-+ +---+---+
                     |  |       |        |        |        | |       |
                   uart_tx uart_rx timer_irq gpio[7:0] pwm_out spi_sck/  seg[6:0]
                                                              mosi/miso/  an[3:0]
                                                              cs_n

              Interrupt lines (uart_irq, timer_irq, gpio_irq, spi_irq) are OR-reduced /
              aggregated into a single external interrupt input on the RISC-V core, with
              per-source pending bits visible in each IP's STATUS register
              (see Section 8, Interrupts).
```

**Top-level ports (chip/FPGA boundary):**

| Port | Direction | Width | Connects to |
|---|---|---|---|
| `clk` | in | 1 | Global clock, drives processor + all IPs |
| `rst_n` | in | 1 | Active-low async assert / sync de-assert reset |
| `uart_tx` | out | 1 | UART Controller |
| `uart_rx` | in | 1 | UART Controller |
| `gpio[7:0]` | inout | 8 | GPIO |
| `pwm_out` | out | 1 | PWM Generator |
| `spi_sck` | out | 1 | SPI Controller |
| `spi_mosi` | out | 1 | SPI Controller |
| `spi_miso` | in | 1 | SPI Controller |
| `spi_cs_n` | out | 1 | SPI Controller |
| `seg[6:0]` | out | 7 | Seven-Segment Display Controller (segments a–g) |
| `dp` | out | 1 | Seven-Segment Display Controller (decimal point) |
| `an[3:0]` | out | 4 | Seven-Segment Display Controller (digit/anode select, active per multiplex scheme in 7.3) |

---

## 3. Memory Map

All peripherals are 4 KB-aligned regions on a 32-bit address space. Register offsets within each block
are given in [Section 5](#5-register-description).

| Base Address | End Address | Size | Block | Notes |
|---|---|---|---|---|
| `0x0000_0000` | `0x0000_FFFF` | 64 KB | Instruction Memory (IMEM) | Program storage, word-addressed |
| `0x1000_0000` | `0x1000_FFFF` | 64 KB | Data Memory (DMEM) | Application data / stack / heap |
| `0x2000_0000` | `0x2000_0FFF` | 4 KB | UART | Mandatory peripheral |
| `0x2000_1000` | `0x2000_1FFF` | 4 KB | Timer | Mandatory peripheral |
| `0x2000_2000` | `0x2000_2FFF` | 4 KB | GPIO | Mandatory peripheral |
| `0x3000_0000` | `0x3000_0FFF` | 4 KB | PWM Generator | Additional IP |
| `0x3000_1000` | `0x3000_1FFF` | 4 KB | SPI Controller | Additional IP |
| `0x3000_2000` | `0x3000_2FFF` | 4 KB | Seven-Segment Display Controller | Additional IP |
| `0x4000_0000+` | — | — | Reserved | Any access here is an error condition — see Section 9 |

Address decode rule: bits `[31:12]` select the region/peripheral; bits `[11:0]` select the register
offset within that peripheral. Any address that does not match a defined region returns a bus error
response (`p_err = 1`) — see [Section 9](#9-error-cases).

---

## 4. Signal List

Signals are grouped as: **Boundary** (top-level chip I/O), **Bus/Interconnect** (processor ↔
interconnect ↔ peripheral), and **Internal** (inside each IP, not visible outside its own module).

### 4.1 System-Level Signals (Boundary)

| Signal | Dir | Width | Type | Description |
|---|---|---|---|---|
| `clk` | in | 1 | control | System clock |
| `rst_n` | in | 1 | control | Active-low reset |

### 4.2 Bus / Interconnect Signals (Cross-IP — shared by every peripheral)

This is the **Simple Peripheral Bus (SPB)**: a single-master, multi-slave, synchronous bus used by the
processor to reach every mandatory/additional IP. It is intentionally simple (APB-like) since all
peripherals are low-bandwidth, register-driven blocks.

| Signal | Dir (master→slave unless noted) | Width | Type | Description |
|---|---|---|---|---|
| `p_addr` | M→S | 32 | control | Byte address of the register being accessed |
| `p_wdata` | M→S | 32 | data | Write data |
| `p_we` | M→S | 1 | control | Write enable (1 = write, 0 = read) |
| `p_sel` | M→S | 1 per slave | control | One-hot slave select, generated by address decoder |
| `p_enable` | M→S | 1 | control | Bus transfer qualifier (asserted 1 cycle after `p_sel`, APB-style setup/access phases) |
| `p_rdata` | S→M | 32 | data | Read data, driven by the selected slave |
| `p_ready` | S→M | 1 | control | Slave ready (1 = transfer completes this cycle) |
| `p_err` | S→M | 1 | status | Bus error (invalid address / illegal access — see Section 9) |

### 4.3 UART — Internal Signals

| Signal | Dir | Width | Type | Description |
|---|---|---|---|---|
| `tx_shift_reg` | internal | 8 | data | Parallel-in/serial-out shift register for TX |
| `rx_shift_reg` | internal | 8 | data | Serial-in/parallel-out shift register for RX |
| `baud_tick` | internal | 1 | control | Baud-rate generator tick, derived from `BAUD_DIV` |
| `tx_busy` | internal | 1 | status | TX shift in progress |
| `rx_busy` | internal | 1 | status | RX shift in progress |
| `frame_err` | internal | 1 | status | Stop-bit not sampled high → framing error (non-fatal, Section 9) |
| `uart_tx` | boundary out | 1 | data | Serial transmit line |
| `uart_rx` | boundary in | 1 | data | Serial receive line |
| `uart_irq` | cross-IP out | 1 | status | Asserted per Section 8 conditions |

### 4.4 Timer — Internal Signals

| Signal | Dir | Width | Type | Description |
|---|---|---|---|---|
| `count_reg` | internal | 32 | data | Live down-counter value (mirrored to `TIMER_COUNT`) |
| `reload_pulse` | internal | 1 | control | Asserted 1 cycle when counter hits zero and auto-reload is enabled |
| `timer_irq` | cross-IP out | 1 | status | Asserted per Section 8 conditions |

### 4.5 GPIO — Internal Signals

| Signal | Dir | Width | Type | Description |
|---|---|---|---|---|
| `gpio_in_sync` | internal | 8 | data | 2-flop synchronizer output for input pins |
| `gpio_edge_det` | internal | 8 | status | Per-bit edge-detect (configurable rising/falling via `GPIO_INTCFG`) |
| `gpio[7:0]` | boundary inout | 8 | data | Physical GPIO pins |
| `gpio_irq` | cross-IP out | 1 | status | Asserted per Section 8 conditions |

### 4.6 PWM Generator — Internal Signals

| Signal | Dir | Width | Type | Description |
|---|---|---|---|---|
| `pwm_counter` | internal | 16 | data | Free-running counter, compared against `PWM_PERIOD` |
| `duty_cmp` | internal | 1 | control | `pwm_counter < PWM_DUTY` comparator output, drives `pwm_out` |
| `period_pulse` | internal | 1 | status | Asserted 1 cycle when `pwm_counter` wraps (period complete) |
| `pwm_out` | boundary out | 1 | data | PWM waveform output |

### 4.7 SPI Controller — Internal Signals

| Signal | Dir | Width | Type | Description |
|---|---|---|---|---|
| `spi_shift_reg` | internal | 8 | data | Shared TX/RX shift register |
| `spi_clk_gen` | internal | 1 | control | Internally generated SCK, derived from `SPI_CLKDIV` |
| `bit_cnt` | internal | 3 | control | Tracks bits shifted (0–7) per transaction |
| `xfer_done_pulse` | internal | 1 | status | Asserted 1 cycle when 8 bits complete |
| `spi_sck` | boundary out | 1 | data | Serial clock |
| `spi_mosi` | boundary out | 1 | data | Master-out data |
| `spi_miso` | boundary in | 1 | data | Master-in data |
| `spi_cs_n` | boundary out | 1 | control | Active-low chip select |
| `spi_irq` | cross-IP out | 1 | status | Asserted per Section 8 conditions |

### 4.8 Seven-Segment Display Controller — Internal Signals

| Signal | Dir | Width | Type | Description |
|---|---|---|---|---|
| `digit_val[3:0]` | internal | 4×4 | data | BCD value per digit, sliced from `SEG_DATA` |
| `bcd2seg_out` | internal | 7 | data | Combinational BCD→7-segment decoder output |
| `mux_counter` | internal | 2 | control | Selects which of 4 digits is active this refresh cycle |
| `refresh_tick` | internal | 1 | control | Digit-switch rate, derived from `SEG_CTRL.REFDIV` |
| `seg[6:0]` | boundary out | 7 | data | Segment lines (a–g) |
| `dp` | boundary out | 1 | data | Decimal point |
| `an[3:0]` | boundary out | 4 | control | Active digit/anode select |

---

## 5. Register Description

**Convention:** `RW` = read-write, `RO` = read-only, `WO` = write-only, `W1C` = write-1-to-clear.
Every register is explicitly tagged **[CONTROL]** (configures behavior/mode) or **[DATA]** (carries the
payload being produced/consumed), so the boundary the notes ask for is unambiguous.

### 5.1 UART (base `0x2000_0000`)

| Offset | Name | Access | Reset | Tag | Bit Fields | Description |
|---|---|---|---|---|---|---|
| `0x00` | `UART_CTRL` | RW | `0x0000_0000` | **CONTROL** | `[0] EN`, `[1] TX_IRQ_EN`, `[2] RX_IRQ_EN` | Enable UART; enable TX-empty / RX-ready interrupts |
| `0x04` | `UART_BAUD_DIV` | RW | `0x0000_0001` | **CONTROL** | `[15:0] DIV` | Clock divider for baud-rate generator |
| `0x08` | `UART_STATUS` | RO | `0x0000_0002` | **DATA** (status) | `[0] TX_BUSY`, `[1] TX_EMPTY`, `[2] RX_VALID`, `[3] FRAME_ERR` | Live status; `TX_EMPTY` reset value = 1 (idle) |
| `0x0C` | `UART_TXDATA` | WO | `0x0000_0000` | **DATA** | `[7:0] DATA` | Byte to transmit; write triggers shift-out |
| `0x10` | `UART_RXDATA` | RO | `0x0000_0000` | **DATA** | `[7:0] DATA` | Last received byte; reading clears `RX_VALID` |
| `0x14` | `UART_IRQ_CLR` | WO | — | **CONTROL** | `[0] TX_CLR`, `[1] RX_CLR`, `[2] ERR_CLR` | Write-1-to-clear the corresponding pending bit |

### 5.2 Timer (base `0x2000_1000`)

| Offset | Name | Access | Reset | Tag | Bit Fields | Description |
|---|---|---|---|---|---|---|
| `0x00` | `TIMER_CTRL` | RW | `0x0000_0000` | **CONTROL** | `[0] EN`, `[1] AUTO_RELOAD`, `[2] IRQ_EN` | Start/stop; reload-on-zero; overflow interrupt enable |
| `0x04` | `TIMER_LOAD` | RW | `0x0000_0000` | **CONTROL** | `[31:0] LOAD` | Value loaded into counter on start / on reload |
| `0x08` | `TIMER_COUNT` | RO | `0x0000_0000` | **DATA** | `[31:0] COUNT` | Live down-counter value |
| `0x0C` | `TIMER_STATUS` | RO | `0x0000_0000` | **DATA** (status) | `[0] OVERFLOW` | Set when counter reaches zero |
| `0x10` | `TIMER_IRQ_CLR` | WO | — | **CONTROL** | `[0] OVF_CLR` | Write-1-to-clear overflow pending bit |

### 5.3 GPIO (base `0x2000_2000`)

| Offset | Name | Access | Reset | Tag | Bit Fields | Description |
|---|---|---|---|---|---|---|
| `0x00` | `GPIO_DIR` | RW | `0x0000_0000` | **CONTROL** | `[7:0] DIR` | 1 = output, 0 = input, per pin |
| `0x04` | `GPIO_OUT` | RW | `0x0000_0000` | **DATA** | `[7:0] OUT` | Output drive value (pins configured as output) |
| `0x08` | `GPIO_IN` | RO | `0x0000_0000` | **DATA** | `[7:0] IN` | Synchronized input pin value |
| `0x0C` | `GPIO_INTCFG` | RW | `0x0000_0000` | **CONTROL** | `[7:0] EDGE_SEL` (0=rising,1=falling per bit) | Per-pin interrupt edge configuration |
| `0x10` | `GPIO_INT_EN` | RW | `0x0000_0000` | **CONTROL** | `[7:0] EN` | Per-pin interrupt enable mask |
| `0x14` | `GPIO_INT_STAT` | RO | `0x0000_0000` | **DATA** (status) | `[7:0] PEND` | Per-pin pending flags |
| `0x18` | `GPIO_INT_CLR` | WO | — | **CONTROL** | `[7:0] CLR` | Write-1-to-clear per-pin pending bit |

### 5.4 PWM Generator (base `0x3000_0000`)

| Offset | Name | Access | Reset | Tag | Bit Fields | Description |
|---|---|---|---|---|---|---|
| `0x00` | `PWM_CTRL` | RW | `0x0000_0000` | **CONTROL** | `[0] EN`, `[1] IRQ_EN` | Enable PWM output; enable period-complete interrupt |
| `0x04` | `PWM_PERIOD` | RW | `0x0000_FFFF` | **CONTROL** | `[15:0] PERIOD` | Counter wrap value (defines waveform frequency) |
| `0x08` | `PWM_DUTY` | RW | `0x0000_0000` | **DATA** | `[15:0] DUTY` | Compare value (defines ON time / duty cycle) |
| `0x0C` | `PWM_STATUS` | RO | `0x0000_0000` | **DATA** (status) | `[0] PERIOD_PEND` | Set on period wrap |
| `0x10` | `PWM_IRQ_CLR` | WO | — | **CONTROL** | `[0] CLR` | Write-1-to-clear period-pending bit |

> Constraint: firmware must ensure `PWM_DUTY <= PWM_PERIOD`. Violating this is a defined non-fatal
> condition — see Section 9.

### 5.5 SPI Controller (base `0x3000_1000`)

| Offset | Name | Access | Reset | Tag | Bit Fields | Description |
|---|---|---|---|---|---|---|
| `0x00` | `SPI_CTRL` | RW | `0x0000_0000` | **CONTROL** | `[0] EN`, `[1] CPOL`, `[2] CPHA`, `[3] IRQ_EN` | Enable; clock polarity/phase mode; done-interrupt enable |
| `0x04` | `SPI_CLKDIV` | RW | `0x0000_0004` | **CONTROL** | `[7:0] DIV` | SCK frequency divider from system clock |
| `0x08` | `SPI_CS_CTRL` | RW | `0x0000_0001` | **CONTROL** | `[0] CS_N` | Manual chip-select control (software-driven) |
| `0x0C` | `SPI_TXDATA` | WO | `0x0000_0000` | **DATA** | `[7:0] DATA` | Byte to transmit; write starts an 8-bit transaction |
| `0x10` | `SPI_RXDATA` | RO | `0x0000_0000` | **DATA** | `[7:0] DATA` | Byte received during the last transaction |
| `0x14` | `SPI_STATUS` | RO | `0x0000_0001` | **DATA** (status) | `[0] DONE`, `[1] BUSY`, `[2] OVERRUN` | Transaction complete / in-progress / overrun flags |
| `0x18` | `SPI_IRQ_CLR` | WO | — | **CONTROL** | `[0] DONE_CLR`, `[1] OVR_CLR` | Write-1-to-clear pending bits |

### 5.6 Seven-Segment Display Controller (base `0x3000_2000`)

| Offset | Name | Access | Reset | Tag | Bit Fields | Description |
|---|---|---|---|---|---|---|
| `0x00` | `SEG_CTRL` | RW | `0x0000_0000` | **CONTROL** | `[0] EN`, `[15:4] REFDIV` | Enable display; digit-refresh rate divider |
| `0x04` | `SEG_DATA` | RW | `0x0000_0000` | **DATA** | `[15:0] VALUE` (4× 4-bit BCD digits) | Numeric value to display, one nibble per digit |
| `0x08` | `SEG_DP_CTRL` | RW | `0x0000_0000` | **CONTROL** | `[3:0] DP_EN` | Per-digit decimal-point enable |
| `0x0C` | `SEG_STATUS` | RO | `0x0000_0001` | **DATA** (status) | `[0] ACTIVE` | Display refresh running |

### 5.7 Control vs. Data Register Summary

| Peripheral | Control Registers | Data Registers |
|---|---|---|
| UART | `CTRL`, `BAUD_DIV`, `IRQ_CLR` | `STATUS`, `TXDATA`, `RXDATA` |
| Timer | `CTRL`, `LOAD`, `IRQ_CLR` | `COUNT`, `STATUS` |
| GPIO | `DIR`, `INTCFG`, `INT_EN`, `INT_CLR` | `OUT`, `IN`, `INT_STAT` |
| PWM | `CTRL`, `PERIOD`, `IRQ_CLR` | `DUTY`, `STATUS` |
| SPI | `CTRL`, `CLKDIV`, `CS_CTRL`, `IRQ_CLR` | `TXDATA`, `RXDATA`, `STATUS` |
| 7-SEG | `CTRL`, `DP_CTRL` | `DATA`, `STATUS` |

---

## 6. Control Paths

A **control path** is: firmware writes a configuration register → that write reconfigures the IP's
behavior/mode → the IP's data path is enabled/gated by that configuration. Every control path below
must be fully configured **before** the corresponding data path (Section 7) is exercised.

| # | Path | Pre-required registers | Start/trigger | End condition |
|---|---|---|---|---|
| C1 | UART enable | `UART_BAUD_DIV` set, then `UART_CTRL.EN=1` | Write `UART_CTRL` | UART accepts TX/RX activity |
| C2 | Timer start | `TIMER_LOAD` set | Write `TIMER_CTRL.EN=1` | Counter begins decrementing |
| C3 | GPIO direction/interrupt config | `GPIO_DIR`, `GPIO_INTCFG`, `GPIO_INT_EN` | Any write to these regs (no explicit enable bit — direction takes effect immediately) | Pin behaves per new config next cycle |
| C4 | PWM enable | `PWM_PERIOD` set, `PWM_DUTY` set (`DUTY <= PERIOD`) | Write `PWM_CTRL.EN=1` | `pwm_counter` free-runs, `pwm_out` reflects duty |
| C5 | SPI enable | `SPI_CLKDIV`, `SPI_CTRL.CPOL/CPHA` set | Write `SPI_CTRL.EN=1` | SPI ready to accept `SPI_TXDATA` writes |
| C6 | 7-Seg enable | `SEG_CTRL.REFDIV` set | Write `SEG_CTRL.EN=1` | Multiplexed refresh begins |

**Rule:** if any data-path register (Section 7) is written while its owning IP's `EN` bit is 0, the
write is accepted (stored) but has **no observable effect** until `EN=1` — this is intentional, not an
error condition.

---

## 7. Data Paths

A **data path** is the route a payload value takes from a register write through to a physical output
(or from a physical input through to a readable register).

### 7.1 PWM Data Path
`PWM_DUTY` (register) → 16-bit comparator (`pwm_counter < PWM_DUTY`) → `duty_cmp` → `pwm_out` pin.
`pwm_counter` free-runs 0→`PWM_PERIOD`→wraps, driven only by `clk` once `PWM_CTRL.EN=1`.

### 7.2 SPI Data Path
**TX:** `SPI_TXDATA` write → loaded into `spi_shift_reg` → shifted out MSB-first on `spi_mosi`,
synchronized to `spi_clk_gen` (derived from `SPI_CLKDIV`) → `spi_cs_n` held low for the duration
(auto, driven by internal FSM while a transaction is active).
**RX:** `spi_miso` → sampled into `spi_shift_reg` on the opposite clock edge (per `CPHA`) → after 8
bits, latched into `SPI_RXDATA`, `SPI_STATUS.DONE` set.

### 7.3 Seven-Segment Data Path
`SEG_DATA` write → 4× 4-bit BCD nibbles → per-digit combinational `bcd2seg_out` (BCD→7-segment
decode table, values 0–9 only; 10–15 map to blank, see Section 9) → time-multiplexed onto shared
`seg[6:0]`/`dp` lines, with `an[3:0]` cycling one-hot at the `refresh_tick` rate (derived from
`SEG_CTRL.REFDIV`) so only one digit is illuminated at a time, fast enough to appear steady (target
≥ 100 Hz full-frame refresh).

### 7.4 UART Data Path
**TX:** `UART_TXDATA` write → `tx_shift_reg` (8N1 framing: start bit, 8 data bits, stop bit) → serial
bit stream on `uart_tx`, timed by `baud_tick` (from `UART_BAUD_DIV`).
**RX:** `uart_rx` → sampled at mid-bit per `baud_tick` → `rx_shift_reg` → on stop-bit sample, latched
into `UART_RXDATA`, `UART_STATUS.RX_VALID` set. If the stop bit does not sample high, `FRAME_ERR` is
set instead (Section 9).

### 7.5 GPIO Data Path
**Output:** `GPIO_OUT` write (only affects bits where `GPIO_DIR=1`) → driven directly onto `gpio[7:0]`.
**Input:** `gpio[7:0]` → 2-flop synchronizer → `GPIO_IN` (only meaningful where `GPIO_DIR=0`).

### 7.6 Timer Data Path
`TIMER_LOAD` → loaded into `count_reg` on start or on reload → `count_reg` decrements every `clk`
while `TIMER_CTRL.EN=1` → readable live via `TIMER_COUNT` → on reaching 0, `TIMER_STATUS.OVERFLOW` set
and, if `AUTO_RELOAD=1`, `count_reg` reloads from `TIMER_LOAD` and continues.

---

## 8. Interrupts

**Principle:** every interrupt in the system is a subset of one global interrupt line into the RISC-V
core's external interrupt input. Cause discrimination happens in software by polling each IP's
`STATUS`/`INT_STAT` register after taking the trap — there is no separate vectored interrupt
controller in v1.0 of this design (documented explicitly so the AI agent does not assume one exists).

### 8.1 All Possible Interrupt Sources

| Source | Register that reveals cause | Set condition | Enable bit |
|---|---|---|---|
| UART TX empty | `UART_STATUS.TX_EMPTY` | Shift register finished transmitting | `UART_CTRL.TX_IRQ_EN` |
| UART RX ready | `UART_STATUS.RX_VALID` | New byte fully received | `UART_CTRL.RX_IRQ_EN` |
| UART frame error | `UART_STATUS.FRAME_ERR` | Stop bit not sampled high | (always signals if RX_IRQ_EN=1) |
| Timer overflow | `TIMER_STATUS.OVERFLOW` | `count_reg` reaches 0 | `TIMER_CTRL.IRQ_EN` |
| GPIO edge | `GPIO_INT_STAT[7:0]` | Configured edge detected on enabled pin | `GPIO_INT_EN[n]` |
| PWM period complete | `PWM_STATUS.PERIOD_PEND` | `pwm_counter` wraps | `PWM_CTRL.IRQ_EN` |
| SPI transaction done | `SPI_STATUS.DONE` | 8 bits shifted | `SPI_CTRL.IRQ_EN` |
| SPI overrun | `SPI_STATUS.OVERRUN` | New TX write while `BUSY=1` | (always signals if IRQ_EN=1) |

### 8.2 Recovery Path for Interrupts (mandatory ISR sequence)

1. Trap taken on the RISC-V core's external interrupt input.
2. ISR polls each IP's status register, in priority order: **UART → Timer → GPIO → PWM → SPI**
   (fixed priority; first pending source found is serviced this pass).
3. ISR performs the data-path action required (e.g., read `UART_RXDATA`, read `SPI_RXDATA`).
4. ISR writes the matching `*_IRQ_CLR` (or `GPIO_INT_CLR`) bit — **write-1-to-clear only**; the
   pending bit is not auto-cleared by reading data registers except where explicitly noted
   (`UART_RXDATA` read does clear `RX_VALID`, per 5.1).
5. ISR returns; if another source is still pending, the interrupt line remains asserted and the core
   re-traps immediately.

This recovery path is the **only defined interrupt recovery mechanism** — no other clearing sequence is
valid, and any interrupt left pending with its enable bit still set will keep re-asserting.

---

## 9. Error Cases

Per the project's error-handling rule: **only the conditions explicitly listed below are non-fatal**;
anything else (any undefined/unspecified error condition) is treated as **fatal**, and the *only*
defined recovery from a fatal error is a full system reset / power cycle (`rst_n` assertion). This is
intentional and matches the instruction to keep the fatal-error recovery path minimal.

### 9.1 Non-Fatal Errors (defined, with defined recovery)

| # | Error | Where detected | Indicated by | Recovery path |
|---|---|---|---|---|
| E1 | UART framing error | UART RX path | `UART_STATUS.FRAME_ERR` | Software clears via `UART_IRQ_CLR.ERR_CLR`, discards the byte, resumes listening |
| E2 | SPI overrun (TX write while busy) | SPI control path | `SPI_STATUS.OVERRUN` | Software clears via `SPI_IRQ_CLR.OVR_CLR`, waits for `BUSY=0`, retries the write |
| E3 | PWM `DUTY > PERIOD` misconfiguration | PWM control path (comparator never trips) | No dedicated flag — `pwm_out` simply stays high 100% of the time; treated as a firmware logic error, not a hardware fault | Software rewrites `PWM_DUTY` to a valid value; no reset required |
| E4 | Write to a read-only register offset | Bus interconnect / register decode | `p_err` asserted for that single transfer; write has no effect | Software should not retry the same write; treat as a firmware bug to fix, not a runtime condition to recover from at runtime |
| E5 | 7-Segment BCD nibble out of range (10–15) | 7-Seg decoder | No status flag — decoder maps 10–15 to a defined blank pattern (all segments off) | Software rewrites `SEG_DATA` with a valid 0–9 nibble |

### 9.2 Fatal Errors (undefined/unspecified — reset-only recovery)

| # | Condition | Behavior |
|---|---|---|
| F1 | Access to any address in the Reserved region (`0x4000_0000` and above) | `p_err` asserted; bus transaction aborted; system state beyond this point is **not guaranteed** |
| F2 | Any bus protocol violation not covered by the SPB timing in Section 4.2 (e.g. `p_sel` asserted for two slaves simultaneously — should never happen from a correctly generated decoder, but is undefined if it does) | Undefined; recovery is `rst_n` assertion only |
| F3 | Any register bit-field value outside the ranges explicitly documented in Section 5, other than the specifically-forgiven cases in 9.1 (E3, E5) | Undefined; recovery is `rst_n` assertion only |

> **Agent instruction:** do not invent additional non-fatal error handling beyond E1–E5. If RTL
> synthesis or simulation surfaces a new error condition not listed here, stop and flag it for the
> spec to be updated — do not silently add a new recovery path.

---

## 10. Application (brief — full detail in Section 11)

The application initializes all peripherals, drives a PWM waveform, performs an SPI transaction,
displays a live system value on the seven-segment display, and reports status over UART.

---

## 11. Application — Full Detail

### 11.1 Application Goal

Demonstrate all three additional IPs operating concurrently under processor control, with UART used
purely for observability (debug/status reporting to an external terminal), matching the abstract's
scope exactly.

### 11.2 Initialization Sequence (on reset / boot)

```
1.  Wait for rst_n de-assertion.
2.  Configure UART:      UART_BAUD_DIV = <value for target baud>, UART_CTRL.EN = 1
3.  Configure Timer:     TIMER_LOAD = <1ms-equivalent tick count>, TIMER_CTRL = {AUTO_RELOAD=1, IRQ_EN=1, EN=1}
4.  Configure GPIO:      GPIO_DIR = 0x00 (all inputs) or per board wiring
5.  Configure PWM:       PWM_PERIOD = 0xFFFF, PWM_DUTY = 0x0000, PWM_CTRL = {IRQ_EN=0, EN=1}
6.  Configure SPI:       SPI_CLKDIV = <value>, SPI_CTRL = {CPOL=0, CPHA=0, EN=1}, SPI_CS_CTRL.CS_N = 1 (idle high)
7.  Configure 7-Seg:     SEG_CTRL.REFDIV = <value for ~100Hz+ refresh>, SEG_CTRL.EN = 1
8.  Enable global interrupt on the RISC-V core.
9.  Print "SoC INIT OK" over UART.
```

### 11.3 Main Application Loop

```
loop forever:
    a. On each Timer overflow interrupt (~ every N ms):
         i.   Increment a software "brightness" variable (0..PWM_PERIOD, wrapping)
         ii.  Write new value to PWM_DUTY               -> drives LED brightness ramp
         iii. Increment a software "display value" variable (0..9999, wrapping)
         iv.  Write new value to SEG_DATA                -> updates 7-seg display
         v.   Clear TIMER overflow pending bit

    b. Every M-th Timer tick (slower cadence):
         i.   Write a test byte to SPI_TXDATA             -> starts SPI transaction
         ii.  Poll (or wait for interrupt) SPI_STATUS.DONE
         iii. Read SPI_RXDATA                             -> received byte available to app
         iv.  Format a status string with: current PWM duty, current display value,
              and the SPI byte just exchanged
         v.   Write that string, byte-by-byte, to UART_TXDATA (waiting for TX_EMPTY between bytes)

    c. Any GPIO edge interrupt (e.g. a push-button):
         i.   Read GPIO_IN
         ii.  Toggle a mode flag (e.g. pause/resume the PWM ramp)
         iii. Clear the GPIO interrupt pending bit
```

### 11.4 Expected Observable Behavior on FPGA

- LED connected to `pwm_out` visibly ramps brightness up and down.
- Seven-segment display shows a live incrementing counter value.
- UART terminal (e.g. via USB-UART bridge, 115200-8N1 or configured baud) prints periodic status
  lines showing PWM duty, display value, and the SPI loopback/byte result.
- SPI lines (`spi_sck`, `spi_mosi`, `spi_miso`, `spi_cs_n`) show a clean 8-bit transaction each time
  the app triggers one — observable on a logic analyzer or scope during bring-up.

---

## 12. Verification Plan

| Test ID | Target | Description | Maps to spec section |
|---|---|---|---|
| TC-BUS-01 | Bus interconnect | Address decode routes to correct slave for every defined base address | Section 3 |
| TC-BUS-02 | Bus interconnect | Access to reserved region asserts `p_err` | Section 9 (F1) |
| TC-UART-01 | UART | TX byte observed correctly framed (8N1) on `uart_tx` at configured baud | 7.4 |
| TC-UART-02 | UART | RX byte with corrupted stop bit sets `FRAME_ERR`, recovers after clear | 9.1 (E1) |
| TC-TIMER-01 | Timer | Counter reaches zero at expected cycle count, sets overflow, auto-reloads | 7.6, 8.1 |
| TC-GPIO-01 | GPIO | Direction register correctly gates input vs output per-bit | 7.5 |
| TC-GPIO-02 | GPIO | Configured edge on enabled pin sets correct pending bit | 8.1 |
| TC-PWM-01 | PWM | Duty cycle sweep 0→PERIOD produces correct ON-time ratio on `pwm_out` | 7.1 |
| TC-PWM-02 | PWM | `DUTY > PERIOD` leaves `pwm_out` high continuously (no crash) | 9.1 (E3) |
| TC-SPI-01 | SPI | 8-bit TX/RX transaction with CPOL/CPHA = 00 matches expected waveform | 7.2 |
| TC-SPI-02 | SPI | Overrun condition (write while busy) sets `OVERRUN`, recovers after clear | 9.1 (E2) |
| TC-SEG-01 | 7-Seg | All four digits show correct BCD→segment mapping, multiplexed correctly | 7.3 |
| TC-SEG-02 | 7-Seg | Nibble value 10–15 renders blank, no illegal segment pattern | 9.1 (E5) |
| TC-IRQ-01 | Interrupt system | Each of the 8 interrupt sources independently asserts and is clearable | Section 8 |
| TC-APP-01 | Full application | End-to-end: init → PWM ramp + SPI txn + display update + UART report, on FPGA | Section 11 |

Simulation environment: directed testbenches per IP (in `tb/`) plus one full-system testbench that
boots the application binary and checks bus transactions/waveforms against the above table.
FPGA bring-up follows the same TC-* IDs as a hardware bring-up checklist.

---

## 13. Repository / Directory Structure

This repository follows the fixed top-level layout below. **Do not rename these directories** — file
generation by the AI agent should always target the correct one.

```
proj-dir/
├── README.md              # Project overview, quick start, how to build/run
├── doc/                    # This ARCHITECTURE.md + any register/interrupt reference docs
├── scripts/                # Build, lint, simulation-run, and FPGA flash automation scripts
├── rtl/                    # Design (RTL) source files — one subfolder per IP recommended
│   ├── core/                 (top-level SoC integration / bus interconnect)
│   ├── uart/
│   ├── timer/
│   ├── gpio/
│   ├── pwm/
│   ├── spi/
│   └── seg7/
├── tb/                      # Testbenches — mirror rtl/ subfolder names 1:1
├── lib/                     # Reusable library components (e.g. sync FIFO, 2-flop synchronizer,
│                              generic BCD-to-7-seg decoder) shared across multiple IPs
├── reg/                     # Register definition source-of-truth (e.g. a machine-readable
│                              register spec such as .json/.yaml per Section 5, used to
│                              auto-generate register RTL and C header files)
└── run/                     # Simulation/synthesis run directories & generated outputs
                               (kept out of version control except a .gitkeep — see .gitignore)
```

Each `rtl/<ip>/` folder should contain that IP's synthesizable Verilog/SystemVerilog only. Each
corresponding `tb/<ip>/` folder contains that IP's standalone testbench, following the test IDs in
Section 12. `reg/` should hold one register-definition file per peripheral (e.g.
`reg/uart_regs.yaml`, `reg/pwm_regs.yaml`, ...) that mirrors Section 5 exactly, so a register-generator
script in `scripts/` can produce both the RTL register bank and the C header used by firmware — keeping
Section 5 as the single source of truth instead of duplicating field definitions by hand in multiple
places.
