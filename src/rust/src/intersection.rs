use std::collections::BTreeMap;

use rstar::AABB;

use crate::{validate_trajectories, PreparedAirspaces, Result, TrajPoint};

const PARAM_EPS: f64 = 1e-12;
const COORD_EPS: f64 = 1e-10;

#[cfg_attr(not(feature = "r-api"), allow(dead_code))]
pub(crate) enum Progress {
    Started {
        points: usize,
        flights: usize,
        segments: usize,
    },
    Segments {
        processed: usize,
        total: usize,
        completed_flights: usize,
        profiles: usize,
    },
    Sorting {
        profiles: usize,
    },
}

#[derive(Clone, Debug)]
pub struct Profile {
    pub id: String,
    pub airspace_id: String,
    pub visit_id: i32,
    pub entry_lon: f64,
    pub entry_lat: f64,
    pub exit_lon: f64,
    pub exit_lat: f64,
    pub entry_altitude_ft: f64,
    pub exit_altitude_ft: f64,
    pub entry_time: f64,
    pub exit_time: f64,
    pub starts_inside: bool,
    pub ends_inside: bool,
}

fn cross(a: [f64; 2], b: [f64; 2]) -> f64 {
    a[0] * b[1] - a[1] * b[0]
}

fn subtract(a: [f64; 2], b: [f64; 2]) -> [f64; 2] {
    [a[0] - b[0], a[1] - b[1]]
}

fn inside(point: [f64; 2], polygon: &[[f64; 2]], edge_lengths: &[f64]) -> bool {
    let mut inside = false;
    for (edge, &length) in polygon.windows(2).zip(edge_lengths) {
        let [a, b] = [edge[0], edge[1]];
        let delta = subtract(b, a);
        if cross(subtract(point, a), delta).abs() <= COORD_EPS * length
            && point[0] >= a[0].min(b[0]) - COORD_EPS
            && point[0] <= a[0].max(b[0]) + COORD_EPS
            && point[1] >= a[1].min(b[1]) - COORD_EPS
            && point[1] <= a[1].max(b[1]) + COORD_EPS
        {
            return true;
        }
        if (a[1] > point[1]) != (b[1] > point[1])
            && a[0] + (point[1] - a[1]) * delta[0] / delta[1] > point[0]
        {
            inside = !inside;
        }
    }
    inside
}

fn horizontal_intervals(
    start: [f64; 2],
    end: [f64; 2],
    polygon: &[[f64; 2]],
    edge_lengths: &[f64],
    cuts: &mut Vec<f64>,
    intervals: &mut Vec<(f64, f64)>,
) {
    let direction = subtract(end, start);
    let squared_length = direction[0].powi(2) + direction[1].powi(2);
    intervals.clear();
    if squared_length == 0.0 {
        if inside(start, polygon, edge_lengths) {
            intervals.push((0.0, 1.0));
        }
        return;
    }
    cuts.clear();
    cuts.extend_from_slice(&[0.0, 1.0]);
    let direction_length = direction[0].hypot(direction[1]);
    for (edge, &edge_length) in polygon.windows(2).zip(edge_lengths) {
        let delta = subtract(edge[1], edge[0]);
        let offset = subtract(edge[0], start);
        let denominator = cross(direction, delta);
        let scale = direction_length * edge_length;
        if denominator.abs() > 1e-14 * scale {
            let t = cross(offset, delta) / denominator;
            let u = cross(offset, direction) / denominator;
            if (-PARAM_EPS..=1.0 + PARAM_EPS).contains(&t)
                && (-PARAM_EPS..=1.0 + PARAM_EPS).contains(&u)
            {
                cuts.push(t.clamp(0.0, 1.0));
            }
        } else if cross(offset, direction).abs() <= COORD_EPS * direction_length {
            // Collinear edges contribute their endpoints; midpoint testing
            // below consistently includes travel along a boundary.
            for vertex in edge {
                let offset = subtract(*vertex, start);
                let t = (offset[0] * direction[0] + offset[1] * direction[1]) / squared_length;
                if (0.0..=1.0).contains(&t) {
                    cuts.push(t);
                }
            }
        }
    }
    cuts.sort_by(f64::total_cmp);
    cuts.dedup_by(|a, b| (*a - *b).abs() <= PARAM_EPS);
    intervals.extend(cuts.windows(2).filter_map(|pair| {
        let midpoint = (pair[0] + pair[1]) / 2.0;
        (pair[1] - pair[0] > PARAM_EPS
            && inside(
                [
                    start[0] + midpoint * direction[0],
                    start[1] + midpoint * direction[1],
                ],
                polygon,
                edge_lengths,
            ))
        .then_some((pair[0], pair[1]))
    }))
}

fn interpolate(points: &[TrajPoint], position: f64) -> [f64; 4] {
    let index = (position.floor() as usize).min(points.len() - 2);
    let fraction = position - index as f64;
    let a = &points[index];
    let b = &points[index + 1];
    let delta = crate::longitude_delta(a.lon, b.lon).expect("longitude differences were validated");
    let lon = a.lon + fraction * delta;
    let lon = if lon > 180.0 {
        lon - 360.0
    } else if lon < -180.0 {
        lon + 360.0
    } else {
        lon
    };
    [
        lon,
        a.lat + fraction * (b.lat - a.lat),
        a.altitude + fraction * (b.altitude - a.altitude),
        a.time + fraction * (b.time - a.time),
    ]
}

pub fn intersect_trajectories(
    airspaces: &PreparedAirspaces,
    points: &[TrajPoint],
) -> Result<Vec<Profile>> {
    intersect_trajectories_owned(airspaces, points.to_vec(), None)
}

pub(crate) fn intersect_trajectories_owned(
    airspaces: &PreparedAirspaces,
    points: Vec<TrajPoint>,
    mut progress: Option<&mut dyn FnMut(Progress)>,
) -> Result<Vec<Profile>> {
    let points = validate_trajectories(points)?;
    let mut processed_segments = 0;
    let mut completed_flights = 0;
    let mut next_report = 0;
    let mut report_interval = 0;
    let mut total_segments = 0;
    if let Some(report) = progress.as_mut() {
        let flights = 1 + points
            .windows(2)
            .filter(|pair| pair[0].id != pair[1].id)
            .count();
        total_segments = points.len() - flights;
        report_interval = total_segments.div_ceil(100);
        next_report = report_interval;
        report(Progress::Started {
            points: points.len(),
            flights,
            segments: total_segments,
        });
    }
    let mut output = Vec::new();
    let mut cuts = Vec::new();
    let mut scratch_intervals = Vec::new();
    let mut start = 0;
    while start < points.len() {
        let mut end = start + 1;
        while end < points.len() && points[end].id == points[start].id {
            end += 1;
        }
        let flight = &points[start..end];
        let mut intervals: BTreeMap<&str, Vec<(f64, f64)>> = BTreeMap::new();
        for (index, pair) in flight.windows(2).enumerate() {
            let a = &pair[0];
            let b = &pair[1];
            let end_lon = a.lon + crate::longitude_delta(a.lon, b.lon)?;
            let envelope = AABB::from_corners(
                [
                    a.lon.min(end_lon),
                    a.lat.min(b.lat),
                    a.altitude.min(b.altitude),
                ],
                [
                    a.lon.max(end_lon),
                    a.lat.max(b.lat),
                    a.altitude.max(b.altitude),
                ],
            );
            for candidate in airspaces.tree.locate_in_envelope_intersecting(&envelope) {
                let block = &airspaces.blocks[candidate.index];
                let difference = b.altitude - a.altitude;
                let (low, high) = if difference == 0.0 {
                    if a.altitude < block.min_altitude || a.altitude > block.max_altitude {
                        continue;
                    }
                    (0.0, 1.0)
                } else {
                    let t1 = (block.min_altitude - a.altitude) / difference;
                    let t2 = (block.max_altitude - a.altitude) / difference;
                    (t1.min(t2).max(0.0), t1.max(t2).min(1.0))
                };
                if high - low <= PARAM_EPS {
                    continue;
                }
                horizontal_intervals(
                    [a.lon - candidate.longitude_offset, a.lat],
                    [end_lon - candidate.longitude_offset, b.lat],
                    &block.coords,
                    &airspaces.edge_lengths[candidate.index],
                    &mut cuts,
                    &mut scratch_intervals,
                );
                for &(entry, exit) in &scratch_intervals {
                    let entry = entry.max(low);
                    let exit = exit.min(high);
                    if exit - entry > PARAM_EPS {
                        intervals
                            .entry(&block.airspace_id)
                            .or_default()
                            .push((index as f64 + entry, index as f64 + exit));
                    }
                }
            }
            if let Some(report) = progress.as_mut() {
                processed_segments += 1;
                if processed_segments >= next_report || processed_segments == total_segments {
                    report(Progress::Segments {
                        processed: processed_segments,
                        total: total_segments,
                        completed_flights,
                        profiles: output.len(),
                    });
                    next_report = processed_segments.saturating_add(report_interval);
                }
            }
        }
        for (airspace_id, mut visits) in intervals {
            visits.sort_by(|a, b| a.0.total_cmp(&b.0).then(a.1.total_cmp(&b.1)));
            let mut merged: Vec<(f64, f64)> = Vec::new();
            for (entry, exit) in visits {
                if let Some(last) = merged.last_mut() {
                    if entry <= last.1 + PARAM_EPS {
                        last.1 = last.1.max(exit);
                        continue;
                    }
                }
                merged.push((entry, exit));
            }
            for (visit, (entry, exit)) in merged.into_iter().enumerate() {
                let e = interpolate(flight, entry);
                let x = interpolate(flight, exit);
                output.push(Profile {
                    id: flight[0].id.clone(),
                    airspace_id: airspace_id.to_owned(),
                    visit_id: i32::try_from(visit + 1).map_err(|_| "too many airspace visits")?,
                    entry_lon: e[0],
                    entry_lat: e[1],
                    exit_lon: x[0],
                    exit_lat: x[1],
                    entry_altitude_ft: e[2],
                    exit_altitude_ft: x[2],
                    entry_time: e[3],
                    exit_time: x[3],
                    starts_inside: entry <= PARAM_EPS,
                    ends_inside: exit >= (flight.len() - 1) as f64 - PARAM_EPS,
                });
            }
        }
        completed_flights += 1;
        start = end;
    }
    if let Some(report) = progress.as_mut() {
        report(Progress::Sorting {
            profiles: output.len(),
        });
    }
    output.sort_by(|a, b| {
        a.id.cmp(&b.id)
            .then(a.entry_time.total_cmp(&b.entry_time))
            .then(a.airspace_id.cmp(&b.airspace_id))
            .then(a.visit_id.cmp(&b.visit_id))
    });
    Ok(output)
}
