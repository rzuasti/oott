INSERT INTO device_events (id, mac_address, created_on, event_type, ipv4_address, vendor, scanner)
    VALUES (1, 'aa:aa:aa:aa:aa:aa', '2026-01-01T11:11:11+00:00', 'NewDevice', '192.168.0.1', 'Vendor 1', 'ARP');
INSERT INTO device_events (id, mac_address, created_on, event_type, ipv4_address, vendor, scanner)
    VALUES (2, 'bb:bb:bb:bb:bb:bb', '2026-02-03T13:14:15+00:00', 'DeviceSeen', '192.168.0.2', 'Vendor 2', 'mDNS');
INSERT INTO device_events (id, mac_address, created_on, event_type, ipv4_address, vendor, scanner)
    VALUES (3, 'aa:aa:aa:aa:aa:aa', '2026-03-10T09:00:00+00:00', 'DeviceSeen', '192.168.0.1', 'Vendor 1', 'ARP');
