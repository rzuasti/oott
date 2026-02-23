use std::{error, fmt};

#[derive(Debug)]
pub enum DbError {
    ParseRusqlite(rusqlite::Error),
    ParseRusqliteMigration(rusqlite_migration::Error),
}

impl fmt::Display for DbError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match *self {
            DbError::ParseRusqlite(..) => write!(f, "Database access error"),
            DbError::ParseRusqliteMigration(..) => write!(f, "Database migration error"),
        }
    }
}

impl error::Error for DbError {
    fn source(&self) -> Option<&(dyn error::Error + 'static)> {
        match *self {
            DbError::ParseRusqlite(ref e) => Some(e),
            DbError::ParseRusqliteMigration(ref e) => Some(e),
        }
    }
}

impl From<rusqlite::Error> for DbError {
    fn from(err: rusqlite::Error) -> DbError {
        DbError::ParseRusqlite(err)
    }
}
impl From<rusqlite_migration::Error> for DbError {
    fn from(err: rusqlite_migration::Error) -> DbError {
        DbError::ParseRusqliteMigration(err)
    }
}
