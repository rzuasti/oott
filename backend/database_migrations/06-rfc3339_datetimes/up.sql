UPDATE device_events SET created_on = REPLACE(created_on, ' ', 'T') WHERE created_on LIKE '____-__-__ %';
UPDATE devices SET last_seen = REPLACE(last_seen, ' ', 'T') WHERE last_seen LIKE '____-__-__ %';
UPDATE notifications SET created_on = REPLACE(created_on, ' ', 'T') WHERE created_on LIKE '____-__-__ %';
