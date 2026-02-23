use log::{debug, error};
use pushover::requests::message::SendMessage;
use pushover::{API, Error};

use crate::settings::get_settings;

pub fn send_message(body: String) -> Result<(), Error> {
    debug!("About to send message via pushover ({body})");
    let api = API::new();

    let msg = SendMessage::new(
        get_settings().notifications.pushover.token.as_str(),
        get_settings().notifications.pushover.user_key.as_str(),
        body,
    );

    match api.send(&msg) {
        Ok(_) => {
            debug!("Message sent successfully");
            Ok(())
        }
        Err(error) => {
            error!("Error sending message via pushover: {error}");
            Err(error)
        }
    }
}
