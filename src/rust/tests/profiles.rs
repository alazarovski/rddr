use std::path::PathBuf;
use std::sync::Arc;

use airspaceprofile::{
    init_airspaces, intersect_trajectories, parse_time, read_trajectories, validate_trajectories,
    AirspaceBlock, PreparedAirspaces, TrajPoint,
};

fn fixture(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../inst/extdata")
        .join(name)
}

fn point(lon: f64, lat: f64, altitude: f64, time: f64) -> TrajPoint {
    TrajPoint {
        id: "F".into(),
        lon,
        lat,
        altitude,
        time,
    }
}

fn model() -> PreparedAirspaces {
    init_airspaces(
        &fixture("example.are"),
        &fixture("example.sls"),
        &fixture("example.spc"),
        "NAS",
        Some(&["LEFT".into()]),
    )
    .unwrap()
}

fn near(actual: f64, expected: f64) {
    assert!((actual - expected).abs() < 1e-8, "{actual} != {expected}");
}

#[test]
fn known_entry_exit_and_no_intersection() {
    let airspaces = model();
    let rows = intersect_trajectories(
        &airspaces,
        &[
            point(-1.0, 1.0, 15000.0, 0.0),
            point(3.0, 1.0, 15000.0, 40.0),
        ],
    )
    .unwrap();
    assert_eq!(rows.len(), 1);
    near(rows[0].entry_lon, 0.0);
    near(rows[0].exit_lon, 2.0);
    near(rows[0].entry_time, 10.0);
    near(rows[0].exit_time, 30.0);
    assert!(!rows[0].starts_inside && !rows[0].ends_inside);
    assert!(intersect_trajectories(
        &airspaces,
        &[
            point(-1.0, 3.0, 15000.0, 0.0),
            point(3.0, 3.0, 15000.0, 40.0)
        ]
    )
    .unwrap()
    .is_empty());
}

#[test]
fn repeated_visits_do_not_span_outside_gaps() {
    let rows = intersect_trajectories(
        &model(),
        &[
            point(-1.0, 1.0, 15000.0, 0.0),
            point(3.0, 1.0, 15000.0, 40.0),
            point(-1.0, 1.0, 15000.0, 80.0),
        ],
    )
    .unwrap();
    assert_eq!(rows.len(), 2);
    near(rows[0].exit_time, 30.0);
    near(rows[1].entry_time, 50.0);
    assert_eq!(rows[1].visit_id, 2);
}

#[test]
fn overlapping_and_adjacent_blocks_merge_but_disconnected_blocks_do_not() {
    let airspaces = init_airspaces(
        &fixture("example.are"),
        &fixture("example.sls"),
        &fixture("example.spc"),
        "AUAG",
        None,
    )
    .unwrap();
    assert_eq!(airspaces.block_count(), 4);
    let flights = read_trajectories(&[fixture("flights.csv")]).unwrap();
    let rows = intersect_trajectories(&airspaces, &flights).unwrap();
    assert_eq!(rows.len(), 2);
    near(rows[0].entry_lon, 0.0);
    near(rows[0].exit_lon, 4.0);
    near(rows[1].entry_lon, 6.0);
    near(rows[1].exit_lon, 8.0);
    near(rows[1].exit_time - rows[0].entry_time, 80.0);
}

#[test]
fn vertical_climb_and_descent_interpolate_time_and_altitude() {
    for (a, b) in [(0.0, 30000.0), (30000.0, 0.0)] {
        let rows = intersect_trajectories(
            &model(),
            &[point(1.0, 1.0, a, 0.0), point(1.0, 1.0, b, 90.0)],
        )
        .unwrap();
        assert_eq!(rows.len(), 1);
        near(rows[0].entry_time, 30.0);
        near(rows[0].exit_time, 60.0);
        near(
            rows[0].entry_altitude_ft,
            if a == 0.0 { 10000.0 } else { 20000.0 },
        );
        near(
            rows[0].exit_altitude_ft,
            if a == 0.0 { 20000.0 } else { 10000.0 },
        );
    }
}

#[test]
fn start_end_inside_and_stationary_recording() {
    let rows = intersect_trajectories(
        &model(),
        &[
            point(1.0, 1.0, 15000.0, 0.0),
            point(1.0, 1.0, 15000.0, 10.0),
        ],
    )
    .unwrap();
    assert!(rows[0].starts_inside && rows[0].ends_inside);
    near(rows[0].exit_time, 10.0);
}

#[test]
fn boundary_travel_is_included_but_isolated_vertex_touch_is_not() {
    let rows = intersect_trajectories(
        &model(),
        &[
            point(-1.0, 0.0, 15000.0, 0.0),
            point(3.0, 0.0, 15000.0, 40.0),
        ],
    )
    .unwrap();
    assert_eq!(rows.len(), 1);
    near(rows[0].entry_time, 10.0);
    near(rows[0].exit_time, 30.0);
    assert!(intersect_trajectories(
        &model(),
        &[
            point(-1.0, 1.0, 15000.0, 0.0),
            point(1.0, -1.0, 15000.0, 20.0)
        ]
    )
    .unwrap()
    .is_empty());
}

#[test]
fn diagonal_shared_vertices_are_not_double_counted() {
    let rows = intersect_trajectories(
        &model(),
        &[
            point(-1.0, -1.0, 15000.0, 0.0),
            point(3.0, 3.0, 15000.0, 40.0),
        ],
    )
    .unwrap();
    assert_eq!(rows.len(), 1);
    near(rows[0].entry_time, 10.0);
    near(rows[0].exit_time, 30.0);
}

#[test]
fn nonconvex_polygon_preserves_multiple_intervals_on_one_segment() {
    let airspaces = PreparedAirspaces::new(vec![AirspaceBlock {
        airspace_id: "U".into(),
        min_altitude: 0.0,
        max_altitude: 20000.0,
        coords: Arc::new(vec![
            [0.0, 0.0],
            [3.0, 0.0],
            [3.0, 3.0],
            [2.0, 3.0],
            [2.0, 1.0],
            [1.0, 1.0],
            [1.0, 3.0],
            [0.0, 3.0],
        ]),
    }])
    .unwrap();
    let rows = intersect_trajectories(
        &airspaces,
        &[
            point(-1.0, 2.0, 10000.0, 0.0),
            point(4.0, 2.0, 10000.0, 50.0),
        ],
    )
    .unwrap();
    assert_eq!(rows.len(), 2);
    near(rows[0].entry_time, 10.0);
    near(rows[0].exit_time, 20.0);
    near(rows[1].entry_time, 30.0);
    near(rows[1].exit_time, 40.0);
}

#[test]
fn unsorted_interleaved_flights_match_sorted_results() {
    let mut second_a = point(-1.0, 1.0, 15000.0, 0.0);
    let mut second_b = point(3.0, 1.0, 15000.0, 40.0);
    second_a.id = "SECOND".into();
    second_b.id = "SECOND".into();
    let rows = intersect_trajectories(
        &model(),
        &[
            second_b,
            point(3.0, 1.0, 15000.0, 40.0),
            second_a,
            point(-1.0, 1.0, 15000.0, 0.0),
        ],
    )
    .unwrap();
    assert_eq!(rows.len(), 2);
    assert_eq!(rows[0].id, "F");
    assert_eq!(rows[1].id, "SECOND");
    near(rows[0].entry_time, rows[1].entry_time);
}

#[test]
fn timestamps_preserve_offsets_and_fractional_seconds() {
    near(
        parse_time("2025-01-01T02:00:00.125+02:00").unwrap(),
        parse_time("2025-01-01T00:00:00.125Z").unwrap(),
    );
    near(
        parse_time("2025-01-01 00:00:00.125").unwrap(),
        parse_time("2025-01-01T00:00:00.125Z").unwrap(),
    );
    near(parse_time("123.125").unwrap(), 123.125);
    assert!(parse_time("bad time").is_err());
}

#[test]
fn invalid_points_selections_and_geometry_fail_explicitly() {
    assert!(validate_trajectories(vec![point(0.0, 0.0, 0.0, 0.0)]).is_err());
    assert!(
        validate_trajectories(vec![point(0.0, 0.0, 0.0, 0.0), point(1.0, 0.0, 0.0, 0.0)])
            .unwrap_err()
            .contains("duplicate")
    );
    assert!(
        validate_trajectories(vec![point(0.0, 0.0, 0.0, 0.0), point(180.0, 0.0, 0.0, 1.0)])
            .unwrap_err()
            .contains("ambiguous")
    );
    assert!(validate_trajectories(vec![
        point(f64::NAN, 0.0, 0.0, 0.0),
        point(1.0, 0.0, 0.0, 1.0)
    ])
    .is_err());
    assert!(validate_trajectories(vec![
        point(0.0, 0.0, -f64::MAX, 0.0),
        point(1.0, 0.0, f64::MAX, 1.0)
    ])
    .unwrap_err()
    .contains("overflowing"));
    let error = init_airspaces(
        &fixture("example.are"),
        &fixture("example.sls"),
        &fixture("example.spc"),
        "NAS",
        Some(&["MISSING".into()]),
    )
    .err()
    .unwrap();
    assert!(error.contains("MISSING"));
    assert!(PreparedAirspaces::new(vec![AirspaceBlock {
        airspace_id: "BAD".into(),
        min_altitude: 0.0,
        max_altitude: 100.0,
        coords: Arc::new(vec![[0.0, 0.0], [1.0, 0.0], [2.0, 0.0]]),
    }])
    .is_err());
}

#[test]
fn antimeridian_crossing_both_directions_preserves_entry_exit() {
    let airspaces = PreparedAirspaces::new(vec![AirspaceBlock {
        airspace_id: "DATE".into(),
        min_altitude: 0.0,
        max_altitude: 20000.0,
        coords: Arc::new(vec![
            [179.0, -1.0],
            [-179.0, -1.0],
            [-179.0, 1.0],
            [179.0, 1.0],
        ]),
    }])
    .unwrap();
    for (a, b, entry, exit) in [
        (178.0, -178.0, 179.0, -179.0),
        (-178.0, 178.0, -179.0, 179.0),
    ] {
        let rows = intersect_trajectories(
            &airspaces,
            &[point(a, 0.0, 10000.0, 0.0), point(b, 0.0, 10000.0, 40.0)],
        )
        .unwrap();
        assert_eq!(rows.len(), 1);
        near(rows[0].entry_lon, entry);
        near(rows[0].exit_lon, exit);
        near(rows[0].entry_time, 10.0);
        near(rows[0].exit_time, 30.0);
    }
}

#[test]
fn antimeridian_index_handles_both_sides_and_exact_seam() {
    let blocks = [
        (
            "EAST",
            vec![[178.0, -1.0], [180.0, -1.0], [180.0, 1.0], [178.0, 1.0]],
        ),
        (
            "WEST",
            vec![[-180.0, -1.0], [-178.0, -1.0], [-178.0, 1.0], [-180.0, 1.0]],
        ),
        (
            "GREENWICH",
            vec![[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]],
        ),
    ];
    let airspaces = PreparedAirspaces::new(
        blocks
            .into_iter()
            .map(|(id, coords)| AirspaceBlock {
                airspace_id: id.into(),
                min_altitude: 0.0,
                max_altitude: 20000.0,
                coords: Arc::new(coords),
            })
            .collect(),
    )
    .unwrap();
    let rows = intersect_trajectories(
        &airspaces,
        &[
            point(179.0, 0.0, 10000.0, 0.0),
            point(180.0, 0.0, 10000.0, 10.0),
            point(-179.0, 0.0, 10000.0, 20.0),
        ],
    )
    .unwrap();
    assert_eq!(rows.len(), 2);
    assert_eq!(rows[0].airspace_id, "EAST");
    assert_eq!(rows[1].airspace_id, "WEST");
    assert!(rows[0].starts_inside && rows[1].ends_inside);
    near(rows[0].exit_time, 10.0);
    near(rows[1].entry_time, 10.0);
    let seam = intersect_trajectories(
        &airspaces,
        &[
            point(180.0, 0.0, 10000.0, 0.0),
            point(-180.0, 0.0, 10000.0, 10.0),
        ],
    )
    .unwrap();
    assert_eq!(seam.len(), 2);
}

#[test]
fn shared_polygon_keeps_distinct_airspaces_and_altitudes() {
    let polygon = Arc::new(vec![
        [179.0, -1.0],
        [-179.0, -1.0],
        [-179.0, 1.0],
        [179.0, 1.0],
    ]);
    let airspaces = PreparedAirspaces::new(vec![
        AirspaceBlock {
            airspace_id: "LOW".into(),
            min_altitude: 10000.0,
            max_altitude: 20000.0,
            coords: Arc::clone(&polygon),
        },
        AirspaceBlock {
            airspace_id: "HIGH".into(),
            min_altitude: 20000.0,
            max_altitude: 30000.0,
            coords: Arc::clone(&polygon),
        },
        AirspaceBlock {
            airspace_id: "ELSEWHERE".into(),
            min_altitude: 0.0,
            max_altitude: 30000.0,
            coords: Arc::new(vec![[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]),
        },
    ])
    .unwrap();
    let rows = intersect_trajectories(
        &airspaces,
        &[
            point(178.0, 0.0, 0.0, 0.0),
            point(-178.0, 0.0, 40000.0, 40.0),
        ],
    )
    .unwrap();
    assert_eq!(rows.len(), 2);
    assert_eq!(rows[0].airspace_id, "LOW");
    assert_eq!(rows[1].airspace_id, "HIGH");
    near(rows[0].entry_time, 10.0);
    near(rows[0].exit_time, 20.0);
    near(rows[1].entry_time, 20.0);
    near(rows[1].exit_time, 30.0);
}

#[test]
fn wrapped_intervals_merge_and_multiple_crossings_remain_separate() {
    let airspaces = PreparedAirspaces::new(vec![AirspaceBlock {
        airspace_id: "DATE".into(),
        min_altitude: 10000.0,
        max_altitude: 20000.0,
        coords: Arc::new(vec![
            [179.0, -1.0],
            [-179.0, -1.0],
            [-179.0, 1.0],
            [179.0, 1.0],
        ]),
    }])
    .unwrap();
    let rows = intersect_trajectories(
        &airspaces,
        &[
            point(178.0, 0.0, 15000.0, 0.0),
            point(-180.0, 0.0, 15000.0, 20.0),
            point(-178.0, 0.0, 15000.0, 40.0),
            point(178.0, 0.0, 15000.0, 80.0),
        ],
    )
    .unwrap();
    assert_eq!(rows.len(), 2);
    near(rows[0].entry_time, 10.0);
    near(rows[0].exit_time, 30.0);
    near(rows[1].entry_time, 50.0);
    near(rows[1].exit_time, 70.0);
}

#[test]
fn longitude_crossing_intersects_altitude_band() {
    let airspaces = PreparedAirspaces::new(vec![AirspaceBlock {
        airspace_id: "DATE".into(),
        min_altitude: 10000.0,
        max_altitude: 20000.0,
        coords: Arc::new(vec![
            [179.0, -1.0],
            [-179.0, -1.0],
            [-179.0, 1.0],
            [179.0, 1.0],
        ]),
    }])
    .unwrap();
    let rows = intersect_trajectories(
        &airspaces,
        &[
            point(178.0, 0.0, 0.0, 0.0),
            point(-178.0, 0.0, 40000.0, 40.0),
        ],
    )
    .unwrap();
    assert_eq!(rows.len(), 1);
    near(rows[0].entry_time, 10.0);
    near(rows[0].exit_time, 20.0);
    near(rows[0].entry_altitude_ft, 10000.0);
    near(rows[0].exit_altitude_ft, 20000.0);
}

#[test]
fn nested_region_area_and_elementary_sector_selection() {
    for (kind, id, count) in [("REG", "REGION", 4), ("AREA", "AREA1", 1), ("ES", "S1", 1)] {
        let airspaces = init_airspaces(
            &fixture("example.are"),
            &fixture("example.sls"),
            &fixture("example.spc"),
            kind,
            Some(&[id.into()]),
        )
        .unwrap();
        assert_eq!(airspaces.airspace_ids(), vec![id]);
        assert_eq!(airspaces.block_count(), count);
    }
}
