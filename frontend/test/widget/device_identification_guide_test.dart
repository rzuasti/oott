import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/devices/device_identification_guide.dart';
import 'package:frontend/model/device.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  Device device({String vendor = 'Acme Corp', String deviceType = 'laptop'}) =>
      Device.fromJson(deviceJson(vendor: vendor, deviceType: deviceType));

  // Pumps a button that opens the dialog, then taps it so the dialog is shown.
  Future<void> openDialog(WidgetTester tester, Device d) async {
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showDeviceIdentificationDialog(context, d),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows every guidance step', (tester) async {
    await openDialog(tester, device());

    expect(find.text('Identify this device'), findsOneWidget);
    expect(find.text('Check the manufacturer'), findsOneWidget);
    expect(find.text('Try the unplug test'), findsOneWidget);
    expect(find.text('Check your router'), findsOneWidget);
    expect(find.text('Scan its open ports (advanced)'), findsOneWidget);
  });

  testWidgets('weaves the vendor and type into the intro', (tester) async {
    await openDialog(
      tester,
      device(vendor: 'Acme Corp', deviceType: 'printer'),
    );

    expect(
      find.textContaining('Printer'),
      findsWidgets,
      reason: 'the inferred device type should appear in the intro',
    );
    expect(find.textContaining('Acme Corp'), findsWidgets);
  });

  testWidgets('closes when Close is tapped', (tester) async {
    await openDialog(tester, device());

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Identify this device'), findsNothing);
  });
}
