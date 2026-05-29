mod packet_send_receive;

use crate::device_finders::error::{
    DataChannelError, InvalidDeviceError, NoIPAddressError, NoMACAddressError,
};
use crate::model::devices::Device;
use crate::settings::get_settings;
use duration_string::DurationString;
use log::{debug, error, info, warn};
use packet_send_receive::{listen_for_packets, send_packet};
use pnet::{
    datalink::{self, Channel, NetworkInterface},
    ipnetwork::IpNetwork,
};
use tokio::time::{Duration, timeout};

fn select_interface<'a>(
    interfaces: &'a [NetworkInterface],
    configured: &Option<String>,
) -> Option<&'a NetworkInterface> {
    match configured {
        Some(name) => interfaces
            .iter()
            .filter(|el| el.is_up())
            .find(|el| &el.name == name),
        None => interfaces
            .iter()
            .find(|el| el.is_up() && !el.is_loopback() && el.ips.iter().any(|ip| ip.is_ipv4())),
    }
}

pub async fn find(interface: Option<String>) -> Result<Vec<Device>, Box<dyn std::error::Error>> {
    debug!("Looking up devices via ARP, configured interface: {:?}", interface);

    // Get the network device to use
    let all_interfaces = datalink::interfaces();
    let network_interface: NetworkInterface = match select_interface(&all_interfaces, &interface) {
        Some(value) => {
            info!("Using network interface: {}", value.name);
            value.clone()
        }
        None => {
            match &interface {
                Some(name) => error!("Interface ({name}) not found or not active."),
                None => error!("No suitable non-loopback interface with an IPv4 address found."),
            }
            return Err(InvalidDeviceError.into());
        }
    };

    // Get the IPV4 network to use
    let ipv4_net = match network_interface
        .ips
        .iter()
        .filter_map(|el| match el {
            IpNetwork::V4(v4) => Some(*v4),
            _ => None,
        })
        .next()
    {
        Some(value) => value,
        None => {
            error!("No IP address found for selected interface ({}).", network_interface.name);
            return Err(NoIPAddressError.into());
        }
    };

    // Get the local MAC address
    let mac = match network_interface.mac {
        Some(mac) => mac,
        None => {
            error!("Could not get MAC address for selected interface ({}).", network_interface.name);
            return Err(NoMACAddressError.into());
        }
    };

    info!("Local MAC: {}", mac);
    info!("Local IP: {}", ipv4_net);

    // Data channel
    debug!("Creating data channel");
    let tunnel: Channel = match datalink::channel(&network_interface, datalink::Config::default()) {
        Ok(value) => value,
        Err(error) => {
            error!("Could not create data channel: {error}");
            return Err(DataChannelError.into());
        }
    };

    let (sender, receiver) = match tunnel {
        Channel::Ethernet(tx, rx) => (tx, rx),
        _ => {
            error!("Unsupported data channel type");
            return Err(DataChannelError.into());
        }
    };

    let send_interface = network_interface.clone();

    // Get timeouts
    let sender_timeout: Duration = get_settings().arp_scanner.sender_timeout.into();
    info!(
        "Sender timeout set to {}",
        get_settings().arp_scanner.sender_timeout
    );
    let scan_duration: Duration = get_settings().arp_scanner.scan_duration.into();
    let receiver_timeout: Duration = scan_duration * 2;
    info!(
        "Scan duration set to {}",
        get_settings().arp_scanner.scan_duration
    );
    info!(
        "Receiver timeout set to {}",
        String::from(DurationString::from(receiver_timeout))
    );

    let result_send = timeout(
        sender_timeout,
        send_packet(sender, send_interface, ipv4_net, mac),
    )
    .await;

    match result_send {
        Ok(_) => info!("ARP sender done."),
        Err(_) => warn!("ARP sender timed out. Consider increasing its duration."),
    };

    let result_receive = timeout(
        receiver_timeout,
        listen_for_packets(receiver, ipv4_net, scan_duration),
    )
    .await;

    match result_receive {
        Ok(_) => info!("ARP receiver done."),
        Err(_) => info!("ARP receiver timed out."),
    };

    Ok(result_receive.unwrap_or(Vec::new()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use pnet::datalink::NetworkInterface;
    use pnet::ipnetwork::IpNetwork;

    // Raw Linux IFF flag values used by pnet's is_up() / is_loopback()
    const IFF_UP: u32 = 0x1;
    const IFF_LOOPBACK: u32 = 0x8;

    fn make_interface(name: &str, up: bool, loopback: bool, ipv4: bool) -> NetworkInterface {
        let mut flags: u32 = 0;
        if up {
            flags |= IFF_UP;
        }
        if loopback {
            flags |= IFF_LOOPBACK;
        }
        let ips = if ipv4 {
            vec![IpNetwork::V4("192.168.1.1/24".parse().unwrap())]
        } else {
            vec![]
        };
        NetworkInterface {
            name: name.to_string(),
            description: String::new(),
            index: 0,
            mac: None,
            ips,
            flags,
        }
    }

    #[test]
    fn test_select_configured_interface_found() {
        let ifaces = vec![
            make_interface("eth0", true, false, true),
            make_interface("wlan0", true, false, true),
        ];
        let result = select_interface(&ifaces, &Some("wlan0".to_string()));
        assert!(result.is_some());
        assert_eq!(result.unwrap().name, "wlan0");
    }

    #[test]
    fn test_select_configured_interface_not_found() {
        let ifaces = vec![make_interface("eth0", true, false, true)];
        let result = select_interface(&ifaces, &Some("missing0".to_string()));
        assert!(result.is_none());
    }

    #[test]
    fn test_select_configured_interface_down_not_found() {
        let ifaces = vec![make_interface("eth0", false, false, true)];
        let result = select_interface(&ifaces, &Some("eth0".to_string()));
        assert!(result.is_none());
    }

    #[test]
    fn test_auto_select_skips_loopback() {
        let ifaces = vec![
            make_interface("lo", true, true, true),
            make_interface("eth0", true, false, true),
        ];
        let result = select_interface(&ifaces, &None);
        assert!(result.is_some());
        assert_eq!(result.unwrap().name, "eth0");
    }

    #[test]
    fn test_auto_select_only_loopback_returns_none() {
        let ifaces = vec![make_interface("lo", true, true, true)];
        let result = select_interface(&ifaces, &None);
        assert!(result.is_none());
    }

    #[test]
    fn test_auto_select_skips_interface_without_ipv4() {
        let ifaces = vec![
            make_interface("eth0", true, false, false),
            make_interface("wlan0", true, false, true),
        ];
        let result = select_interface(&ifaces, &None);
        assert!(result.is_some());
        assert_eq!(result.unwrap().name, "wlan0");
    }
}
