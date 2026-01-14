mod packet_send_receive;

use crate::{config, device_finders::Device};
use log::{debug, info, warn};
use packet_send_receive::{listen_for_packets, send_packet};
use pnet::{
    datalink::{self, Channel, NetworkInterface},
    ipnetwork::IpNetwork,
};
use tokio::time::{Duration, Instant, timeout};

const DEFAULT_SENDER_TIMEOUT: u64 = 60; // 1 minute to send all packets - good for a class C network
const DEFAULT_RECEIVER_TIMEOUT: u64 = 300; // 5 minutes to wait per round to receive responses

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

    // Spawn sender thread
    info!("Starting ARP sender");
    let sender_start = Instant::now();
    let sender_timeout =
        config::parse_env("OOTT_ARP_SENDER_TIMEOUT").unwrap_or(DEFAULT_SENDER_TIMEOUT);
    debug!("Sender timeout set to {} seconds", sender_timeout);
    let sender_thread = timeout(
        Duration::from_secs(sender_timeout),
        send_packet(sender, send_interface, ipv4_net, mac),
    );

    // Spawn receiver thread
    info!("Starting ARP receiver");
    let receiver_start = Instant::now();
    let receiver_timeout =
        config::parse_env("OOTT_ARP_RECEIVER_TIMEOUT").unwrap_or(DEFAULT_RECEIVER_TIMEOUT);
    debug!("Receiver timeout set to {} seconds", receiver_timeout);
    let receiver_thread = timeout(
        Duration::from_secs(receiver_timeout),
        listen_for_packets(receiver, ipv4_net),
    );

    // Now we wait
    // Joining sender thread - It should have a shorter timeout than the receiver thread
    let sender_result = sender_thread.await;
    match sender_result {
        Ok(_) => info!("ARP sender done"),
        Err(_) => warn!("ARP sender timed out"),
    };
    info!(
        "ARP sender took {} secs",
        (Instant::now() - sender_start).as_secs()
    );

    // Joining receiver thread
    let receiver_result = receiver_thread.await;
    match receiver_result {
        Ok(_) => info!("ARP receiver done"),
        Err(_) => warn!("ARP receiver timed out"),
    };
    info!(
        "ARP receiver took {} secs",
        (Instant::now() - receiver_start).as_secs()
    );

    let mut devices = Vec::new();
    devices.push(Device {
        mac_address: String::from("mac"),
        ipv4_address: String::from("ip"),
    });
    devices
}
