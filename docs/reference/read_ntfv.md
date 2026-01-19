# Read NTFV (Traffic Volume) File

This function parses SAAM/Gasel `.ntfv` files. These files define
"Traffic Volumes" (TVs), which are groupings of flights (flows) passing
through specific points or airspaces.

The file structure is hierarchical:

- **Extension**: ntfv

- **Separator**: Semicolon (;)

The file consists of:

1.  **First Line**: Metadata starting with \#.

2.  **Traffic Volume Headers (T)**: Define the volume properties. The
    number of fields varies by location type.

3.  **Flow Element Lines (F)**: Define the specific flows
    included/excluded in that volume.

**Header Types**:

- **Type 1 (AD/AZ)**: 8 Fields. (No FL or Skip info).

- **Type 2 (AS/SP/DBP)**: 10 Fields. Includes Min/Max FL or Skip In/Out
  times.

**Common Fields (T)**:

- ID, Name, Category (MO/\_), Ref Location Name, Ref Location Type (AD,
  AZ, AS, SP, DBP), Role (D, A, G), Nb Elements.

**Variable Fields (T)**:

- For AS/SP/DBP: Field 8 (Min FL / Skip In), Field 9 (Max FL / Skip
  Out).

**Flow Lines (F)**:

- Field 2: Flow Element ID

- Field 3: Flow Type (IN, IE, EX, EM)

## Usage

``` r
read_ntfv(ntfv_file)
```

## Arguments

- ntfv_file:

  Path to the .ntfv file.

## Value

A `data.table` with the following columns:

- `tv_id`: Traffic Volume ID.

- `tv_name`: Traffic Volume Name/Description.

- `tv_category`: Category (e.g., MO).

- `ref_loc_name`: Reference Location Name.

- `ref_loc_type`: Reference Location Type (AD, AZ, AS, SP, DBP).

- `ref_loc_role`: Reference Role (D, A, G).

- `min_fl_or_skip_in`: Min Flight Level or Skip In time (Numeric).

- `max_fl_or_skip_out`: Max Flight Level or Skip Out time (Numeric).

- `flow_id`: The ID of the flow element (Child).

- `flow_type`: The type of the flow element (IN, EX, etc.).

## Details

Reads a .ntfv file defining traffic volumes and their flow elements.
