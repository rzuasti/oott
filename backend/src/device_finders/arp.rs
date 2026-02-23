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

pub async fn find(interface: String) -> Result<Vec<Device>, Box<dyn std::error::Error>> {
    debug!("Looking up devices via ARP using interface {}", interface);

    // Get the network device to use
    let network_interface: NetworkInterface = match datalink::interfaces()
        .iter()
        .filter(|el| el.is_up())
        .filter(|el| el.name == interface)
        .next()
    {
        Some(value) => value.clone(),
        None => {
            error!("Interface ({interface}) not found or not active.");
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
            error!("No IP address found for selected interface ({interface}).");
            return Err(NoIPAddressError.into());
        }
    };

    // Get the local MAC address
    let mac = match network_interface.mac {
        Some(mac) => mac,
        None => {
            error!("Could not get MAC address for selected interface ({interface}).");
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
    let sender_timeout: Duration = get_settings().timings.arp_sender_timeout.into();
    info!(
        "Sender timeout set to {}",
        get_settings().timings.arp_sender_timeout
    );
    let scan_duration: Duration = get_settings().timings.arp_scan_duration.into();
    let receiver_timeout: Duration = scan_duration * 2;
    info!(
        "Scan duration set to {}",
        get_settings().timings.arp_scan_duration
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
