# Read TAX (Penalisation/Turn) File

This function parses SAAM/Gasel `.tax` files (often referred to as
"penalisation" files). These files define specific turn sequences (Point
1 -\> Point 2 -\> Point 3) that carry a penalty or restriction.

The structure defines a specific geometric turn:

- **Incoming Leg**: Point 1 to Point 2.

- **Turn Point**: Point 2.

- **Outgoing Leg**: Point 2 to Point 3.

The file structure is defined as follows:

- **Extension**: tax

- **Origin**: Produced manually

- **Separator**: Whitespace (Space or Tab)

- **Sort**: No specific sort order

**Record Structure**:

- Field 1: **Point 1** (Previous point)

- Field 2: **Point 2** (The vertex/turn point)

- Field 3: **Point 3** (Next point)

## Usage

``` r
read_tax(tax_file)
```

## Arguments

- tax_file:

  Path to the .tax file.

## Value

A `data.table` with the following columns:

- `point_1`: The start of the incoming segment.

- `point_2`: The turning point.

- `point_3`: The end of the outgoing segment.

## Details

Reads a .tax file defining turning penalties or forbidden turns between
navigation points.
