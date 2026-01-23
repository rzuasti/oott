use log::{debug, error};
use pushover::API;
use pushover::requests::message::SendMessage;

use crate::settings::CONFIG;

pub fn send_message(body: String) -> Result<(), String> {
    debug!("About to send message via pushover ({body})");
    let api = API::new();

    let msg = SendMessage::new(
        CONFIG.notifications.pushover.token.as_str(),
        CONFIG.notifications.pushover.user_key.as_str(),
        body,
    );

    match api.send(&msg) {
        Ok(_) => {
            debug!("Message sent successfully");
            Ok(())
        }
        Err(error) => {
            error!("Error sending message via pushover: {error}");
            Err(format!("Error sending message via pushover: {error}"))
        }
    }
}
