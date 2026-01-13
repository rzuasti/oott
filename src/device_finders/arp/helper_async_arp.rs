use async_arp::{Client, ClientConfigBuilder, ProbeStatus};
use std::time::{Duration, Instant};

use crate::device_finders::Device;
mod common;

#[tokio::main(flavor = "current_thread")]
pub async fn execute_probe(iface: &str) -> Vec<Device> {
    let interface = common::interface_from(&iface);
    let net = common::net_from(&interface).unwrap();

    let client = Client::new(
        ClientConfigBuilder::new(&iface)
            .with_response_timeout(Duration::from_millis(500))
            .build(),
    )
    .unwrap();

    let inputs = common::generate_probe_inputs(net, interface);
    let start = Instant::now();

    let futures = inputs.into_iter().map(|input| client.probe(input));
    let outcomes = futures::future::join_all(futures).await;
    let scan_duration = start.elapsed();

    let occupied = outcomes
        .into_iter()
        .filter_map(|outcome| outcome.ok())
        .filter(|outcome| outcome.status == ProbeStatus::Occupied);

    let mut devices = Vec::new();
    for outcome in occupied {
        devices.push(Device {
            mac_address: outcome.target_ip.to_string(),
        });
    }

    devices
}
