CREATE TABLE devices(
    mac_address TEXT PRIMARY KEY,
    ip_address TEXT NOT NULL,
    vendor_name TEXT,
    last_seen TEXT NOT NULL
);
