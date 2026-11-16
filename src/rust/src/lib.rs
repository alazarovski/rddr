//! Portable airspace profiles. The R interface is an optional build feature.

mod airspace;
mod intersection;
mod trajectory;

#[cfg(feature = "r-api")]
mod bindings;

pub use airspace::{init_airspaces, AirspaceBlock, PreparedAirspaces};
pub use intersection::{intersect_trajectories, Profile};
pub use trajectory::{parse_time, read_trajectories, validate_trajectories, TrajPoint};

pub type Result<T> = std::result::Result<T, String>;

fn longitude_delta(start: f64, end: f64) -> Result<f64> {
    let delta = end - start;
    if delta.abs() == 180.0 {
        return Err("longitude difference of exactly 180 degrees is ambiguous".into());
    }
    Ok(if delta > 180.0 {
        delta - 360.0
    } else if delta < -180.0 {
        delta + 360.0
    } else {
        delta
    })
}
