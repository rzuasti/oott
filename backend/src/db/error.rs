use std::{error, fmt};

#[derive(Debug)]
pub enum DbError {
    ParseRusqlite(rusqlite::Error),
    ParseRusqliteMigration(rusqlite_migration::Error),
    Pool(r2d2::Error),
}

impl fmt::Display for DbError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match *self {
            DbError::ParseRusqlite(..) => write!(f, "Database access error"),
            DbError::ParseRusqliteMigration(..) => write!(f, "Database migration error"),
            DbError::Pool(..) => write!(f, "Database connection pool error"),
        }
    }
}

impl error::Error for DbError {
    fn source(&self) -> Option<&(dyn error::Error + 'static)> {
        match *self {
            DbError::ParseRusqlite(ref e) => Some(e),
            DbError::ParseRusqliteMigration(ref e) => Some(e),
            DbError::Pool(ref e) => Some(e),
        }
    }
}

impl From<rusqlite::Error> for DbError {
    fn from(err: rusqlite::Error) -> DbError {
        DbError::ParseRusqlite(err)
    }
}
impl From<r2d2::Error> for DbError {
    fn from(err: r2d2::Error) -> DbError {
        DbError::Pool(err)
    }
}
impl From<rusqlite_migration::Error> for DbError {
    fn from(err: rusqlite_migration::Error) -> DbError {
        DbError::ParseRusqliteMigration(err)
    }
}
