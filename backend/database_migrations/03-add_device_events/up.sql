CREATE TABLE device_events(
    id INTEGER PRIMARY KEY,
    mac_address TEXT NOT NULL COLLATE NOCASE,
    created_on TEXT NOT NULL,
    event_type TEXT NOT NULL COLLATE NOCASE,
    ipv4_address TEXT NOT NULL,
    vendor TEXT NOT NULL COLLATE NOCASE
);
