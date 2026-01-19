# Read FLC2 (Rule/Constraint) File

This function parses SAAM `.flc2` files. It handles:

- Hierarchical Sections and Rule headers.

- **Nested Logic Blocks**: Handles `if(...) { ... }` structures by
  flattening the logic.

- **Syntax Variations**: Supports both Regex (`~ /.../`) and String
  Equality (`== "..."`).

## Usage

``` r
read_flc2(flc2_file, parse_rules = FALSE)
```

## Arguments

- flc2_file:

  Path to the .flc2 file.

- parse_rules:

  Logical. If `TRUE`, extracts structured columns.

## Value

A `data.table`. If `parse_rules = TRUE`, the following columns are
added:

- `condition_dep`, `condition_arr`, `condition_point`, `condition_via`,
  `condition_climb_rate`: Regex patterns or exact strings.

- `exclude_dep`, `exclude_arr`, etc.: Logical flags (TRUE if the
  condition is negated with '!').

- `constraint_type`: "ROUTING" (for REGLE), "MAX", "MIN", or "EQUAL"
  (for FL_CONT).

- `constraint_value`: The routing string (if type is ROUTING) or the
  Flight Level (as integer).

## Details

Reads a .flc2 (or .awk) file defining RAD Rules.
