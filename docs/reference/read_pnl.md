# Read PNL (Penalisation/Segment) File

This function parses SAAM/Gasel `.pnl` files. Unlike `.tax` files (which
define turn penalties), `.pnl` files define a penalty (in Nautical
Miles) for traversing a specific straight-line segment between two
points.

The file structure is defined as follows:

- **Extension**: pnl

- **Separator**: One or more spaces (Whitespace)

- **Comments**: Lines starting with `//` are ignored.

**Record Structure**:

- Field 1: **Point 1** (Start of segment)

- Field 2: **Point 2** (End of segment)

- Field 3: **Penalisation** (Cost in NM)

## Usage

``` r
read_pnl(pnl_file)
```

## Arguments

- pnl_file:

  Path to the .pnl file.

## Value

A `data.table` with the following columns:

- `start_point`: The identifier of the starting point.

- `end_point`: The identifier of the ending point.

- `penalty`: Numeric. The added cost (in NM) for using this segment.

## Details

Reads a .pnl file defining penalizations (costs) for specific network
segments.
