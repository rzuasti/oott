use std::collections::HashMap;
use std::str::FromStr;

use chrono::{DateTime, Utc};
use log::{debug, warn};

// Parses a query parameter into any `FromStr` type (e.g. bool, i64, String). Returns `None` when
// the parameter is absent or fails to parse. The target type is inferred from the call site, so
// callers annotate the binding: `let limit: Option<i64> = parse_parameter(&params, "page_limit");`
pub fn parse_parameter<T: FromStr>(params: &HashMap<String, String>, name: &str) -> Option<T> {
    let param_value = params.get(name)?;
    debug!("Found parameter {name} with value {param_value}");
    param_value.parse::<T>().ok()
}

pub fn parse_parameter_date(params: &HashMap<String, String>, name: &str) -> Option<DateTime<Utc>> {
    if let Some(value) = params.get(name) {
        let mut param_value = value.to_ascii_uppercase();
        if !param_value.ends_with("Z") {
            param_value.push('Z');
        }
        debug!("Found parameter {name} with value {}", param_value);
        match DateTime::parse_from_rfc3339(param_value.as_str()) {
            Ok(value) => {
                debug!("Date parsed to {}", value.to_utc().to_rfc3339());
                Some(value.to_utc())
            }
            Err(err) => {
                warn!("Error parsing date from parameters: {}", err);
                None
            }
        }
    } else {
        None
    }
}
