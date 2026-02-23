use std::{error, fmt};

#[derive(Debug)]
pub enum DeliveryError {
    ParsePushover(pushover::Error),
}

impl fmt::Display for DeliveryError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match *self {
            DeliveryError::ParsePushover(..) => {
                write!(f, "Error delivering notification via Pushover")
            }
        }
    }
}

impl error::Error for DeliveryError {
    fn source(&self) -> Option<&(dyn error::Error + 'static)> {
        match *self {
            DeliveryError::ParsePushover(ref e) => Some(e),
        }
    }
}

impl From<pushover::Error> for DeliveryError {
    fn from(err: pushover::Error) -> DeliveryError {
        DeliveryError::ParsePushover(err)
    }
}
