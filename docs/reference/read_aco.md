# Read ACO (Airspace Colour) File

This function parses SAAM `.aco` files. These files link specific
airblocks (often defined by Sector:Airblock composite names) to visual
properties like RGB color, transparency, and display flags.

The file structure is defined as follows:

- **Extension**: aco

- **Origin**: SAAM

- **Separator**: Whitespace

**Record Structure**:

- Field 1: **Version** (Format version, usually 1).

- Field 2: **Airblock Name** (Format: `Sector:Airblock` or just
  `Airblock`).

- Field 3: **Flight Level Bottom** (Padded with 0, e.g., 085).

- Field 4: **Flight Level Top** (Padded with 0).

- Field 5: **Nb Colours** (Number of color definitions following).

- Field 6: **Colour Version**.

- Field 7: **Colour Name** ("?" is default).

- Field 8: **Feature Code** (Bitmask for display flags, see details).

- Field 9: **Colour Flag** (1=Defined here, 0=Inherited).

- Field 10: **Type** (Usually "C").

- Field 11: **Transparency** (0-255).

- Field 12: **Red** (0-255).

- Field 13: **Green** (0-255).

- Field 14: **Blue** (0-255).

## Usage

``` r
read_aco(aco_file)
```

## Arguments

- aco_file:

  Path to the .aco file.

## Value

A `data.table` with the following columns:

- `airblock_name`: Character (The raw ID from the file).

- `fl_bottom`: Integer.

- `fl_top`: Integer.

- `feature_code`: Integer (Bitmask).

- `transparency`: Integer.

- `red`: Integer.

- `green`: Integer.

- `blue`: Integer.

- `hex`: Character (Derived hex color string for convenience, e.g.,
  "#RRGGBB").

## Details

Reads a .aco file defining display attributes (colors, transparency,
flags) for 3D airblocks.
