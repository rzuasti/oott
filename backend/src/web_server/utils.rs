use std::collections::HashMap;

use chrono::{DateTime, Utc};
use log::{debug, warn};

pub fn parse_parameter_bool(params: &HashMap<String, String>, name: &str) -> Option<bool> {
    if params.contains_key(name) {
        let param_value = params.get(name).unwrap().as_str();
        debug!("Found parameter {name} with value {}", param_value);
        match param_value.parse::<bool>() {
            Ok(value) => Some(value),
            Err(_) => None,
        }
    } else {
        None
    }
}

pub fn parse_parameter_string(params: &HashMap<String, String>, name: &str) -> Option<String> {
    if params.contains_key(name) {
        let param_value = params.get(name).unwrap().as_str();
        debug!("Found parameter {name} with value {}", param_value);
        Some(param_value.to_string())
    } else {
        None
    }
}

pub fn parse_parameter_date(params: &HashMap<String, String>, name: &str) -> Option<DateTime<Utc>> {
    if params.contains_key(name) {
        let mut param_value = params.get(name).unwrap().to_ascii_uppercase();
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
