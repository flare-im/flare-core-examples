import 'dart:async';
import 'dart:convert';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/application/providers/sdk_provider.dart';
import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im_ui/flare_im_ui.dart'
    show
        FlareAccessConnectAck,
        FlareAccessPoint,
        FlareAccessRecovering,
        FlareAccessStatus;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A `flare-recover://` link the router reports. The router gives the link an
/// empty path of `/`; the core takes it as it was issued. Null for any other
/// location. The core verifies it.
String? recoveryLinkOf(Uri location) => location.scheme == 'flare-recover'
    ? location.replace(path: '').toString()
    : null;

String? _present(String? value) => value?.isEmpty == true ? null : value;

/// `access.getStatus` as the kit's diagnostics page takes it.
FlareAccessStatus kitAccessStatus(core.AccessStatus status) {
  final ack = status.connectAck;
  final recovering = status.recovering;
  return FlareAccessStatus(
    loaded: status.loaded,
    serial: status.serial,
    source: status.source,
    stale: status.stale,
    developmentMode: status.developmentMode,
    regionId: _present(status.regionId),
    accessPointId: _present(status.accessPointId),
    protocol: _present(status.protocol),
    connectAck: ack == null
        ? null
        : FlareAccessConnectAck(
            accessPointId: ack.accessPointId,
            accessPointMismatch: ack.accessPointMismatch,
          ),
    recovering: recovering == null
        ? null
        : FlareAccessRecovering(
            rounds: recovering.rounds,
            nextRoundAtMs: recovering.nextRoundAtMs,
          ),
  );
}

/// One row of `access.listAccessPoints` as the kit's diagnostics page takes it.
FlareAccessPoint kitAccessPoint(core.AccessPointInfo point) => FlareAccessPoint(
  accessPointId: point.accessPointId,
  regionId: _present(point.regionId),
  host: _present(point.host),
  status: point.status,
  rttMs: point.rttMs,
  breaker: point.breaker,
  pinned: point.pinned,
  current: point.current,
);

/// Reads the page again on every link event; every other event is not its
/// business.
final class _LinkEvents extends core.FlareImEventListener {
  const _LinkEvents(this._changed);

  final void Function() _changed;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  void onConnectionStatusChanged(core.ConnectionStatus event) => _changed();

  @override
  void onAccessChanged(core.AccessChangedEvent event) => _changed();

  @override
  void onAccessSwitched(core.AccessSwitchedEvent event) => _changed();
}

/// The host of the network and line page: it reads `access.*`, hands the
/// results to the kit's diagnostics page and carries out what the kit reports.
/// What the page says and which line can be pinned are the kit's.
///
/// One lives for the app, so a recovery link opened from outside and the page
/// it opens read the same outcome.
class AccessDiagnosticsController extends ChangeNotifier {
  AccessDiagnosticsController({
    required Future<core.AccessApi> Function() access,
    required core.EventSubscription Function(core.FlareImEventListener)
    addEventListener,
    Future<void> Function(String text)? writeClipboard,
  }) : _access = access,
       _addEventListener = addEventListener,
       _writeClipboard =
           writeClipboard ??
           ((text) => Clipboard.setData(ClipboardData(text: text)));

  final Future<core.AccessApi> Function() _access;
  final core.EventSubscription Function(core.FlareImEventListener)
  _addEventListener;
  final Future<void> Function(String text) _writeClipboard;

  FlareAccessStatus? status;
  List<FlareAccessPoint> accessPoints = const [];
  bool refreshing = false;
  String? refreshOutcome;
  bool importing = false;
  String? importOutcome;
  String? importCode;
  bool exporting = false;
  String? exportOutcome;

  core.EventSubscription? _following;

  /// Bumped by every read: a slower read that started earlier must not put an
  /// older directory back.
  int _reads = 0;

  Future<void> reload() async {
    final read = ++_reads;
    try {
      final access = await _access();
      final nextStatus = access.getStatus();
      final nextPoints = access.listAccessPoints();
      final statusRead = await nextStatus;
      final pointsRead = await nextPoints;
      if (read != _reads) return;
      status = kitAccessStatus(statusRead);
      accessPoints = pointsRead.map(kitAccessPoint).toList(growable: false);
      notifyListeners();
    } catch (error) {
      debugPrint('[access] reading the access directory failed: $error');
    }
  }

  /// Reads now and again on every link event, until [stop].
  void follow() {
    unawaited(reload());
    _following ??= _addEventListener(_LinkEvents(() => unawaited(reload())));
  }

  void stop() {
    _following?.unsubscribe();
    _following = null;
  }

  /// False when the core refused: the line left the directory meanwhile.
  Future<bool> pin(String accessPointId) async {
    var pinned = true;
    try {
      await (await _access()).pin(
        core.AccessPinRequest(accessPointId: accessPointId),
      );
    } catch (error) {
      debugPrint('[access] pinning an access point failed: $error');
      pinned = false;
    }
    await reload();
    return pinned;
  }

  Future<void> unpin() async {
    try {
      await (await _access()).unpin();
    } catch (error) {
      debugPrint('[access] unpinning failed: $error');
    }
    await reload();
  }

  Future<void> refresh() async {
    refreshing = true;
    refreshOutcome = null;
    notifyListeners();
    String outcome;
    try {
      outcome = (await (await _access()).refresh()).outcome;
    } catch (error) {
      debugPrint('[access] refreshing the access manifest failed: $error');
      outcome = 'failed';
    }
    refreshing = false;
    refreshOutcome = outcome;
    notifyListeners();
    await reload();
  }

  /// A bad link comes back as `rejected` with its code; only a configuration
  /// problem throws, and that is no reason to say nothing.
  Future<void> importRecovery(String link) async {
    importing = true;
    importOutcome = null;
    importCode = null;
    notifyListeners();
    String outcome;
    String? code;
    try {
      final result = await (await _access()).importRecovery(
        core.AccessImportRecoveryRequest(link: link),
      );
      outcome = result.outcome;
      code = result.code;
    } catch (error) {
      debugPrint('[access] importing a recovery link failed: $error');
      outcome = 'rejected';
    }
    importing = false;
    importOutcome = outcome;
    importCode = code;
    notifyListeners();
    await reload();
  }

  Future<void> exportDiagnostics() async {
    exporting = true;
    exportOutcome = null;
    notifyListeners();
    String outcome;
    try {
      final diagnostics = await (await _access()).exportDiagnostics();
      await _writeClipboard(
        const JsonEncoder.withIndent('  ').convert(diagnostics),
      );
      outcome = 'copied';
    } catch (error) {
      debugPrint('[access] copying the diagnostics failed: $error');
      outcome = 'failed';
    }
    exporting = false;
    exportOutcome = outcome;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// `access.*` does not wait for a session, but it does need the core: a
/// recovery link can arrive before anyone signed in.
final accessDiagnosticsProvider =
    ChangeNotifierProvider<AccessDiagnosticsController>((ref) {
      final sdk = ref.watch(sdkWrapperProvider);
      final ready = ref.watch(sdkReadyProvider);
      return AccessDiagnosticsController(
        access: () async {
          await ready();
          return sdk.access;
        },
        addEventListener: sdk.addEventListener,
      );
    });
