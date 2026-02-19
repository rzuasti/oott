use std::{error, fmt};

#[derive(Debug)]
pub enum DbError {
    Parse(rusqlite::Error),
}

impl fmt::Display for DbError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match *self {
            DbError::Parse(..) => write!(f, "Database access error"),
        }
    }
}

impl error::Error for DbError {
    fn source(&self) -> Option<&(dyn error::Error + 'static)> {
        match *self {
            DbError::Parse(ref e) => Some(e),
        }
    }
}

impl From<rusqlite::Error> for DbError {
    fn from(err: rusqlite::Error) -> DbError {
        DbError::Parse(err)
    }
}
