-- Demo data for the Fly.io App Store review test server.
--
-- A cloud host has no LAN to scan, so this script populates the database with a
-- realistic spread of devices, notifications and device events covering every
-- state a reviewer should be able to exercise: registered vs unknown devices,
-- devices seen just now / today / this week / long offline, every device-event
-- type (NewDevice, DeviceSeen, DeviceChanged, DeviceBackOnline) and every
-- scanner source (ARP, mDNS, SSDP, DHCP, SNMP), plus read/unread notifications
-- of each type.
--
-- It is idempotent: it prunes the demo tables first, then reinserts. It is
-- applied on every deployment by the Fly entrypoint (see flake.nix flyImage).
-- push_tokens is intentionally left untouched so a reviewer's app stays
-- registered for push across a reseed.
--
-- Timestamps are written relative to "now" (RFC3339, +00:00 offset) so the data
-- always looks fresh regardless of when the server is deployed. The offset
-- format matches what the backend itself writes, keeping the string-based date
-- comparisons in the device summary correct.

PRAGMA busy_timeout = 10000;

BEGIN;

DELETE FROM device_events;
DELETE FROM notifications;
DELETE FROM devices;

-- ---------------------------------------------------------------------------
-- Devices
-- (mac_address, ipv4_address, vendor, last_seen, is_registered, owner,
--  device_type, name)
-- ---------------------------------------------------------------------------
INSERT INTO devices (mac_address, ipv4_address, vendor, last_seen, is_registered, owner, device_type, name) VALUES
  -- Registered, seen moments ago — the "everything is fine" case.
  ('AA:BB:CC:00:00:01', '192.168.1.10', 'Samsung Electronics',      strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-5 minutes'),  1, 'Alice',   'TV',       'living-room-tv'),
  ('AA:BB:CC:00:00:02', '192.168.1.11', 'Apple, Inc.',              strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-45 minutes'), 1, 'Bob',     'Laptop',   'bobs-macbook'),
  -- Unknown device that just appeared — the core "new device" alert scenario.
  ('AA:BB:CC:00:00:03', '192.168.1.50', 'Espressif Inc.',           strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-2 minutes'),  0, '',        '',         NULL),
  -- Unknown phone, still seen today.
  ('AA:BB:CC:00:00:04', '192.168.1.51', 'Google, Inc.',             strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-6 hours'),    0, '',        'Phone',    NULL),
  -- Registered but long offline — exercises the "not seen for a while" state.
  ('AA:BB:CC:00:00:05', '192.168.1.20', 'HP Inc.',                  strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-10 days'),    1, 'Office',  'Printer',  'hp-office-printer'),
  -- Registered, seen this week but not today.
  ('AA:BB:CC:00:00:06', '192.168.1.21', 'Google, Inc.',             strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-3 days'),     1, 'Home',    'IoT',      'nest-thermostat'),
  -- Unknown tablet, seen this week but not today.
  ('AA:BB:CC:00:00:07', '192.168.1.52', 'Amazon Technologies Inc.', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-4 days'),     0, '',        'Tablet',   NULL),
  -- Router discovered via SNMP.
  ('AA:BB:CC:00:00:08', '192.168.1.1',  'Ubiquiti Inc.',            strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-10 minutes'), 1, 'Network', 'Router',   'gateway'),
  -- Host discovered via mDNS, so it carries a hostname.
  ('AA:BB:CC:00:00:09', '192.168.1.30', 'Raspberry Pi Foundation',  strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-30 minutes'), 1, 'Dev',     'Computer', 'raspberrypi'),
  -- Unknown camera, seen today.
  ('AA:BB:CC:00:00:0A', '192.168.1.53', 'Hangzhou Hikvision',       strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-20 hours'),   0, '',        'Camera',   NULL);

-- ---------------------------------------------------------------------------
-- Notifications
-- (created_on, notification_type, title, body, is_new, mac_address)
-- notification_type: NewDeviceFound | DeviceOnlineAfterTime | DeviceChanged | Other
-- is_new: 1 = unread/new, 0 = already read
-- ---------------------------------------------------------------------------
INSERT INTO notifications (created_on, notification_type, title, body, is_new, mac_address) VALUES
  (strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-2 minutes'),  'NewDeviceFound',        'New device found',        'An unknown device (Espressif Inc.) joined the network at 192.168.1.50.', 1, 'AA:BB:CC:00:00:03'),
  (strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-20 hours'),   'NewDeviceFound',        'New device found',        'An unknown device (Hangzhou Hikvision) joined the network at 192.168.1.53.', 1, 'AA:BB:CC:00:00:0A'),
  (strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-6 hours'),    'NewDeviceFound',        'New device found',        'An unknown device (Google, Inc.) joined the network at 192.168.1.51.', 0, 'AA:BB:CC:00:00:04'),
  (strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-10 minutes'), 'DeviceOnlineAfterTime', 'Device back online',      'gateway (192.168.1.1) is back online after 2 days offline.', 1, 'AA:BB:CC:00:00:08'),
  (strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-3 days'),     'DeviceOnlineAfterTime', 'Device back online',      'nest-thermostat (192.168.1.21) is back online after a week offline.', 0, 'AA:BB:CC:00:00:06'),
  (strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-45 minutes'), 'DeviceChanged',         'Device changed',          'bobs-macbook changed IP address from 192.168.1.99 to 192.168.1.11.', 0, 'AA:BB:CC:00:00:02'),
  (strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-3 days'),     'DeviceChanged',         'Device changed',          'nest-thermostat changed IP address from 192.168.1.45 to 192.168.1.21.', 1, 'AA:BB:CC:00:00:06'),
  (strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-5 days'),     'Other',                 'Monitoring started',      'OOTT started monitoring your network.', 0, NULL);

-- ---------------------------------------------------------------------------
-- Device events (per-device timelines shown on the device detail screen)
-- (mac_address, created_on, event_type, ipv4_address, vendor, scanner)
-- event_type: NewDevice | DeviceSeen | DeviceChanged | DeviceBackOnline
-- scanner: ARP | mDNS | SSDP | DHCP | SNMP
-- ---------------------------------------------------------------------------
INSERT INTO device_events (mac_address, created_on, event_type, ipv4_address, vendor, scanner) VALUES
  -- New unknown device: discovered then seen again.
  ('AA:BB:CC:00:00:03', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-2 minutes'),  'NewDevice',        '192.168.1.50', 'Espressif Inc.',           'ARP'),
  ('AA:BB:CC:00:00:03', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-1 minutes'),  'DeviceSeen',       '192.168.1.50', 'Espressif Inc.',           'ARP'),

  -- Living room TV: long history across ARP and mDNS.
  ('AA:BB:CC:00:00:01', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-30 days'),    'NewDevice',        '192.168.1.10', 'Samsung Electronics',      'ARP'),
  ('AA:BB:CC:00:00:01', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-7 days'),     'DeviceSeen',       '192.168.1.10', 'Samsung Electronics',      'ARP'),
  ('AA:BB:CC:00:00:01', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-1 days'),     'DeviceSeen',       '192.168.1.10', 'Samsung Electronics',      'mDNS'),
  ('AA:BB:CC:00:00:01', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-5 minutes'),  'DeviceSeen',       '192.168.1.10', 'Samsung Electronics',      'ARP'),

  -- MacBook: changed its IP address.
  ('AA:BB:CC:00:00:02', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-60 days'),    'NewDevice',        '192.168.1.99', 'Apple, Inc.',              'ARP'),
  ('AA:BB:CC:00:00:02', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-45 minutes'), 'DeviceChanged',    '192.168.1.11', 'Apple, Inc.',              'ARP'),
  ('AA:BB:CC:00:00:02', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-44 minutes'), 'DeviceSeen',       '192.168.1.11', 'Apple, Inc.',              'ARP'),

  -- Unknown phone: seen via ARP and DHCP.
  ('AA:BB:CC:00:00:04', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-6 hours'),    'NewDevice',        '192.168.1.51', 'Google, Inc.',             'ARP'),
  ('AA:BB:CC:00:00:04', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-6 hours'),    'DeviceSeen',       '192.168.1.51', 'Google, Inc.',             'DHCP'),

  -- Printer: registered but long offline (last event 11 days ago).
  ('AA:BB:CC:00:00:05', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-90 days'),    'NewDevice',        '192.168.1.20', 'HP Inc.',                  'ARP'),
  ('AA:BB:CC:00:00:05', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-11 days'),    'DeviceSeen',       '192.168.1.20', 'HP Inc.',                  'ARP'),

  -- Thermostat: came back online and changed IP, seen via DHCP/SSDP/ARP.
  ('AA:BB:CC:00:00:06', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-40 days'),    'NewDevice',        '192.168.1.45', 'Google, Inc.',             'DHCP'),
  ('AA:BB:CC:00:00:06', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-3 days'),     'DeviceBackOnline', '192.168.1.45', 'Google, Inc.',             'ARP'),
  ('AA:BB:CC:00:00:06', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-3 days'),     'DeviceChanged',    '192.168.1.21', 'Google, Inc.',             'ARP'),
  ('AA:BB:CC:00:00:06', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-3 days'),     'DeviceSeen',       '192.168.1.21', 'Google, Inc.',             'SSDP'),

  -- Unknown tablet, seen this week.
  ('AA:BB:CC:00:00:07', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-4 days'),     'NewDevice',        '192.168.1.52', 'Amazon Technologies Inc.', 'ARP'),
  ('AA:BB:CC:00:00:07', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-4 days'),     'DeviceSeen',       '192.168.1.52', 'Amazon Technologies Inc.', 'ARP'),

  -- Gateway: discovered and polled via SNMP, recently back online.
  ('AA:BB:CC:00:00:08', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-200 days'),   'NewDevice',        '192.168.1.1',  'Ubiquiti Inc.',            'SNMP'),
  ('AA:BB:CC:00:00:08', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-10 minutes'), 'DeviceBackOnline', '192.168.1.1',  'Ubiquiti Inc.',            'SNMP'),
  ('AA:BB:CC:00:00:08', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-9 minutes'),  'DeviceSeen',       '192.168.1.1',  'Ubiquiti Inc.',            'SNMP'),

  -- Raspberry Pi: discovered and seen via mDNS.
  ('AA:BB:CC:00:00:09', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-15 days'),    'NewDevice',        '192.168.1.30', 'Raspberry Pi Foundation',  'mDNS'),
  ('AA:BB:CC:00:00:09', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-30 minutes'), 'DeviceSeen',       '192.168.1.30', 'Raspberry Pi Foundation',  'mDNS'),

  -- Unknown camera: discovered via ARP, seen via SSDP.
  ('AA:BB:CC:00:00:0A', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-20 hours'),   'NewDevice',        '192.168.1.53', 'Hangzhou Hikvision',       'ARP'),
  ('AA:BB:CC:00:00:0A', strftime('%Y-%m-%dT%H:%M:%S+00:00', 'now', '-20 hours'),   'DeviceSeen',       '192.168.1.53', 'Hangzhou Hikvision',       'SSDP');

COMMIT;
