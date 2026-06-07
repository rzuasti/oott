/// Web/no-`dart:io` fallback for [requestLocalNetworkPermission]. There is no
/// local-network prompt to provoke off-device, so this does nothing.
Future<void> requestLocalNetworkPermission() async {}
