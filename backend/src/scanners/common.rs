//! Code shared by all scanners, factored out of the per-protocol modules.
//!
//! - [`pipeline`] persists a sighting and emits the matching event/notification.
//! - [`enrichment`] builds an enriched [`crate::model::devices::Device`] from a MAC + IP.
//! - [`active_status`] / [`passive_status`] hold the two scanner status state machines.

pub mod active_status;
pub mod enrichment;
pub mod passive_status;
pub mod pipeline;
