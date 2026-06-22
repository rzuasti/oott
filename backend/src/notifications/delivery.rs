use log::{error, info, warn};
use once_cell::sync::OnceCell;
use tokio::sync::mpsc;

use crate::settings::get_settings;

use super::push;
use super::pushover;

// A notification handed to the delivery loop. Delivery (a blocking Pushover HTTP call) runs on a
// dedicated task so a slow or unreachable Pushover can never stall the scan loops.
struct DeliveryRequest {
    title: String,
    body: String,
}

// Bounded so a stuck delivery loop cannot grow memory without limit; on overflow we drop and warn
// (delivery is best-effort, matching the "never stop the loop" policy in the scanner pipeline).
const DELIVERY_QUEUE_CAPACITY: usize = 100;

static DELIVERY_TX: OnceCell<mpsc::Sender<DeliveryRequest>> = OnceCell::new();

/// Owns the receiving end of the notification-delivery channel and delivers notifications off the
/// scan loop. Run this as its own task (see `main`); it returns only if the channel is closed.
pub async fn run_delivery() {
    let (tx, mut rx) = mpsc::channel::<DeliveryRequest>(DELIVERY_QUEUE_CAPACITY);
    if DELIVERY_TX.set(tx).is_err() {
        error!("Notification delivery loop started more than once; ignoring");
        return;
    }

    while let Some(request) = rx.recv().await {
        deliver(request).await;
    }
}

// Deliver a single notification according to the configured method. The Pushover call is blocking,
// so it runs on the blocking thread pool rather than the delivery task's async thread.
async fn deliver(request: DeliveryRequest) {
    match get_settings().notifications.method.as_str() {
        "pushover" => match &get_settings().notifications.pushover {
            Some(config) => {
                let config = config.clone();
                let result = tokio::task::spawn_blocking(move || {
                    pushover::send_message(&config, request.title, request.body)
                })
                .await;
                match result {
                    Ok(Ok(())) => {}
                    Ok(Err(err)) => error!("Failed to deliver notification via Pushover: {err}"),
                    Err(err) => error!("Notification delivery task panicked: {err}"),
                }
            }
            None => {
                error!(
                    "Notification method is 'pushover' but no [notifications.pushover] section is \
                     configured; cannot deliver notification."
                );
            }
        },
        "push" => {
            // The relay URL defaults to the project-operated relay, so the [notifications.push]
            // section is optional. The send call is async (reqwest), so unlike Pushover it is
            // awaited directly rather than dispatched to the blocking pool.
            let config = get_settings()
                .notifications
                .push
                .clone()
                .unwrap_or_default();
            if let Err(err) = push::send(&config, request.title, request.body).await {
                error!("Failed to deliver notification via the push relay: {err}");
            }
        }
        other => {
            warn!("Notification method set to '{other}'. Set logs to 'info' to see notifications.");
            info!("Notification: {}", request.body);
        }
    }
}

// Hand a notification to the delivery loop. Never blocks: if the loop is not running (e.g. in
// tests) or its queue is full, the notification is logged and dropped rather than stalling the
// caller (a scan loop).
pub(super) fn enqueue(title: String, body: String) {
    match DELIVERY_TX.get() {
        Some(tx) => {
            if let Err(err) = tx.try_send(DeliveryRequest { title, body }) {
                warn!("Notification delivery queue unavailable; dropping notification: {err}");
            }
        }
        None => {
            info!("Notification (delivery loop not running): {body}");
        }
    }
}
