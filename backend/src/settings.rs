use config::{Config, ConfigError, File};
use duration_string::DurationString;
use once_cell::sync::OnceCell;
use serde::Deserialize;

// -----------------------------------------------------------
// Configuration structure

fn default_true() -> bool {
    true
}

fn default_log_level() -> String {
    "warn".to_string()
}

fn default_ip_address() -> String {
    "0.0.0.0".to_string()
}

fn default_port() -> u16 {
    3000
}

fn default_notify_when_not_seen_for() -> DurationString {
    DurationString::try_from("1w".to_string()).unwrap()
}

fn default_arp_wait_between_scans() -> DurationString {
    DurationString::try_from("30m".to_string()).unwrap()
}

fn default_arp_sender_timeout() -> DurationString {
    DurationString::try_from("1m".to_string()).unwrap()
}

fn default_arp_scan_duration() -> DurationString {
    DurationString::try_from("10m".to_string()).unwrap()
}

fn default_probe_timeout() -> DurationString {
    DurationString::try_from("2s".to_string()).unwrap()
}

fn default_snmp_wait_between_scans() -> DurationString {
    DurationString::try_from("10m".to_string()).unwrap()
}

fn default_snmp_timeout() -> DurationString {
    DurationString::try_from("5s".to_string()).unwrap()
}

#[derive(Debug, Deserialize, Clone)]
pub struct Database {
    pub path: String,
}

#[derive(Debug, Deserialize, Clone, Default)]
pub struct Networking {
    pub interface: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Log {
    #[serde(default = "default_log_level")]
    pub level: String,
}

impl Default for Log {
    fn default() -> Self {
        Log {
            level: default_log_level(),
        }
    }
}

#[derive(Debug, Deserialize, Clone)]
pub struct ArpScanner {
    #[serde(default = "default_true")]
    pub enabled: bool,
    #[serde(default = "default_arp_wait_between_scans")]
    pub wait_between_scans: DurationString,
    #[serde(default = "default_arp_sender_timeout")]
    pub sender_timeout: DurationString,
    #[serde(default = "default_arp_scan_duration")]
    pub scan_duration: DurationString,
}

impl Default for ArpScanner {
    fn default() -> Self {
        ArpScanner {
            enabled: true,
            wait_between_scans: default_arp_wait_between_scans(),
            sender_timeout: default_arp_sender_timeout(),
            scan_duration: default_arp_scan_duration(),
        }
    }
}

#[derive(Debug, Deserialize, Clone)]
pub struct MdnsScanner {
    #[serde(default = "default_true")]
    pub enabled: bool,
    #[serde(default = "default_probe_timeout")]
    pub probe_timeout: DurationString,
}

impl Default for MdnsScanner {
    fn default() -> Self {
        MdnsScanner {
            enabled: true,
            probe_timeout: default_probe_timeout(),
        }
    }
}

#[derive(Debug, Deserialize, Clone)]
pub struct SsdpScanner {
    #[serde(default = "default_true")]
    pub enabled: bool,
    #[serde(default = "default_probe_timeout")]
    pub probe_timeout: DurationString,
}

impl Default for SsdpScanner {
    fn default() -> Self {
        SsdpScanner {
            enabled: true,
            probe_timeout: default_probe_timeout(),
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
    #[serde(default = "default_snmp_wait_between_scans")]
    pub wait_between_scans: DurationString,
    #[serde(default = "default_snmp_timeout")]
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
            wait_between_scans: default_snmp_wait_between_scans(),
            timeout: default_snmp_timeout(),
        }
    }
}

#[derive(Debug, Deserialize, Clone)]
pub struct Pushover {
    pub token: String,
    pub user_key: String,
}

fn default_relay_url() -> String {
    // The send endpoint of the project-operated push relay. Self-hosters need paste nothing to
    // enable push: with `method = "push"` and no `[notifications.push]` section, this default is
    // used. The concrete URL is filled in once the relay Cloud Function is deployed (see
    // push_relay/README.md); a self-hoster can always override it via `relay_url`.
    "https://oott-push-relay.example.com/v1/push".to_string()
}

#[derive(Debug, Deserialize, Clone)]
pub struct Push {
    #[serde(default = "default_relay_url")]
    pub relay_url: String,
}

impl Default for Push {
    fn default() -> Self {
        Push {
            relay_url: default_relay_url(),
        }
    }
}

#[derive(Debug, Deserialize, Clone)]
pub struct Notifications {
    pub method: String,
    // Only required when `method` is "pushover"; other methods leave this section out.
    pub pushover: Option<Pushover>,
    // Optional when `method` is "push": with no section the default relay URL is used.
    pub push: Option<Push>,
    #[serde(default = "default_notify_when_not_seen_for")]
    pub notify_when_not_seen_for: DurationString,
}

#[derive(Debug, Deserialize, Clone)]
pub struct WebServer {
    #[serde(default = "default_ip_address")]
    pub ip_address: String,
    #[serde(default = "default_port")]
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
pub struct DeviceEvents {
    pub deduplication_window: DurationString,
}

impl Default for DeviceEvents {
    fn default() -> Self {
        DeviceEvents {
            deduplication_window: DurationString::try_from("1m".to_string()).unwrap(),
        }
    }
}

#[derive(Debug, Deserialize, Clone)]
pub struct Settings {
    pub database: Database,
    #[serde(default)]
    pub networking: Networking,
    #[serde(default)]
    pub log: Log,
    #[serde(default)]
    pub arp_scanner: ArpScanner,
    pub notifications: Notifications,
    pub web_server: WebServer,
    #[serde(default)]
    pub retention: Retention,
    #[serde(default)]
    pub device_events: DeviceEvents,
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

        let settings: Settings = local_settings.try_deserialize()?;
        settings.validate()?;
        Ok(settings)
    }

    // Cross-field checks that serde can't express on its own. Run once at load time so a
    // misconfiguration fails fast at startup rather than on every notification attempt.
    fn validate(&self) -> Result<(), ConfigError> {
        if self.notifications.method == "pushover" && self.notifications.pushover.is_none() {
            return Err(ConfigError::Message(
                "notifications.method is \"pushover\" but the [notifications.pushover] section is \
                 missing; add it with your token and user_key, or change notifications.method."
                    .to_string(),
            ));
        }
        Ok(())
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
    fn snmp_scanner_durations_default_when_omitted() {
        // The section is present (with only the required target/community), so the
        // duration fields must fall back to their defaults rather than failing.
        let toml = format!(
            "{BASE_CONFIG}
            [snmp_scanner]
            target = \"192.168.1.1:161\"
            community = \"public\"
            "
        );
        let settings = parse(&toml);
        assert!(settings.snmp_scanner.enabled);
        assert_eq!(
            std::time::Duration::from(settings.snmp_scanner.wait_between_scans),
            std::time::Duration::from_secs(10 * 60)
        );
        assert_eq!(
            std::time::Duration::from(settings.snmp_scanner.timeout),
            std::time::Duration::from_secs(5)
        );
    }

    #[test]
    fn scanner_durations_default_when_section_present_but_fields_omitted() {
        // Each scanner section is present (e.g. to toggle `enabled`) but the duration
        // fields are omitted; they must fall back to their defaults, not fail parsing.
        let toml = format!(
            "{BASE_CONFIG}
            [mdns_scanner]
            enabled = true
            [ssdp_scanner]
            enabled = true
            "
        );
        // Keep the `[arp_scanner]` section but drop its duration fields.
        let toml = toml.replace(
            "[arp_scanner]\n        wait_between_scans = \"1m\"\n        sender_timeout = \"1m\"\n        scan_duration = \"2m\"",
            "[arp_scanner]",
        );
        let settings = parse(&toml);
        assert_eq!(
            std::time::Duration::from(settings.arp_scanner.wait_between_scans),
            std::time::Duration::from_secs(30 * 60)
        );
        assert_eq!(
            std::time::Duration::from(settings.arp_scanner.sender_timeout),
            std::time::Duration::from_secs(60)
        );
        assert_eq!(
            std::time::Duration::from(settings.arp_scanner.scan_duration),
            std::time::Duration::from_secs(10 * 60)
        );
        assert_eq!(
            std::time::Duration::from(settings.mdns_scanner.probe_timeout),
            std::time::Duration::from_secs(2)
        );
        assert_eq!(
            std::time::Duration::from(settings.ssdp_scanner.probe_timeout),
            std::time::Duration::from_secs(2)
        );
    }

    #[test]
    fn arp_scanner_uses_code_defaults_when_section_omitted() {
        // A config without an `[arp_scanner]` section falls back to the code defaults.
        const NO_ARP_CONFIG: &str = r#"
            [database]
            path = "./oott.db"
            [networking]
            [log]
            level = "info"
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
        let settings = parse(NO_ARP_CONFIG);
        assert!(settings.arp_scanner.enabled);
        assert_eq!(
            std::time::Duration::from(settings.arp_scanner.wait_between_scans),
            std::time::Duration::from_secs(30 * 60)
        );
        assert_eq!(
            std::time::Duration::from(settings.arp_scanner.sender_timeout),
            std::time::Duration::from_secs(60)
        );
        assert_eq!(
            std::time::Duration::from(settings.arp_scanner.scan_duration),
            std::time::Duration::from_secs(10 * 60)
        );
    }

    #[test]
    fn log_level_defaults_to_warn_when_section_omitted() {
        // A config without a `[log]` section falls back to the code default.
        const NO_LOG_CONFIG: &str = r#"
            [database]
            path = "./oott.db"
            [networking]
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
        let settings = parse(NO_LOG_CONFIG);
        assert_eq!(settings.log.level, "warn");
    }

    #[test]
    fn log_level_defaults_to_warn_when_field_omitted() {
        // Keep the `[log]` section but drop the `level` field; it should fall back to the default.
        let toml = BASE_CONFIG.replace("[log]\n        level = \"info\"", "[log]");
        let settings = parse(&toml);
        assert_eq!(settings.log.level, "warn");
    }

    #[test]
    fn web_server_address_and_port_default_when_fields_omitted() {
        // Keep the `[web_server]` section (api_key is required) but drop ip_address and port.
        const NO_ADDR_CONFIG: &str = r#"
            [database]
            path = "./oott.db"
            [networking]
            [log]
            level = "info"
            [notifications]
            method = "none"
            notify_when_not_seen_for = "1w"
            [notifications.pushover]
            token = ""
            user_key = ""
            [web_server]
            api_key = "test"
        "#;
        let settings = parse(NO_ADDR_CONFIG);
        assert_eq!(settings.web_server.ip_address, "0.0.0.0");
        assert_eq!(settings.web_server.port, 3000);
    }

    #[test]
    fn device_events_dedup_window_defaults_when_section_omitted() {
        let settings = parse(BASE_CONFIG);
        assert_eq!(
            std::time::Duration::from(settings.device_events.deduplication_window),
            std::time::Duration::from_secs(60)
        );
    }

    #[test]
    fn device_events_dedup_window_is_parsed() {
        let toml = format!(
            "{BASE_CONFIG}
            [device_events]
            deduplication_window = \"5m\"
            "
        );
        let settings = parse(&toml);
        assert_eq!(
            std::time::Duration::from(settings.device_events.deduplication_window),
            std::time::Duration::from_secs(5 * 60)
        );
    }

    #[test]
    fn notify_when_not_seen_for_defaults_when_field_omitted() {
        // Drop the `notify_when_not_seen_for` field; it should fall back to the "1w" default.
        let toml = BASE_CONFIG.replace("\n        notify_when_not_seen_for = \"1w\"", "");
        let settings = parse(&toml);
        assert_eq!(
            std::time::Duration::from(settings.notifications.notify_when_not_seen_for),
            std::time::Duration::from_secs(7 * 24 * 60 * 60)
        );
    }

    #[test]
    fn validate_rejects_pushover_method_without_section() {
        // method = "pushover" but no [notifications.pushover] section: must fail at load time.
        const PUSHOVER_NO_SECTION: &str = r#"
            [database]
            path = "./oott.db"
            [networking]
            [log]
            level = "info"
            [notifications]
            method = "pushover"
            [web_server]
            api_key = "test"
        "#;
        let settings = parse(PUSHOVER_NO_SECTION);
        assert!(settings.validate().is_err());
    }

    #[test]
    fn validate_accepts_non_pushover_method_without_section() {
        let settings = parse(NO_PUSHOVER_CONFIG);
        assert!(settings.validate().is_ok());
    }

    #[test]
    fn validate_accepts_pushover_method_with_section() {
        let settings = parse(BASE_CONFIG);
        assert!(settings.validate().is_ok());
    }

    #[test]
    fn push_method_without_section_uses_default_relay_url() {
        // method = "push" with no [notifications.push] section: valid, and the default relay URL is
        // used so self-hosters need paste nothing to enable push.
        const PUSH_NO_SECTION: &str = r#"
            [database]
            path = "./oott.db"
            [networking]
            [log]
            level = "info"
            [notifications]
            method = "push"
            [web_server]
            api_key = "test"
        "#;
        let settings = parse(PUSH_NO_SECTION);
        assert_eq!(settings.notifications.method, "push");
        assert!(settings.notifications.push.is_none());
        assert!(settings.validate().is_ok());
        // The sender falls back to the default when the section is absent.
        assert_eq!(settings.notifications.push.unwrap_or_default().relay_url, default_relay_url());
    }

    #[test]
    fn push_section_relay_url_is_parsed_when_present() {
        let toml = format!(
            "{BASE_CONFIG}
            [notifications.push]
            relay_url = \"https://relay.example.test/v1/push\"
            "
        );
        let settings = parse(&toml);
        let push = settings
            .notifications
            .push
            .expect("push section should be parsed when present");
        assert_eq!(push.relay_url, "https://relay.example.test/v1/push");
    }

    #[test]
    fn push_relay_url_defaults_when_field_omitted() {
        // The [notifications.push] section is present but empty; relay_url must fall back to the
        // default rather than fail parsing.
        let toml = format!(
            "{BASE_CONFIG}
            [notifications.push]
            "
        );
        let settings = parse(&toml);
        let push = settings.notifications.push.expect("push section should parse when present");
        assert_eq!(push.relay_url, default_relay_url());
    }

    const NO_PUSHOVER_CONFIG: &str = r#"
        [database]
        path = "./oott.db"
        [networking]
        [log]
        level = "info"
        [notifications]
        method = "none"
        [web_server]
        api_key = "test"
    "#;

    #[test]
    fn pushover_section_is_optional_for_non_pushover_methods() {
        // With a non-pushover method, the `[notifications.pushover]` section may be omitted
        // entirely; it should deserialize to `None` rather than fail parsing.
        let settings = parse(NO_PUSHOVER_CONFIG);
        assert_eq!(settings.notifications.method, "none");
        assert!(settings.notifications.pushover.is_none());
    }

    #[test]
    fn pushover_section_is_parsed_when_present() {
        let settings = parse(BASE_CONFIG);
        let pushover = settings
            .notifications
            .pushover
            .expect("pushover section should be parsed when present");
        assert_eq!(pushover.token, "");
        assert_eq!(pushover.user_key, "");
    }

    #[test]
    fn networking_section_is_optional() {
        // The `[networking]` section has no mandatory fields, so omitting it entirely
        // should fall back to the code default (interface auto-detected at runtime).
        const NO_NETWORKING_CONFIG: &str = r#"
            [database]
            path = "./oott.db"
            [log]
            level = "info"
            [notifications]
            method = "none"
            [notifications.pushover]
            token = ""
            user_key = ""
            [web_server]
            api_key = "test"
        "#;
        let settings = parse(NO_NETWORKING_CONFIG);
        assert!(settings.networking.interface.is_none());
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
