import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/scanner_status_card.dart';

import '../helpers/backend_test_harness.dart';
import '../helpers/pump_app.dart';

ScannerStatus _resolve(BuildContext context, int value, double elapsed) =>
    (color: Colors.green, label: 'Value $value', sublabels: ['detail line']);

void main() {
  setUp(() async {
    await setUpBackendForTest();
  });

  testWidgets('shows a spinner, then the resolved label and sublabels',
      (tester) async {
    await pumpScreen(
      tester,
      ScannerStatusCard<int>(
        title: 'Probe',
        fetch: ({cancelToken}) async => 42,
        resolver: _resolve,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await pumpUntilFound(tester, find.text('Value 42'));

    expect(find.text('Probe'), findsOneWidget);
    expect(find.text('detail line'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('renders an Error state when the fetch fails', (tester) async {
    await pumpScreen(
      tester,
      ScannerStatusCard<int>(
        title: 'Probe',
        fetch: ({cancelToken}) async => throw DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
        resolver: _resolve,
      ),
    );

    await pumpUntilFound(tester, find.text('Error'));

    expect(find.text('Error'), findsOneWidget);

    await tearDownTree(tester);
  });
}
