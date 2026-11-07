import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flare_im/interface/widgets/connection_notice_host.dart';
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the SDK status reaches the kit field for field', () {
    expect(kitConnectionStatus(null), isNull);
    expect(
      kitConnectionStatus(
        const core.ConnectionStatus(
          phase: core.ConnectionPhase.actionRequired,
          accessPointId: 'development',
          protocol: 'ws',
          attempt: 2,
          nextRetryAt: 1762250000000,
          reason: 'kicked',
          developmentMode: true,
        ),
      ),
      const FlareConnectionStatus(
        phase: FlareConnectionPhase.actionRequired,
        attempt: 2,
        nextRetryAt: 1762250000000,
        reason: 'kicked',
        developmentMode: true,
      ),
    );
    // Every core phase has its kit phase; switching reasons pass through.
    for (final phase in core.ConnectionPhase.values) {
      expect(
        kitConnectionStatus(
          core.ConnectionStatus(phase: phase, reason: 'drain'),
        )?.phase.name,
        phase.name,
      );
    }
  });

  test(
    'listeners added before init attach to the client init creates',
    () async {
      final events = _RecordingEvents();
      Map<String, Object?>? created;
      final sdk = SdkWrapper(
        createClient: (config) async {
          created = config;
          return _FakeClient(events);
        },
      );
      final early = sdk.addEventListener(const _Listener());
      final dropped = sdk.addEventListener(const _Listener());
      dropped.unsubscribe();
      expect(events.listeners, isEmpty);

      await sdk.init(const SdkConfig(access: {'trustMode': 'development'}));

      expect(created?['access'], {'trustMode': 'development'});
      expect(created?['auth'], isEmpty);
      expect(events.listeners, hasLength(1));
      early.unsubscribe();
      expect(events.listeners, isEmpty);
      // The same config again is no new init.
      await sdk.init(const SdkConfig(access: {'trustMode': 'development'}));
      expect(events.batchSubscriptions, 1);
    },
  );
}

final class _Listener extends core.FlareImEventListener {
  const _Listener();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final class _RecordingEvents implements core.EventsApi {
  final listeners = <core.FlareImEventListener>[];
  var batchSubscriptions = 0;

  @override
  core.EventSubscription addEventListener(core.FlareImEventListener listener) {
    listeners.add(listener);
    return _Subscription(() => listeners.remove(listener));
  }

  @override
  Future<Map<String, Object?>> subscribeEventsBatch(
    Map<String, Object?> request,
  ) async {
    batchSubscriptions++;
    return {'subscription': batchSubscriptions};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Subscription implements core.EventSubscription {
  _Subscription(this._cancel);

  final void Function() _cancel;

  @override
  Object get id => identityHashCode(this);

  @override
  void unsubscribe() => _cancel();
}

final class _FakeClient implements core.FlareImClient {
  _FakeClient(this.events);

  @override
  final core.EventsApi events;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
