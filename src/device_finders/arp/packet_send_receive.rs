use log::{debug, info, warn};
use pnet::datalink::{DataLinkReceiver, DataLinkSender, NetworkInterface};
use pnet::ipnetwork::Ipv4Network;
use pnet::packet::arp::{ArpHardwareTypes, ArpOperations, ArpPacket, MutableArpPacket};
use pnet::packet::ethernet::{EtherTypes, EthernetPacket, MutableEthernetPacket};
use pnet::packet::{MutablePacket, Packet};
use pnet::util::MacAddr;
use tokio::time::{Duration, sleep, timeout};

pub async fn send_packet(
    mut tx: Box<dyn DataLinkSender>,
    interface: NetworkInterface,
    sender_ip: Ipv4Network,
    sender_macaddr: MacAddr,
) {
    info!("Starting ARP sender loop");
    for target_ip in sender_ip.iter() {
        if target_ip == sender_ip.ip() {
            continue;
        }
        debug!("Sending ARP packet to {}", target_ip);
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
        // Sleep  1 millisecond between IPs
        sleep(Duration::from_millis(1)).await;
    }
}

pub async fn listen_for_packets(mut rx: Box<dyn DataLinkReceiver>, ipv4_net: Ipv4Network) {
    info!("Starting ARP receiver loop");
    loop {
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
                    info!(
                        "Found online  device - IP addr={} - MAC addr={}",
                        arp_packet.get_sender_proto_addr(),
                        arp_packet.get_sender_hw_addr()
                    );
                }
            }
        }
        // Sleep  1 millisecond between IPs
        sleep(Duration::from_millis(1)).await;
    }
}
