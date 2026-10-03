# rtl/

Synthesizable design (RTL) source files only — no testbenches here (those live in `tb/`, mirroring
these folder names 1:1).

| Subfolder | Contents |
|---|---|
| `core/` | Top-level SoC integration: RISC-V core instantiation, IMEM/DMEM, bus interconnect / address decoder, interrupt aggregation |
| `uart/` | UART Controller |
| `timer/` | Timer |
| `gpio/` | GPIO |
| `pwm/` | PWM Generator |
| `spi/` | SPI Controller |
| `seg7/` | Seven-Segment Display Controller |

Register field definitions for each block come from `reg/<block>_regs.yaml` — do not hand-duplicate
bit-field constants inside RTL; generate them or reference `doc/ARCHITECTURE.md` Section 5 directly.

See `doc/ARCHITECTURE.md` Section 2 (block diagram) and Section 4 (signal list) before writing any
module here — every port name should match the signal list exactly.
