use std::{error, fmt};

use crate::db::error::DbError;

#[derive(Debug)]
pub enum DeliveryError {
    ParsePushover(pushover::Error),
    Http(reqwest::Error),
    Db(DbError),
}

impl fmt::Display for DeliveryError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match *self {
            DeliveryError::ParsePushover(..) => {
                write!(f, "Error delivering notification via Pushover")
            }
            DeliveryError::Http(..) => {
                write!(f, "Error delivering notification via the push relay")
            }
            DeliveryError::Db(..) => {
                write!(f, "Database error while delivering a push notification")
            }
        }
    }
}

impl error::Error for DeliveryError {
    fn source(&self) -> Option<&(dyn error::Error + 'static)> {
        match *self {
            DeliveryError::ParsePushover(ref e) => Some(e),
            DeliveryError::Http(ref e) => Some(e),
            DeliveryError::Db(ref e) => Some(e),
        }
    }
}

impl From<pushover::Error> for DeliveryError {
    fn from(err: pushover::Error) -> DeliveryError {
        DeliveryError::ParsePushover(err)
    }
}

impl From<reqwest::Error> for DeliveryError {
    fn from(err: reqwest::Error) -> DeliveryError {
        DeliveryError::Http(err)
    }
}

impl From<DbError> for DeliveryError {
    fn from(err: DbError) -> DeliveryError {
        DeliveryError::Db(err)
    }
}
