use std::path::Path;

use extendr_api::prelude::*;
use extendr_api::Result;

use crate::{PreparedAirspaces, TrajPoint};

extern "C" {
    fn R_FlushConsole();
}

fn r_error(message: String) -> Error {
    Error::Other(message)
}

fn trajectory_frame(points: &[TrajPoint]) -> List {
    list!(
        id = points.iter().map(|p| p.id.clone()).collect::<Vec<_>>(),
        lon = points.iter().map(|p| p.lon).collect::<Vec<_>>(),
        lat = points.iter().map(|p| p.lat).collect::<Vec<_>>(),
        altitude = points.iter().map(|p| p.altitude).collect::<Vec<_>>(),
        time_over = points.iter().map(|p| p.time).collect::<Vec<_>>()
    )
}

#[extendr]
fn airspaces_init(
    are_file: &str,
    sls_file: &str,
    spc_file: &str,
    airspace_type: &str,
    ids: Nullable<Vec<String>>,
) -> Result<Robj> {
    let ids = match ids {
        Nullable::Null => None,
        Nullable::NotNull(ids) => Some(ids),
    };
    let prepared = crate::init_airspaces(
        Path::new(are_file),
        Path::new(sls_file),
        Path::new(spc_file),
        airspace_type,
        ids.as_deref(),
    )
    .map_err(r_error)?;
    let count = prepared.block_count() as f64;
    let ids = prepared.airspace_ids();
    let mut pointer: Robj = ExternalPtr::new(prepared).into();
    pointer.set_class(["rddr_airspaces"])?;
    pointer.set_attrib("airspace_ids", ids)?;
    pointer.set_attrib("airspace_type", airspace_type)?;
    pointer.set_attrib("block_count", count)?;
    Ok(pointer)
}

#[extendr]
fn trajectories_read(paths: Vec<String>) -> Result<List> {
    let points = crate::read_trajectories(&paths).map_err(r_error)?;
    Ok(trajectory_frame(&points))
}

#[extendr]
fn trajectories_intersect(airspaces: Robj, trajectory: List, progress: bool) -> Result<List> {
    // Check the tag before extendr downcasts its Box<dyn Any>. Unrelated R
    // external pointers need not contain a Rust box.
    if !airspaces.is_external_pointer()
        || !airspaces.inherits("rddr_airspaces")
        || unsafe { airspaces.external_ptr_tag() }.as_str()
            != Some(std::any::type_name::<PreparedAirspaces>())
    {
        return Err(r_error(
            "invalid airspaces object; call init_airspaces() in this R session".into(),
        ));
    }
    let pointer = ExternalPtr::<PreparedAirspaces>::try_from(&airspaces).map_err(|_| {
        r_error(
            "airspaces object is no longer valid; call init_airspaces() in this R session".into(),
        )
    })?;
    let started = std::time::Instant::now();
    if progress {
        rprintln!("[rddr] Preparing trajectory points for Rust.");
        unsafe { R_FlushConsole() };
    }
    let lon_column = trajectory.dollar("lon")?;
    let lat_column = trajectory.dollar("lat")?;
    let altitude_column = trajectory.dollar("altitude")?;
    let id_column = trajectory.dollar("id")?;
    let ids = id_column
        .as_str_vector()
        .ok_or_else(|| r_error("'id' must be character".into()))?;
    let lon = lon_column
        .as_real_slice()
        .ok_or_else(|| r_error("'lon' must be numeric".into()))?;
    let lat = lat_column
        .as_real_slice()
        .ok_or_else(|| r_error("'lat' must be numeric".into()))?;
    let altitude = altitude_column
        .as_real_slice()
        .ok_or_else(|| r_error("'altitude' must be numeric".into()))?;
    let time_column = trajectory.dollar("time_over")?;
    let parsed_times;
    let times = if let Some(times) = time_column.as_real_slice() {
        times
    } else if let Some(times) = time_column.as_str_vector() {
        parsed_times = times
            .into_iter()
            .map(crate::parse_time)
            .collect::<crate::Result<Vec<_>>>()
            .map_err(r_error)?;
        &parsed_times
    } else {
        return Err(r_error(
            "'time_over' must be UTC times, Unix seconds or ISO 8601 strings".into(),
        ));
    };
    if [lon.len(), lat.len(), altitude.len(), times.len()]
        .iter()
        .any(|length| *length != ids.len())
    {
        return Err(r_error("trajectory columns have different lengths".into()));
    }
    let points: Vec<_> = (0..ids.len())
        .map(|i| TrajPoint {
            id: ids[i].to_owned(),
            lon: lon[i],
            lat: lat[i],
            altitude: altitude[i],
            time: times[i],
        })
        .collect();
    if progress {
        rprintln!("[rddr] Validating and sorting trajectory points.");
        unsafe { R_FlushConsole() };
    }
    let mut report = |event| {
        use crate::intersection::Progress;
        match event {
            Progress::Started {
                points,
                flights,
                segments,
            } => {
                rprintln!(
                    "[rddr] Intersecting {segments} segments from {flights} flights ({points} points)."
                );
            }
            Progress::Segments {
                processed,
                total,
                completed_flights,
                profiles,
            } => {
                rprintln!(
                    "[rddr] Segments: {processed}/{total} ({:.1}%); completed flights: {completed_flights}; profiles from completed flights: {profiles}; elapsed: {:.1}s.",
                    100.0 * processed as f64 / total as f64,
                    started.elapsed().as_secs_f64()
                );
            }
            Progress::Sorting { profiles } => {
                rprintln!("[rddr] Segment processing complete; sorting {profiles} profiles.");
            }
        }
        unsafe { R_FlushConsole() };
    };
    let callback = if progress {
        Some(&mut report as &mut dyn FnMut(crate::intersection::Progress))
    } else {
        None
    };
    let profiles =
        crate::intersection::intersect_trajectories_owned(pointer.try_addr()?, points, callback)
            .map_err(r_error)?;
    if progress {
        rprintln!("[rddr] Converting {} profiles for R.", profiles.len());
        unsafe { R_FlushConsole() };
    }
    macro_rules! column {
        ($field:ident) => {
            profiles
                .iter()
                .map(|p| p.$field.clone())
                .collect::<Vec<_>>()
        };
    }
    Ok(list!(
        id = column!(id),
        airspace_id = column!(airspace_id),
        visit_id = column!(visit_id),
        entry_lon = column!(entry_lon),
        entry_lat = column!(entry_lat),
        exit_lon = column!(exit_lon),
        exit_lat = column!(exit_lat),
        entry_altitude_ft = column!(entry_altitude_ft),
        exit_altitude_ft = column!(exit_altitude_ft),
        entry_time = column!(entry_time),
        exit_time = column!(exit_time),
        starts_inside = column!(starts_inside),
        ends_inside = column!(ends_inside)
    ))
}

extendr_module! {
    mod rddr;
    fn airspaces_init;
    fn trajectories_read;
    fn trajectories_intersect;
}
