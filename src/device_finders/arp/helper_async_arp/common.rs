use async_arp::{ProbeInput, ProbeInputBuilder};
use ipnet::Ipv4Net;
use pnet::datalink::{self, NetworkInterface};
use std::net::IpAddr;

// Generate the probe inputs for a scan
pub(crate) fn generate_probe_inputs(net: Ipv4Net, interface: NetworkInterface) -> Vec<ProbeInput> {
    net.hosts()
        .map(|target_ip| {
            let sender_mac = interface
                .mac
                .ok_or("interface does not have mac address")
                .unwrap();
            ProbeInputBuilder::new()
                .with_sender_mac(sender_mac)
                .with_target_ip(target_ip)
                .build()
                .unwrap()
        })
        .collect()
}

// Find the desired network interface
pub(crate) fn interface_from(interface_name: &str) -> NetworkInterface {
    datalink::interfaces()
        .into_iter()
        .find(|iface| iface.name == interface_name)
        .ok_or_else(|| format!("interface {} not found", interface_name))
        .unwrap()
}

// Find the network from which we are probing
pub(crate) fn net_from(interface: &NetworkInterface) -> Option<Ipv4Net> {
    let net = interface
        .ips
        .iter()
        .filter(|net| net.is_ipv4())
        .take(1)
        .next()?;
    if let IpAddr::V4(ipv4) = net.ip() {
        Some(Ipv4Net::new(ipv4, net.prefix()).unwrap())
    } else {
        None
    }
}
