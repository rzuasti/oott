mod packet_send_receive;

use crate::{config, device_finders::Device};
use log::{debug, info, warn};
use packet_send_receive::{listen_for_packets, send_packet};
use pnet::{
    datalink::{self, Channel, NetworkInterface},
    ipnetwork::IpNetwork,
};
use tokio::time::{Duration, timeout};

const DEFAULT_SENDER_TIMEOUT: u64 = 60; // 1 minute to send all packets - good for a class C network
const DEFAULT_SCAN_DURATION: u64 = 300; // 5 minutes to wait per round to receive responses

pub async fn find(interface: &str) -> Vec<Device> {
    debug!("Looking up devices via ARP using interface {}", interface);

    // Get the network device to use
    let network_interface: NetworkInterface = datalink::interfaces()
        .iter()
        .filter(|el| el.is_up())
        .filter(|el| el.name == interface)
        .next()
        .expect("Selected interface not found")
        .clone();

    // Get the IPV4 network to use
    let ipv4_net = network_interface
        .ips
        .iter()
        .filter_map(|el| match el {
            IpNetwork::V4(v4) => Some(*v4),
            _ => None,
        })
        .next()
        .expect("No local ip address found");

    // Get the local MAC address
    let mac = match network_interface.mac {
        Some(mac) => mac,
        None => {
            panic!("No local MAC address found");
        }
    };

    info!("Local MAC: {}", mac);
    info!("Local IP: {}", ipv4_net);

    // Data channel
    debug!("Creating data channel");
    let tunnel = datalink::channel(&network_interface, datalink::Config::default())
        .expect("Failed to create datalink channel");
    let (sender, receiver) = match tunnel {
        Channel::Ethernet(tx, rx) => (tx, rx),
        _ => panic!("Unsupported data channel type"),
    };

    let send_interface = network_interface.clone();

    // Get timeouts
    let sender_timeout =
        config::parse_env("OOTT_ARP_SENDER_TIMEOUT").unwrap_or(DEFAULT_SENDER_TIMEOUT);
    info!("Sender timeout set to {} seconds", sender_timeout);
    let scan_duration =
        config::parse_env("OOTT_ARP_SCAN_DURATION").unwrap_or(DEFAULT_SCAN_DURATION);
    let receiver_timeout = scan_duration * 2;
    info!("Scan duration set to {} seconds", scan_duration);
    info!("Receiver timeout set to {} seconds", receiver_timeout);

    if sender_timeout >= scan_duration {
        panic!("OOTT_ARP_SENDER_TIMEOUT needs to be smaller than OOTT_ARP_SCAN_DURATION");
    }

    let result = tokio::join!(
        timeout(
            Duration::from_secs(sender_timeout),
            send_packet(sender, send_interface, ipv4_net, mac),
        ),
        timeout(
            Duration::from_secs(receiver_timeout),
            listen_for_packets(receiver, ipv4_net, scan_duration),
        )
    );

    match result {
        (Ok(_), Ok(_)) => info!("ARP sender and receiver done"),
        (Err(_), _) => warn!("ARP sender timed out"),
        (_, Err(_)) => info!("ARP receiver timed out"),
    };

    result.1.unwrap_or(Vec::new())
}
