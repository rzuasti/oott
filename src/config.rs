use log::error;
use std::env;
use std::fmt::Display;
use std::str::FromStr;

pub fn parse_env<T>(variable: &str) -> Option<T>
where
    T: FromStr,
    <T as FromStr>::Err: Display,
{
    env::var(variable)
        .map_err(|error| error!("{error}: {variable}"))
        .ok()
        .and_then(|raw| {
            raw.parse::<T>()
                .map_err(|error| error!("{error}: {raw}"))
                .ok()
        })
}
