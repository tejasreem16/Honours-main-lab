# lib/

Reusable RTL components shared across more than one IP, e.g.:

- 2-flop input synchronizer (used by GPIO input path and any async input)
- Generic parameterized shift register (used by UART and SPI)
- BCD-to-7-segment decoder table (used by the Seven-Segment Display Controller)
- Simple clock-divider / tick generator (used by UART baud generation, PWM, SPI, Timer)

Keep these generic and parameterized — do not hardcode any single IP's register offsets or bit
widths in here.
