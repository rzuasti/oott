CREATE TABLE device_events(
    id INTEGER PRIMARY KEY,
    mac_address TEXT NOT NULL,
    created_on TEXT NOT NULL,
    event_type TEXT NOT NULL,
    ipv4_address TEXT NOT NULL,
    vendor TEXT NOT NULL
);
