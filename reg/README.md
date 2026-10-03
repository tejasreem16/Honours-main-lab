# reg/

Machine-readable register definitions — the source of truth for `doc/ARCHITECTURE.md` Section 5.
One YAML file per peripheral. A register-generator script (see `scripts/gen_regs.py`) should consume
these to produce both the RTL register bank and the firmware C header, so field definitions are never
hand-duplicated in more than one place.

Format per file: base address, then a list of registers with offset, name, access type
(RW/RO/WO/W1C), reset value, control-vs-data tag, and bit fields.
