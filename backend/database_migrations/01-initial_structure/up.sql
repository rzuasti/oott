CREATE TABLE devices(
    mac_address TEXT PRIMARY KEY,
    ipv4_address TEXT NOT NULL,
    vendor TEXT,
    last_seen TEXT NOT NULL,
    is_registered INTEGER NOT NULL,
    owner TEXT,
    device_type TEXT
);

CREATE TABLE notifications(
    id INTEGER PRIMARY KEY,
    created_on TEXT NOT NULL,
    notification_type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT,
    is_new INTEGER NOT NULL
);
