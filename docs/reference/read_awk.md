# Read AWK (RAD Rule) File

This function parses SAAM `.awk` files. It handles the hierarchical
structure, nested logic blocks, and extracts Routing constraints.

**Structure**:

- Sections (`#SECTION`)

- Rule Headers (`#RAD`)

- Logic Lines (`if ... REGLE=REGLE ...`)

## Usage

``` r
read_awk(awk_file, parse_rules = FALSE)
```

## Arguments

- awk_file:

  Path to the .awk file.

- parse_rules:

  Logical. If `TRUE`, extracts structured columns: `condition_dep`,
  `condition_arr`, `condition_rfl_min`, `condition_rfl_max`,
  `routing_constraint`.

## Value

A `data.table`. If `parse_rules = TRUE`, columns include:

- `condition_dep/arr/...`: Regex patterns.

- `exclude_dep/arr/...`: Logical flags for negation.

- `condition_rfl_min/max`: Integer limits for Requested Flight Level.

- `routing_constraint`: The routing string (e.g., " - BUGOR DERAD").

## Details

Reads a .awk file defining RAD Routing Rules.
