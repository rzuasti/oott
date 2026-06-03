import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/backend_reachability.dart';
import 'package:frontend/utils/polled_value.dart';

import '../helpers/backend_test_harness.dart';

void main() {
  late List<Completer<int>> completers;

  setUp(() async {
    completers = [];
    await setUpBackendForTest();
  });

  // A PolledValue whose every fetch is resolved manually through [completers].
  // The poll interval is effectively disabled so only explicit reloads fetch.
  PolledValue<int> makePolled({
    Duration staleErrorAfter = const Duration(seconds: 30),
  }) {
    return PolledValue<int>(
      fetch: ({cancelToken}) {
        final completer = Completer<int>();
        completers.add(completer);
        return completer.future;
      },
      pollInterval: const Duration(hours: 1),
      staleErrorAfter: staleErrorAfter,
    );
  }

  DioException connectionError() => DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );

  test('starts in initialLoading then becomes fresh on success', () async {
    final polled = makePolled();
    addTearDown(polled.dispose);

    expect(polled.freshness, PolledFreshness.initialLoading);
    expect(polled.value, isNull);

    completers[0].complete(5);
    await pumpEventQueue();

    expect(polled.freshness, PolledFreshness.fresh);
    expect(polled.value, 5);
  });

  test('becomes error when the first load fails with no prior value', () async {
    final polled = makePolled();
    addTearDown(polled.dispose);

    completers[0].completeError(connectionError());
    await pumpEventQueue();

    expect(polled.freshness, PolledFreshness.error);
    expect(polled.value, isNull);
    expect(polled.lastErrorMessage, isNotNull);
  });

  test('a failure after a success is stale, then error past staleErrorAfter',
      () async {
    final polled = makePolled(staleErrorAfter: const Duration(seconds: 1));
    addTearDown(polled.dispose);

    completers[0].complete(1);
    await pumpEventQueue();
    expect(polled.freshness, PolledFreshness.fresh);

    // Force a second load and fail it.
    polled.pause();
    polled.resume();
    await pumpEventQueue();
    completers[1].completeError(connectionError());
    await pumpEventQueue();

    expect(polled.value, 1, reason: 'keeps the last good value');
    expect(polled.freshness, PolledFreshness.stale);

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(polled.freshness, PolledFreshness.error);
  });

  test('effectiveFreshness downgrades error to stale while offline', () async {
    final polled = makePolled(staleErrorAfter: const Duration(milliseconds: 1));
    addTearDown(polled.dispose);

    completers[0].complete(1);
    await pumpEventQueue();
    polled.pause();
    polled.resume();
    await pumpEventQueue();
    completers[1].completeError(connectionError());
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 5));

    // Base freshness is error (value present, but past the 1ms threshold).
    expect(polled.freshness, PolledFreshness.error);

    // Online: effective freshness mirrors the base error.
    expect(effectiveFreshness(polled), PolledFreshness.error);

    // Offline with a value present: downgraded to stale.
    BackendReachability.instance.recordFailure(connectionError());
    expect(BackendReachability.instance.isOnline, isFalse);
    expect(effectiveFreshness(polled), PolledFreshness.stale);
  });

  test('pause/resume is reference counted across reasons', () async {
    final polled = makePolled();
    addTearDown(polled.dispose);

    completers[0].complete(1);
    await pumpEventQueue();
    expect(completers, hasLength(1));

    polled.pauseFor(PolledPauseReason.manual);
    polled.pauseFor(PolledPauseReason.unreachable);

    // Removing only one of two reasons must not reload.
    polled.resumeFor(PolledPauseReason.manual);
    await pumpEventQueue();
    expect(completers, hasLength(1));

    // Clearing the last reason reloads.
    polled.resumeFor(PolledPauseReason.unreachable);
    await pumpEventQueue();
    expect(completers, hasLength(2));
  });
}
