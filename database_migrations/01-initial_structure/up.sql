CREATE TABLE devices(
    mac_address TEXT PRIMARY KEY,
    ipv4_address TEXT NOT NULL,
    vendor TEXT,
    last_seen TEXT NOT NULL
);
