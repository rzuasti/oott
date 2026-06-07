import 'dart:io';

import 'package:flutter/foundation.dart';

/// Native implementation of [requestLocalNetworkPermission]. Only iOS has a
/// local-network permission prompt, so this is a no-op on every other native
/// platform (Android, desktop).
///
/// Sending a datagram toward the mDNS multicast group is enough to make iOS
/// surface the prompt; nothing needs to be received and no backend has to be
/// reachable.
Future<void> requestLocalNetworkPermission() async {
  if (!Platform.isIOS) return;

  RawDatagramSocket? socket;
  try {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    // 224.0.0.251:5353 is the mDNS group; the send itself is what trips the
    // permission prompt, regardless of whether anything is listening.
    socket.send(const [0], InternetAddress('224.0.0.251'), 5353);
  } catch (e) {
    debugPrint('Local network permission trigger failed: $e');
  } finally {
    socket?.close();
  }
}
