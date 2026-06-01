CREATE TABLE devices(
    mac_address TEXT PRIMARY KEY COLLATE NOCASE,
    ipv4_address TEXT NOT NULL,
    vendor TEXT COLLATE NOCASE,
    last_seen TEXT NOT NULL,
    is_registered INTEGER NOT NULL,
    owner TEXT COLLATE NOCASE,
    device_type TEXT COLLATE NOCASE
);

CREATE TABLE notifications(
    id INTEGER PRIMARY KEY,
    created_on TEXT NOT NULL,
    notification_type TEXT NOT NULL COLLATE NOCASE,
    title TEXT NOT NULL COLLATE NOCASE,
    body TEXT COLLATE NOCASE,
    is_new INTEGER NOT NULL
);
