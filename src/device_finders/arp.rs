use crate::device_finders::{
    Device,
    arp::packet_send_receive::{listen_for_packets, send_packet},
};
use pnet::{
    datalink::{self, Channel, NetworkInterface},
    ipnetwork::IpNetwork,
};
use tokio::task;
use tokio::time::{Duration, sleep, timeout};

mod packet_send_receive;

pub async fn find(interface: &str) -> Vec<Device> {
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

    println!("Local MAC: {}", mac);
    println!("Local IP: {}", ipv4_net);

    // Data channel
    println!("Creating data channel");
    let tunnel = datalink::channel(&network_interface, datalink::Config::default())
        .expect("Failed to create datalink channel");
    let (sender, receiver) = match tunnel {
        Channel::Ethernet(tx, rx) => (tx, rx),
        _ => panic!("Unsupported data channel type"),
    };

    let send_interface = network_interface.clone();

    println!("Starting sender");

    let send_result = timeout(
        Duration::from_secs(2),
        send_packet(sender, send_interface, ipv4_net, mac),
        // test_timeout(),
    )
    .await;
    match send_result {
        Ok(_) => println!("Sender done"),
        Err(_) => println!("Sender timed out"),
    };

    // let receive_result = timeout(
    //     Duration::from_secs(5),
    //     listen_for_packets(receiver, ipv4_net),
    // )
    // .await;
    // match receive_result {
    //     Ok(_) => println!("Receiver done"),
    //     Err(_) => println!("Receiver timed out"),
    // };

    // println!("Spawning receiver threads");
    // let reciever_thread = thread::spawn(move || {
    //     listen_for_packets(receiver, ipv4_net);
    // });

    // println!("Spawning sender thread");
    // let sender_thread = thread::spawn(move || {
    //     send_packet(sender, send_interface, ipv4_net, mac);
    // });

    // match sender_thread.join() {
    //     Ok(it) => println!("Sender thread done"),
    //     Err(err) => panic!("Error sending ARP packets"),
    // };

    // println!("Waiting to receive");
    // thread::sleep(Duration::from_secs(10));
    // println!("Done!");

    let mut devices = Vec::new();
    devices.push(Device {
        mac_address: String::from("mac"),
        ipv4_address: String::from("ip"),
    });
    devices
}

async fn test_timeout() {
    sleep(Duration::from_secs(10)).await;
}
