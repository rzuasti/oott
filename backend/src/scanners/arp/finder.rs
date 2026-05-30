use super::packet_send_receive::{listen_for_packets, send_packet};
use crate::model::devices::Device;
use crate::scanners::error::{
    DataChannelError, InvalidDeviceError, NoIPAddressError, NoMACAddressError,
};
use crate::settings::get_settings;
use crate::utils::network::select_interface;
use duration_string::DurationString;
use log::{debug, error, info, warn};
use pnet::{
    datalink::{self, Channel, NetworkInterface},
    ipnetwork::IpNetwork,
};
use tokio::time::{Duration, timeout};

pub async fn find(interface: Option<String>) -> Result<Vec<Device>, Box<dyn std::error::Error>> {
    debug!(
        "Looking up devices via ARP, configured interface: {:?}",
        interface
    );

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
            error!(
                "No IP address found for selected interface ({}).",
                network_interface.name
            );
            return Err(NoIPAddressError.into());
        }
    };

    // Get the local MAC address
    let mac = match network_interface.mac {
        Some(mac) => mac,
        None => {
            error!(
                "Could not get MAC address for selected interface ({}).",
                network_interface.name
            );
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
