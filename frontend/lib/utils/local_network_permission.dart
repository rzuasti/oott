/// Provokes iOS's local-network access prompt at app launch.
///
/// iOS shows the "allow access to devices on your local network" prompt the
/// first time an app touches the local network. Until this ran at startup, that
/// first touch was the user's "Test" tap in settings — so the prompt appeared
/// mid-request and the very first connection attempt always failed while the
/// user was still deciding. Triggering it here means the permission is settled
/// before the user ever reaches the settings screen.
///
/// The real work lives in the `_io` implementation, which depends on `dart:io`
/// and is therefore only compiled on native platforms. Web gets the `_stub`
/// no-op, so `dart:io` never reaches a web build. Android, while native, also
/// no-ops since only iOS has this prompt.
library;

export 'local_network_permission_stub.dart'
    if (dart.library.io) 'local_network_permission_io.dart';
