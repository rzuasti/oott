use crate::device_finders::Device;
use crate::mac_vendor_finder;
use chrono::Local;
use duration_string::DurationString;
use log::{debug, info, trace};
use pnet::datalink::{DataLinkReceiver, DataLinkSender, NetworkInterface};
use pnet::ipnetwork::Ipv4Network;
use pnet::packet::arp::{ArpHardwareTypes, ArpOperations, ArpPacket, MutableArpPacket};
use pnet::packet::ethernet::{EtherTypes, EthernetPacket, MutableEthernetPacket};
use pnet::packet::{MutablePacket, Packet};
use pnet::util::MacAddr;
use tokio::time::{Duration, Instant, sleep};

pub async fn send_packet(
    mut tx: Box<dyn DataLinkSender>,
    interface: NetworkInterface,
    sender_ip: Ipv4Network,
    sender_macaddr: MacAddr,
) {
    info!("Starting ARP sender");
    let sender_start = Instant::now();

    let mut count = 0;
    for target_ip in sender_ip.iter() {
        if target_ip == sender_ip.ip() {
            continue;
        }
        trace!("Sending ARP packet to {}", target_ip);
        for _ in 0..1 {
            //arp packet
            let mut arp_buf = [0u8; 28];
            let mut arp_packet = MutableArpPacket::new(&mut arp_buf).unwrap();

            arp_packet.set_hardware_type(ArpHardwareTypes::Ethernet);
            arp_packet.set_protocol_type(EtherTypes::Ipv4);
            arp_packet.set_hw_addr_len(6);
            arp_packet.set_operation(ArpOperations::Request);
            arp_packet.set_proto_addr_len(4);
            arp_packet.set_sender_hw_addr(sender_macaddr);
            arp_packet.set_sender_proto_addr(sender_ip.ip());
            arp_packet.set_target_hw_addr(MacAddr::zero());
            arp_packet.set_target_proto_addr(target_ip);

            //ethernet packet
            let mut ethernet_buf = [0u8; 42];
            let mut ethernet_packet = MutableEthernetPacket::new(&mut ethernet_buf).unwrap();

            ethernet_packet.set_destination(MacAddr::broadcast());
            ethernet_packet.set_source(sender_macaddr);
            ethernet_packet.set_ethertype(EtherTypes::Arp);
            ethernet_packet.set_payload(arp_packet.packet_mut());

            tx.send_to(
                &ethernet_packet.to_immutable().packet(),
                Some(interface.clone()),
            );
        }
        count += 1;
        // Sleep  1 millisecond every 50 packets
        if (count % 50) == 0 {
            debug!("Sent {count} ARP packets so far.");
            sleep(Duration::from_millis(1)).await;
        }
    }
    info!(
        "ARP sender took {} secs",
        (Instant::now() - sender_start).as_secs()
    );
}

pub async fn listen_for_packets(
    mut rx: Box<dyn DataLinkReceiver>,
    ipv4_net: Ipv4Network,
    run_for: Duration,
) -> Vec<Device> {
    info!(
        "Starting ARP receiver for {}",
        String::from(DurationString::from(run_for))
    );
    let start_time = Instant::now();

    let mut devices = Vec::new();

    let mut count = 0;
    // Run while still under the time window
    while start_time.elapsed() <= run_for {
        let arp_buffer = match rx.next() {
            Ok(buffer) => buffer,
            Err(_) => continue,
        };
        let ethernet_packet = EthernetPacket::new(arp_buffer).unwrap();

        if ethernet_packet.get_ethertype() == EtherTypes::Arp {
            debug!("ARP packet received");
            let arp_packet = ArpPacket::new(ethernet_packet.payload()).unwrap();
            if arp_packet.get_operation() == ArpOperations::Reply {
                debug!("It is an ARP reply packet");
                if arp_packet.get_target_proto_addr() == ipv4_net.ip() {
                    let packet_mac_address = arp_packet.get_sender_hw_addr().to_string();
                    let packet_ip_address = arp_packet.get_sender_proto_addr().to_string();
                    let packet_vendor = mac_vendor_finder::find(
                        packet_mac_address.get(0..8).unwrap_or("").to_string(),
                    );

                    debug!(
                        "Found online  device - IP addr={} - MAC addr={} - vendor={}",
                        packet_ip_address, packet_mac_address, packet_vendor
                    );
                    devices.push(Device {
                        mac_address: packet_mac_address,
                        ipv4_address: packet_ip_address,
                        vendor: packet_vendor,
                        last_seen: Local::now().naive_local(),
                    });
                }
            }
        }
        count += 1;
        if (count % 10) == 0 {
            // Sleep  1 millisecond every 10 packets
            sleep(Duration::from_millis(1)).await;
        }
    }
    info!(
        "ARP receiver ran for {}",
        String::from(DurationString::from(Duration::from_secs(
            start_time.elapsed().as_secs()
        )))
    );

    devices
}
