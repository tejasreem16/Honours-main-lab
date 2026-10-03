# scripts/

Automation scripts. Suggested set (create as the project progresses):

| Script | Purpose |
|---|---|
| `run_sim.sh <ip_name|all>` | Runs one IP's testbench or the full regression, per doc/ARCHITECTURE.md Section 12 |
| `gen_regs.py` | Reads `reg/*.yaml` and generates (a) RTL register-bank modules into `rtl/<ip>/`, and (b) a C header for firmware, keeping Section 5 as the single source of truth |
| `build_fpga.sh` | Runs synthesis + place-and-route + bitstream generation for the target FPGA |
| `lint.sh` | Runs a lint pass (e.g. Verilator `--lint-only` or similar) across all of `rtl/` |
