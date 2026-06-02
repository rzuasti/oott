use config::{Config, ConfigError, File};
use duration_string::DurationString;
use once_cell::sync::OnceCell;
use serde::Deserialize;

// -----------------------------------------------------------
// Configuration structure

fn default_true() -> bool {
    true
}

#[derive(Debug, Deserialize, Clone)]
pub struct Database {
    pub path: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Networking {
    pub interface: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Log {
    pub level: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ArpScanner {
    #[serde(default = "default_true")]
    pub enabled: bool,
    pub wait_between_scans: DurationString,
    pub sender_timeout: DurationString,
    pub scan_duration: DurationString,
}

#[derive(Debug, Deserialize, Clone)]
pub struct MdnsScanner {
    #[serde(default = "default_true")]
    pub enabled: bool,
    pub probe_timeout: DurationString,
}

impl Default for MdnsScanner {
    fn default() -> Self {
        MdnsScanner {
            enabled: true,
            probe_timeout: DurationString::try_from("2s".to_string()).unwrap(),
        }
    }
}

#[derive(Debug, Deserialize, Clone)]
pub struct SsdpScanner {
    #[serde(default = "default_true")]
    pub enabled: bool,
    pub probe_timeout: DurationString,
}

impl Default for SsdpScanner {
    fn default() -> Self {
        SsdpScanner {
            enabled: true,
            probe_timeout: DurationString::try_from("2s".to_string()).unwrap(),
        }
    }
}

#[derive(Debug, Deserialize, Clone)]
pub struct DhcpScanner {
    #[serde(default = "default_true")]
    pub enabled: bool,
}

impl Default for DhcpScanner {
    fn default() -> Self {
        DhcpScanner { enabled: true }
    }
}

#[derive(Debug, Deserialize, Clone)]
pub struct SnmpScanner {
    #[serde(default = "default_true")]
    pub enabled: bool,
    /// SNMP agent to poll, as `host:port` (e.g. the gateway: `192.168.1.1:161`).
    pub target: String,
    /// SNMPv2c read-only community string.
    pub community: String,
    pub wait_between_scans: DurationString,
    pub timeout: DurationString,
}

impl Default for SnmpScanner {
    fn default() -> Self {
        // No universal target exists, so the SNMP scanner stays off until the user adds a
        // `[snmp_scanner]` section pointing at their gateway.
        SnmpScanner {
            enabled: false,
            target: String::new(),
            community: String::new(),
            wait_between_scans: DurationString::try_from("10m".to_string()).unwrap(),
            timeout: DurationString::try_from("5s".to_string()).unwrap(),
        }
    }
}

#[derive(Debug, Deserialize, Clone)]
pub struct Pushover {
    pub token: String,
    pub user_key: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Notifications {
    pub method: String,
    pub pushover: Pushover,
    pub notify_when_not_seen_for: DurationString,
}

#[derive(Debug, Deserialize, Clone)]
pub struct WebServer {
    pub ip_address: String,
    pub port: u16,
    pub api_key: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Retention {
    pub window: DurationString,
}

impl Default for Retention {
    fn default() -> Self {
        Retention {
            window: DurationString::try_from("365d".to_string()).unwrap(),
        }
    }
}

#[derive(Debug, Deserialize, Clone)]
pub struct Settings {
    pub database: Database,
    pub networking: Networking,
    pub log: Log,
    pub arp_scanner: ArpScanner,
    pub notifications: Notifications,
    pub web_server: WebServer,
    #[serde(default)]
    pub retention: Retention,
    #[serde(default)]
    pub mdns_scanner: MdnsScanner,
    #[serde(default)]
    pub ssdp_scanner: SsdpScanner,
    #[serde(default)]
    pub dhcp_scanner: DhcpScanner,
    #[serde(default)]
    pub snmp_scanner: SnmpScanner,
}
// End configuration structure
// -----------------------------------------------------------

impl Settings {
    pub fn new(config_path: String) -> Result<Self, ConfigError> {
        println!("Reading configuration from {}", config_path);

        let local_settings = Config::builder()
            .add_source(File::with_name(config_path.as_str()))
            .build()?;

        local_settings.try_deserialize()
    }
}

pub const DEFAULT_CONFIG_FILE_PATH: &str = "./oott.toml";
static SETTINGS: OnceCell<Settings> = OnceCell::new();

pub fn get_settings() -> &'static Settings {
    match SETTINGS.get() {
        Some(value) => value,
        None => {
            println!(
                "Configuration was not initialized, reading from default path ({})",
                DEFAULT_CONFIG_FILE_PATH
            );
            let settings = Settings::new(DEFAULT_CONFIG_FILE_PATH.to_string()).unwrap();
            let _ = SETTINGS.set(settings);
            SETTINGS.get().unwrap()
        }
    }
}

pub fn init(config_path: String) {
    let _ = SETTINGS.set(Settings::new(config_path).unwrap());
}

#[cfg(test)]
mod tests {
    use super::*;
    use config::{Config, FileFormat};

    fn parse(toml: &str) -> Settings {
        Config::builder()
            .add_source(config::File::from_str(toml, FileFormat::Toml))
            .build()
            .unwrap()
            .try_deserialize()
            .unwrap()
    }

    const BASE_CONFIG: &str = r#"
        [database]
        path = "./oott.db"
        [networking]
        [log]
        level = "info"
        [arp_scanner]
        wait_between_scans = "1m"
        sender_timeout = "1m"
        scan_duration = "2m"
        [notifications]
        method = "none"
        notify_when_not_seen_for = "1w"
        [notifications.pushover]
        token = ""
        user_key = ""
        [web_server]
        ip_address = "0.0.0.0"
        port = 3000
        api_key = "test"
    "#;

    #[test]
    fn scanners_enabled_by_default_when_flag_omitted() {
        let settings = parse(BASE_CONFIG);
        assert!(settings.arp_scanner.enabled);
        assert!(settings.mdns_scanner.enabled);
        assert!(settings.ssdp_scanner.enabled);
        assert!(settings.dhcp_scanner.enabled);
        // The SNMP scanner is opt-in: with no `[snmp_scanner]` section it stays disabled.
        assert!(!settings.snmp_scanner.enabled);
    }

    #[test]
    fn snmp_scanner_section_is_parsed() {
        let toml = format!(
            "{BASE_CONFIG}
            [snmp_scanner]
            target = \"192.168.1.1:161\"
            community = \"public\"
            wait_between_scans = \"5m\"
            timeout = \"3s\"
            "
        );
        let settings = parse(&toml);
        // `enabled` defaults to true once the section is present.
        assert!(settings.snmp_scanner.enabled);
        assert_eq!(settings.snmp_scanner.target, "192.168.1.1:161");
        assert_eq!(settings.snmp_scanner.community, "public");
    }

    #[test]
    fn scanners_can_be_disabled() {
        let toml = format!(
            "{BASE_CONFIG}
            [mdns_scanner]
            enabled = false
            probe_timeout = \"2s\"
            [ssdp_scanner]
            enabled = false
            probe_timeout = \"2s\"
            [dhcp_scanner]
            enabled = false
            "
        );
        // Disable the ARP scanner via its existing section too.
        let toml = toml.replace(
            "wait_between_scans = \"1m\"",
            "enabled = false\n        wait_between_scans = \"1m\"",
        );
        let settings = parse(&toml);
        assert!(!settings.arp_scanner.enabled);
        assert!(!settings.mdns_scanner.enabled);
        assert!(!settings.ssdp_scanner.enabled);
        assert!(!settings.dhcp_scanner.enabled);
    }
}
