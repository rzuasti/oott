CREATE TABLE push_tokens(
    id INTEGER PRIMARY KEY,
    token TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL COLLATE NOCASE,
    created_on TEXT NOT NULL,
    last_seen TEXT NOT NULL
);
