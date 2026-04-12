---
name: comment-generator
description: Generate a top-of-file header comment for a SystemVerilog file. Use when asked to add, write, or generate a file header/comment block. Analyzes the file and produces the standard EE470 format.
model: claude-sonnet-4-6
---

# comment-generator

Analyze the provided SystemVerilog file and write a header comment block in the EE470 standard format.

## Format (strict)

```
// Name: <CurrentUser>, <Either 'Bernardo Lin' or 'Leonard Paya', should be whatever the current user isn't>
// Date: <today's date as YYYY-MM-DD>
// <One sentence: what the module does and its role in the design. Concise, no fluff.>
// Parameters:
//     - <PARAM_NAME>: <what it controls>
// Inputs:
//     - <port_name>: <what it carries / its role>
// Outputs:
//     - <port_name>: <what it carries / its role>
```

- Omit **Parameters** section if the module has none.
- Omit **Inputs** or **Outputs** section if the module has none.
- One sentence only for the description — sacrifice grammar for concision.
- Do not add any section not listed above.

## Workflow

1. Read the file in full before writing anything.
2. Scan every line (code and comments) for misspelled English words. Identifiers that are concatenations of valid words (e.g. `loadWeight`) are not misspellings — only flag words that are clearly wrong (e.g. `Multply`, `Arithemetic`, `Reformating`). Do **not** flag SystemVerilog keywords, module/signal names used consistently as identifiers, or numeric literals.
3. Fix each misspelling in-place (same line, same position). Do not change any logic, formatting, or whitespace beyond the corrected characters.
4. Identify: module name, parameters, input ports, output ports.
5. Infer the module's role from its logic (not just its name).
6. Write the header block exactly matching the format above. Do **not** add inline comments anywhere in the header.
7. Insert the block at the top of the file, before the `module` declaration.
8. Output a misspelling report to the user in this format (omit if none found):

| Line | Old | New |
|------|-----|-----|
| 11 | Multply | Multiply |

## Port description rules

- State the signal's **role**, not just its type (e.g., "Accumulator output, widened to prevent overflow" not "Output signal").
- Include bit-width parameter references where relevant (e.g., "BIT_WIDTH_INPUT bits").
- For clocks: "System clock". For resets: "Active-high/low sync/async reset".
- No inline comments in the header block — descriptions go in the port line only.
