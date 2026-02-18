use crate::model;

pub fn list() -> Vec<model::notifications::Notification> {
    unimplemented!("Not ready yet");
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tests_common;

    #[tokio::test]
    async fn list_default() {
        tests_common::setup_database().await;
        let notifications = list();
        assert_eq!(notifications.len(), 1);
    }
}
