use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::Path;
use std::sync::Arc;

use rstar::{RTree, RTreeObject, AABB};

use crate::Result;

pub const AIRSPACE_TYPES: &[&str] = &[
    "AREA", "NAS", "AUA", "AUAG", "REG", "CRAS", "CLUS", "CS", "CRSA", "ES",
];

#[derive(Clone, Debug)]
pub struct AirspaceBlock {
    pub airspace_id: String,
    pub min_altitude: f64,
    pub max_altitude: f64,
    pub coords: Arc<Vec<[f64; 2]>>,
}

pub(crate) struct IndexedBlock {
    pub index: usize,
    pub longitude_offset: f64,
    pub envelope: AABB<[f64; 3]>,
}

struct CachedPolygon {
    _original: Arc<Vec<[f64; 2]>>,
    coords: Arc<Vec<[f64; 2]>>,
    edge_lengths: Arc<Vec<f64>>,
}

impl RTreeObject for IndexedBlock {
    type Envelope = AABB<[f64; 3]>;
    fn envelope(&self) -> Self::Envelope {
        self.envelope
    }
}

pub struct PreparedAirspaces {
    pub(crate) blocks: Vec<AirspaceBlock>,
    pub(crate) edge_lengths: Vec<Arc<Vec<f64>>>,
    pub(crate) tree: RTree<IndexedBlock>,
}

impl PreparedAirspaces {
    pub fn new(mut blocks: Vec<AirspaceBlock>) -> Result<Self> {
        if blocks.is_empty() {
            return Err("airspace selection contains no airblocks".into());
        }
        let mut indexed = Vec::with_capacity(blocks.len() * 3);
        let mut lengths = Vec::with_capacity(blocks.len());
        let mut cache: HashMap<_, CachedPolygon> = HashMap::new();
        for (index, block) in blocks.iter_mut().enumerate() {
            if block.airspace_id.is_empty()
                || !block.min_altitude.is_finite()
                || !block.max_altitude.is_finite()
                || block.min_altitude >= block.max_altitude
            {
                return Err(format!(
                    "invalid airblock limits for '{}'",
                    block.airspace_id
                ));
            }
            let key = Arc::as_ptr(&block.coords);
            if let Some(polygon) = cache.get(&key) {
                block.coords = Arc::clone(&polygon.coords);
                lengths.push(Arc::clone(&polygon.edge_lengths));
            } else {
                let original = Arc::clone(&block.coords);
                let coords = Arc::make_mut(&mut block.coords);
                coords.dedup();
                if coords.first() != coords.last() && !coords.is_empty() {
                    coords.push(coords[0]);
                }
                if coords.len() < 4
                    || coords.iter().any(|p| {
                        !p[0].is_finite()
                            || !p[1].is_finite()
                            || p[0].abs() > 180.0
                            || p[1].abs() > 90.0
                    })
                {
                    return Err(format!("invalid polygon for '{}'", block.airspace_id));
                }
                let mut original_lon = coords[0][0];
                let mut wrap = 0.0;
                for point in coords.iter_mut().skip(1) {
                    let next_lon = point[0];
                    let delta = crate::longitude_delta(original_lon, next_lon)
                        .map_err(|error| format!("polygon for '{}': {error}", block.airspace_id))?;
                    if delta != next_lon - original_lon {
                        wrap += delta - (next_lon - original_lon);
                    }
                    point[0] = next_lon + wrap;
                    original_lon = next_lon;
                }
                if (coords.last().unwrap()[0] - coords[0][0]).abs() > 1e-8 {
                    return Err(format!(
                    "polygon for '{}' winds around the globe; polar or global rings are unsupported",
                    block.airspace_id
                ));
                }
                // Close precisely after unwrapping to avoid accumulated rounding.
                let last = coords.len() - 1;
                coords[last] = coords[0];
                coords.dedup();
                if coords.len() < 4 {
                    return Err(format!("invalid polygon for '{}'", block.airspace_id));
                }
                let min_lon = coords.iter().map(|p| p[0]).fold(f64::INFINITY, f64::min);
                let max_lon = coords
                    .iter()
                    .map(|p| p[0])
                    .fold(f64::NEG_INFINITY, f64::max);
                if max_lon - min_lon >= 360.0 {
                    return Err(format!(
                        "polygon for '{}' spans the globe",
                        block.airspace_id
                    ));
                }
                let shift = ((min_lon + max_lon + 360.0) / 720.0).floor() * 360.0;
                if shift != 0.0 {
                    for point in coords.iter_mut() {
                        point[0] -= shift;
                    }
                }
                let area: f64 = coords
                    .windows(2)
                    .map(|p| p[0][0] * p[1][1] - p[1][0] * p[0][1])
                    .sum();
                if area.abs() < 1e-14 {
                    return Err(format!("zero-area polygon for '{}'", block.airspace_id));
                }
                let edge_lengths = Arc::new(
                    coords
                        .windows(2)
                        .map(|p| {
                            let dx = p[1][0] - p[0][0];
                            let dy = p[1][1] - p[0][1];
                            dx.hypot(dy)
                        })
                        .collect(),
                );
                cache.insert(
                    key,
                    CachedPolygon {
                        _original: original,
                        coords: Arc::clone(&block.coords),
                        edge_lengths: Arc::clone(&edge_lengths),
                    },
                );
                lengths.push(edge_lengths);
            }
            let mut min = [f64::INFINITY, f64::INFINITY, block.min_altitude];
            let mut max = [f64::NEG_INFINITY, f64::NEG_INFINITY, block.max_altitude];
            for point in block.coords.iter() {
                for axis in 0..2 {
                    min[axis] = min[axis].min(point[axis]);
                    max[axis] = max[axis].max(point[axis]);
                }
            }
            for offset in [-360.0, 0.0, 360.0] {
                let mut shifted_min = min;
                let mut shifted_max = max;
                shifted_min[0] += offset;
                shifted_max[0] += offset;
                indexed.push(IndexedBlock {
                    index,
                    longitude_offset: offset,
                    envelope: AABB::from_corners(shifted_min, shifted_max),
                });
            }
        }
        Ok(Self {
            blocks,
            edge_lengths: lengths,
            tree: RTree::bulk_load(indexed),
        })
    }

    pub fn block_count(&self) -> usize {
        self.blocks.len()
    }

    pub fn airspace_ids(&self) -> Vec<String> {
        self.blocks
            .iter()
            .map(|block| block.airspace_id.clone())
            .collect::<BTreeSet<_>>()
            .into_iter()
            .collect()
    }
}

fn lines(path: &Path) -> Result<Vec<String>> {
    let file = File::open(path).map_err(|error| format!("{}: {error}", path.display()))?;
    BufReader::new(file)
        .lines()
        .enumerate()
        .map(|(index, line)| {
            line.map_err(|error| format!("{} line {}: {error}", path.display(), index + 1))
        })
        .collect()
}

#[derive(Debug)]
struct Definition {
    kind: String,
    children: Vec<(String, String)>,
}

fn definitions(path: &Path) -> Result<BTreeMap<String, Definition>> {
    let mut definitions = BTreeMap::new();
    let mut current: Option<String> = None;
    for (index, line) in lines(path)?.iter().enumerate() {
        let line = line.trim();
        if line.is_empty() || (index == 0 && line.parse::<usize>().is_ok()) {
            continue;
        }
        let parts: Vec<_> = line.split(';').map(str::trim).collect();
        let invalid = || {
            format!(
                "{} line {}: invalid SPC definition",
                path.display(),
                index + 1
            )
        };
        match parts.first().copied() {
            Some("A") if parts.len() >= 4 && !parts[1].is_empty() && !parts[3].is_empty() => {
                let id = parts[1].to_owned();
                if definitions
                    .insert(
                        id.clone(),
                        Definition {
                            kind: parts[3].to_owned(),
                            children: Vec::new(),
                        },
                    )
                    .is_some()
                {
                    return Err(format!(
                        "{}: duplicate airspace definition '{id}'",
                        path.display()
                    ));
                }
                current = Some(id);
            }
            Some("S") if parts.len() >= 3 && !parts[1].is_empty() => {
                let id = current.as_ref().ok_or_else(invalid)?;
                definitions
                    .get_mut(id)
                    .ok_or_else(invalid)?
                    .children
                    .push((parts[1].to_owned(), parts[2].to_owned()));
            }
            _ => return Err(invalid()),
        }
    }
    Ok(definitions)
}

fn resolve(
    id: &str,
    expected_type: &str,
    definitions: &BTreeMap<String, Definition>,
    sectors: &HashMap<String, Vec<(String, f64, f64)>>,
    visiting: &mut BTreeSet<String>,
    result: &mut BTreeSet<String>,
) -> Result<()> {
    // ES definitions live in SLS. Other SPC child types (FIR, UIR, ...) may
    // also name elementary sectors directly.
    if expected_type == "ES" || !AIRSPACE_TYPES.contains(&expected_type) {
        if !sectors.contains_key(id) {
            return Err(format!("missing sector reference '{id}'"));
        }
        result.insert(id.to_owned());
        return Ok(());
    }
    let definition = definitions
        .get(id)
        .ok_or_else(|| format!("missing {expected_type} airspace reference '{id}'"))?;
    if definition.kind != expected_type {
        return Err(format!(
            "airspace '{id}' has type {}, expected {expected_type}",
            definition.kind
        ));
    }
    if !visiting.insert(id.to_owned()) {
        return Err(format!("cyclic airspace reference at '{id}'"));
    }
    if definition.children.is_empty() {
        return Err(format!("airspace '{id}' has no sector references"));
    }
    for (child, kind) in &definition.children {
        resolve(child, kind, definitions, sectors, visiting, result)?;
    }
    visiting.remove(id);
    Ok(())
}

pub fn init_airspaces(
    are_file: &Path,
    sls_file: &Path,
    spc_file: &Path,
    airspace_type: &str,
    airspace_ids: Option<&[String]>,
) -> Result<PreparedAirspaces> {
    if !AIRSPACE_TYPES.contains(&airspace_type) {
        return Err(format!("unsupported airspace type '{airspace_type}'"));
    }
    let definitions = definitions(spc_file)?;
    let mut sectors: HashMap<String, Vec<(String, f64, f64)>> = HashMap::new();
    for (index, line) in lines(sls_file)?.iter().enumerate() {
        let parts: Vec<_> = line.split_whitespace().collect();
        if parts.is_empty() {
            continue;
        }
        let invalid = || {
            format!(
                "{} line {}: invalid SLS record",
                sls_file.display(),
                index + 1
            )
        };
        if parts.len() != 5 {
            return Err(invalid());
        }
        let low: f64 = parts[3].parse().map_err(|_| invalid())?;
        let high: f64 = parts[4].parse().map_err(|_| invalid())?;
        if !low.is_finite() || !high.is_finite() || low >= high {
            return Err(invalid());
        }
        sectors.entry(parts[0].to_owned()).or_default().push((
            parts[2].to_owned(),
            low * 100.0,
            high * 100.0,
        ));
    }
    let available: BTreeSet<String> = if airspace_type == "ES" {
        sectors.keys().cloned().collect()
    } else {
        definitions
            .iter()
            .filter(|(_, definition)| definition.kind == airspace_type)
            .map(|(id, _)| id.clone())
            .collect()
    };
    let selected: BTreeSet<String> = match airspace_ids {
        Some([]) => return Err("airspace_ids must be NULL or nonempty".into()),
        Some(ids) => ids.iter().cloned().collect(),
        None => available.clone(),
    };
    if selected.is_empty() {
        return Err(format!("no '{airspace_type}' airspaces found"));
    }
    if let Some(missing) = selected.difference(&available).next() {
        return Err(format!("unknown '{airspace_type}' airspace ID '{missing}'"));
    }
    let mut assignments = Vec::new();
    let mut needed = BTreeSet::new();
    for id in selected {
        let mut resolved = BTreeSet::new();
        resolve(
            &id,
            airspace_type,
            &definitions,
            &sectors,
            &mut BTreeSet::new(),
            &mut resolved,
        )?;
        for sector in resolved {
            for (block, low, high) in &sectors[&sector] {
                assignments.push((id.clone(), block.clone(), *low, *high));
                needed.insert(block.clone());
            }
        }
    }
    let mut polygons: HashMap<String, Vec<[f64; 2]>> = HashMap::new();
    let mut current = String::new();
    let mut expected = 0_usize;
    let mut actual = 0_usize;
    let check_count = |id: &str, expected: usize, actual: usize| -> Result<()> {
        // ARE counts the coordinate records following its header. Retain the
        // header's coordinate too, matching the original PIE Rust parser.
        let vertices = actual.saturating_sub(1);
        if !id.is_empty() && expected != vertices {
            Err(format!(
                "{}: polygon '{id}' declares {expected} vertices but contains {vertices}",
                are_file.display()
            ))
        } else {
            Ok(())
        }
    };
    for (index, line) in lines(are_file)?.iter().enumerate() {
        let parts: Vec<_> = line.split_whitespace().collect();
        if parts.is_empty() {
            continue;
        }
        let invalid = || {
            format!(
                "{} line {}: invalid ARE record",
                are_file.display(),
                index + 1
            )
        };
        let (lat, lon) = if parts.len() == 15 {
            check_count(&current, expected, actual)?;
            expected = parts[0].parse().map_err(|_| invalid())?;
            actual = 0;
            current = parts[14].to_owned();
            if needed.contains(&current) && polygons.insert(current.clone(), Vec::new()).is_some() {
                return Err(format!(
                    "{}: duplicate polygon '{current}'",
                    are_file.display()
                ));
            }
            (parts[1], parts[2])
        } else if parts.len() == 2 && !current.is_empty() {
            (parts[0], parts[1])
        } else {
            return Err(invalid());
        };
        actual += 1;
        if needed.contains(&current) {
            let lat: f64 = lat.parse().map_err(|_| invalid())?;
            let lon: f64 = lon.parse().map_err(|_| invalid())?;
            polygons
                .get_mut(&current)
                .ok_or_else(invalid)?
                .push([lon / 60.0, lat / 60.0]);
        }
    }
    check_count(&current, expected, actual)?;
    let polygons: HashMap<_, _> = polygons
        .into_iter()
        .map(|(id, coords)| (id, Arc::new(coords)))
        .collect();
    let mut blocks = Vec::new();
    for (id, block, low, high) in assignments {
        let coords = polygons
            .get(&block)
            .ok_or_else(|| format!("airspace '{id}' references missing ARE polygon '{block}'"))?;
        blocks.push(AirspaceBlock {
            airspace_id: id,
            min_altitude: low,
            max_altitude: high,
            coords: Arc::clone(coords),
        });
    }
    PreparedAirspaces::new(blocks)
}
