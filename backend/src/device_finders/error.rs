use std::{error, fmt};

#[derive(Debug)]
pub struct InvalidDeviceError;

impl fmt::Display for InvalidDeviceError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "Invalid network device")
    }
}

impl error::Error for InvalidDeviceError {}

#[derive(Debug)]
pub struct NoIPAddressError;

impl fmt::Display for NoIPAddressError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "No IP address found for device")
    }
}

impl error::Error for NoIPAddressError {}

#[derive(Debug)]
pub struct NoMACAddressError;

impl fmt::Display for NoMACAddressError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "No MAC address found for device")
    }
}

impl error::Error for NoMACAddressError {}

#[derive(Debug)]
pub struct DataChannelError;

impl fmt::Display for DataChannelError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "Error creating or using network data channel")
    }
}

impl error::Error for DataChannelError {}
