use log::{debug, error};
use pushover::API;
use pushover::requests::message::SendMessage;

use crate::notifications::error::DeliveryError;
use crate::settings::Pushover;

pub fn send_message(config: &Pushover, title: String, body: String) -> Result<(), DeliveryError> {
    debug!("About to send message via pushover ({body})");
    let api = API::new();

    let mut msg = SendMessage::new(config.token.as_str(), config.user_key.as_str(), body);

    msg.set_title(title);

    match api.send(&msg) {
        Ok(_) => {
            debug!("Message sent successfully");
            Ok(())
        }
        Err(error) => {
            error!("Error sending message via pushover: {error}");
            Err(DeliveryError::from(error))
        }
    }
}
