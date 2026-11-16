use std::collections::BTreeMap;
use std::path::Path;

use chrono::{DateTime, NaiveDateTime};

use crate::Result;

#[derive(Clone, Debug)]
pub struct TrajPoint {
    pub id: String,
    pub lon: f64,
    pub lat: f64,
    pub altitude: f64,
    pub time: f64,
}

pub fn parse_time(value: &str) -> Result<f64> {
    let value = value.trim();
    if let Ok(seconds) = value.parse::<f64>() {
        if seconds.is_finite() {
            return Ok(seconds);
        }
    }
    if let Ok(time) = DateTime::parse_from_rfc3339(value) {
        return Ok(time.timestamp() as f64 + f64::from(time.timestamp_subsec_nanos()) / 1e9);
    }
    for format in ["%Y-%m-%dT%H:%M:%S%.f", "%Y-%m-%d %H:%M:%S%.f"] {
        if let Ok(time) = NaiveDateTime::parse_from_str(value, format) {
            let time = time.and_utc();
            return Ok(time.timestamp() as f64 + f64::from(time.timestamp_subsec_nanos()) / 1e9);
        }
    }
    Err(format!(
        "invalid timestamp '{value}'; use ISO 8601 or Unix seconds"
    ))
}

pub fn validate_trajectories(mut points: Vec<TrajPoint>) -> Result<Vec<TrajPoint>> {
    if points.is_empty() {
        return Err("trajectory contains no points".into());
    }
    for (i, point) in points.iter().enumerate() {
        if point.id.trim().is_empty()
            || !point.lon.is_finite()
            || !point.lat.is_finite()
            || !point.altitude.is_finite()
            || !point.time.is_finite()
            || point.lon.abs() > 180.0
            || point.lat.abs() > 90.0
        {
            return Err(format!("invalid trajectory values at row {}", i + 1));
        }
    }
    let order = |a: &TrajPoint, b: &TrajPoint| a.id.cmp(&b.id).then(a.time.total_cmp(&b.time));
    if !points.is_sorted_by(|a, b| order(a, b) != std::cmp::Ordering::Greater) {
        points.sort_by(order);
    }
    let mut counts = BTreeMap::new();
    for point in &points {
        *counts.entry(&point.id).or_insert(0_usize) += 1;
    }
    if let Some((id, _)) = counts.iter().find(|(_, count)| **count < 2) {
        return Err(format!("flight '{id}' needs at least two points"));
    }
    for pair in points.windows(2).filter(|pair| pair[0].id == pair[1].id) {
        if pair[0].time == pair[1].time {
            return Err(format!("flight '{}' has duplicate timestamps", pair[0].id));
        }
        if !(pair[1].time - pair[0].time).is_finite()
            || !(pair[1].altitude - pair[0].altitude).is_finite()
        {
            return Err(format!(
                "flight '{}' has an overflowing time or altitude range",
                pair[0].id
            ));
        }
        crate::longitude_delta(pair[0].lon, pair[1].lon)
            .map_err(|error| format!("flight '{}': {error}", pair[0].id))?;
    }
    Ok(points)
}

pub fn read_trajectories<P: AsRef<Path>>(paths: &[P]) -> Result<Vec<TrajPoint>> {
    if paths.is_empty() {
        return Err("provide at least one trajectory CSV path".into());
    }
    let mut points = Vec::new();
    for path in paths {
        let path = path.as_ref();
        let mut reader =
            csv::Reader::from_path(path).map_err(|error| format!("{}: {error}", path.display()))?;
        let headers = reader
            .headers()
            .map_err(|error| format!("{}: {error}", path.display()))?
            .clone();
        let mut columns = Vec::new();
        for name in ["id", "lon", "lat", "altitude", "time_over"] {
            let matches: Vec<_> = headers
                .iter()
                .enumerate()
                .filter(|(_, header)| *header == name)
                .map(|(index, _)| index)
                .collect();
            if matches.len() != 1 {
                return Err(format!(
                    "{}: expected exactly one '{name}' column",
                    path.display()
                ));
            }
            columns.push(matches[0]);
        }
        for (index, row) in reader.records().enumerate() {
            let context = |message| format!("{} row {}: {message}", path.display(), index + 2);
            let row = row.map_err(|error| context(error.to_string()))?;
            let number = |column: usize| -> Result<f64> {
                row[columns[column]].trim().parse().map_err(|_| {
                    context(format!("invalid {}", headers.get(columns[column]).unwrap()))
                })
            };
            points.push(TrajPoint {
                id: row[columns[0]].to_owned(),
                lon: number(1)?,
                lat: number(2)?,
                altitude: number(3)?,
                time: parse_time(&row[columns[4]]).map_err(context)?,
            });
        }
    }
    validate_trajectories(points)
}
