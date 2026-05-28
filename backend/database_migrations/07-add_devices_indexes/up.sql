CREATE INDEX idx_devices_is_registered ON devices (is_registered);
CREATE INDEX idx_devices_last_seen_is_registered ON devices (last_seen, is_registered);
