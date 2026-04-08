---
paths:
  - "**/*.sv"
  - "**/*.svh"
---

# SystemVerilog lint rules

Authoritative config: [.verible-lint-rules](../../.verible-lint-rules).

- Spaces only, **no tabs**
- 100-column line length max
- No trailing whitespace
- POSIX EOF newline (final line ends with `\n`)
- `always_ff` / `always_comb` / `always_latch` only — never bare `always @(...)` for new code
- Synchronous reset unless project standard says otherwise
