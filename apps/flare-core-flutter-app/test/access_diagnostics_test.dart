import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/application/providers/access_diagnostics_provider.dart';
import 'package:flare_im_ui/flare_im_ui.dart'
    show FlareAccessConnectAck, FlareAccessRecovering;
import 'package:flutter_test/flutter_test.dart';

final class _FakeAccess implements core.AccessApi {
  int serial = 7;
  final links = <String>[];
  final pins = <String>[];
  core.AccessRecoveryImport imported = const core.AccessRecoveryImport(
    outcome: 'adopted',
    serial: 9,
  );
  String refreshOutcome = 'upToDate';
  final failures = <String>{};

  void _maybeFail(String op) {
    if (failures.contains(op)) throw StateError('refused');
  }

  @override
  Future<core.AccessStatus> getStatus() async =>
      core.AccessStatus(loaded: true, serial: serial);

  @override
  Future<List<core.AccessPointInfo>> listAccessPoints() async => const [
    core.AccessPointInfo(
      accessPointId: 'ap-a',
      status: 'active',
      breaker: 'closed',
    ),
  ];

  @override
  Future<core.AccessPin> pin(core.AccessPinRequest request) async {
    _maybeFail('pin');
    pins.add(request.accessPointId);
    return core.AccessPin(accessPointId: request.accessPointId);
  }

  @override
  Future<void> unpin() async {}

  @override
  Future<core.AccessRefreshReport> refresh() async {
    _maybeFail('refresh');
    return core.AccessRefreshReport(outcome: refreshOutcome);
  }

  @override
  Future<core.AccessRecoveryImport> importRecovery(
    core.AccessImportRecoveryRequest request,
  ) async {
    links.add(request.link);
    _maybeFail('import');
    return imported;
  }

  @override
  Future<Map<String, Object?>> exportDiagnostics() async {
    _maybeFail('export');
    return {
      'status': {'serial': 7},
    };
  }
}

final class _Subscription implements core.EventSubscription {
  _Subscription(this._cancel);

  final void Function() _cancel;

  @override
  Object get id => identityHashCode(this);

  @override
  void unsubscribe() => _cancel();
}

({
  AccessDiagnosticsController controller,
  _FakeAccess access,
  List<core.FlareImEventListener> listeners,
  List<String> clipboard,
})
_host() {
  final access = _FakeAccess();
  final listeners = <core.FlareImEventListener>[];
  final clipboard = <String>[];
  final controller = AccessDiagnosticsController(
    access: () async => access,
    addEventListener: (listener) {
      listeners.add(listener);
      return _Subscription(() => listeners.remove(listener));
    },
    writeClipboard: (text) async => clipboard.add(text),
  );
  addTearDown(controller.dispose);
  return (
    controller: controller,
    access: access,
    listeners: listeners,
    clipboard: clipboard,
  );
}

void main() {
  group('recoveryLinkOf', () {
    test('gives the core the link as it was issued', () {
      expect(
        recoveryLinkOf(Uri.parse('flare-recover://v1?p=aB-_&k=root&s=c2ln')),
        'flare-recover://v1?p=aB-_&k=root&s=c2ln',
      );
      // The router normalizes an empty path to `/`.
      expect(
        recoveryLinkOf(Uri.parse('flare-recover://v1/?p=aB-_&k=root&s=c2ln')),
        'flare-recover://v1?p=aB-_&k=root&s=c2ln',
      );
    });

    test('leaves every other location alone', () {
      expect(recoveryLinkOf(Uri.parse('/')), isNull);
      expect(recoveryLinkOf(Uri.parse('/settings')), isNull);
      expect(recoveryLinkOf(Uri.parse('https://example.com/v1?p=a')), isNull);
    });
  });

  test('the SDK results reach the kit field for field', () {
    final status = kitAccessStatus(
      const core.AccessStatus(
        loaded: true,
        serial: 42,
        source: 'recovery',
        stale: true,
        developmentMode: true,
        regionId: 'cn-east',
        accessPointId: 'ap-a',
        protocol: 'quic',
        connectAck: core.AccessConnectAck(
          accessPointId: 'ap-b',
          accessPointMismatch: true,
        ),
        recovering: core.AccessRecoveringStatus(rounds: 2, nextRoundAtMs: 1000),
      ),
    );
    expect(status.serial, 42);
    expect(status.source, 'recovery');
    expect(status.stale, isTrue);
    expect(status.developmentMode, isTrue);
    expect(status.regionId, 'cn-east');
    expect(status.accessPointId, 'ap-a');
    expect(status.protocol, 'quic');
    expect(
      status.connectAck,
      const FlareAccessConnectAck(
        accessPointId: 'ap-b',
        accessPointMismatch: true,
      ),
    );
    expect(
      status.recovering,
      const FlareAccessRecovering(rounds: 2, nextRoundAtMs: 1000),
    );

    final point = kitAccessPoint(
      const core.AccessPointInfo(
        accessPointId: 'ap-a',
        status: 'draining',
        rttMs: 12.5,
        breaker: 'open',
        pinned: true,
        current: true,
      ),
    );
    expect(point.regionId, isNull);
    expect(point.host, isNull);
    expect(point.status, 'draining');
    expect(point.rttMs, 12.5);
    expect(point.breaker, 'open');
    expect(point.pinned, isTrue);
    expect(point.current, isTrue);
  });

  group('AccessDiagnosticsController', () {
    test('reads on opening and on link events, until stopped', () async {
      final host = _host();
      host.controller.follow();
      await pumpEventQueue();
      expect(host.controller.status?.serial, 7);
      expect(host.controller.accessPoints.single.accessPointId, 'ap-a');

      host.access.serial = 8;
      host.listeners.single.onConnectionStatusChanged(
        const core.ConnectionStatus(phase: core.ConnectionPhase.online),
      );
      await pumpEventQueue();
      expect(host.controller.status?.serial, 8);

      host.controller.stop();
      expect(host.listeners, isEmpty);
    });

    test('a pin the core refuses reads as refused, then reads again', () async {
      final host = _host();
      expect(await host.controller.pin('ap-a'), isTrue);
      expect(host.access.pins, ['ap-a']);

      host.access.failures.add('pin');
      host.access.serial = 8;
      expect(await host.controller.pin('ap-gone'), isFalse);
      expect(host.controller.status?.serial, 8);
    });

    test('a refresh clears the last answer, then fills its outcome', () async {
      final host = _host();
      host.controller.refreshOutcome = 'failed';
      final round = host.controller.refresh();
      expect(host.controller.refreshing, isTrue);
      expect(host.controller.refreshOutcome, isNull);
      await round;
      expect(host.controller.refreshOutcome, 'upToDate');

      host.access.failures.add('refresh');
      await host.controller.refresh();
      expect(host.controller.refreshOutcome, 'failed');
      expect(host.controller.refreshing, isFalse);
    });

    test('a rejected link carries its code back to the page', () async {
      final host = _host();
      host.access.imported = const core.AccessRecoveryImport(
        outcome: 'rejected',
        code: 'rollback',
        serial: 7,
      );
      await host.controller.importRecovery('flare-recover://v1?p=a&k=b&s=c');
      expect(host.access.links, ['flare-recover://v1?p=a&k=b&s=c']);
      expect(host.controller.importOutcome, 'rejected');
      expect(host.controller.importCode, 'rollback');
      expect(host.controller.importing, isFalse);
    });

    test('an import that throws is not silent', () async {
      final host = _host();
      host.access.failures.add('import');
      await host.controller.importRecovery('flare-recover://x');
      expect(host.controller.importOutcome, 'rejected');
      expect(host.controller.importCode, isNull);
    });

    test('the diagnostics go to the clipboard as readable JSON', () async {
      final host = _host();
      await host.controller.exportDiagnostics();
      expect(host.controller.exportOutcome, 'copied');
      expect(host.clipboard.single, contains('"serial": 7'));

      host.access.failures.add('export');
      await host.controller.exportDiagnostics();
      expect(host.controller.exportOutcome, 'failed');
    });
  });
}
