import 'package:flare_core_flutter_push/flare_core_flutter_push.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 系统推送在应用里的一端。插件在 `main` 里启动；这里管宿主的接上与登出、令牌登记的语言、个推的启用，
/// 以及首次通知引导按账号答过没有。权限的读取与变化、登记、去重、提示决策、登出清理都在引擎与原生模块里。
///
/// 链路在线时引擎自己出的系统通知交给插件的展示方：Android 接上后台展示器（引擎在后台照常确认、自己提示），
/// macOS 接上桌面通知。
class PushNotificationsService {
  PushNotificationsService({
    required FlarePushHost Function() host,
    FlarePush? push,
    FlareNotificationPresenter? presenter,
  }) : _host = host,
       _push = push ?? FlarePush.instance,
       _presenter = presenter ?? FlareNotificationPresenter.instance;

  /// 构建时给的个推 app id（`--dart-define=FLARE_GETUI_APP_ID=...`，与原生 Android 应用的同名构建属性一致；
  /// Android 构建也用它填个推 SDK 清单里的 `GETUI_APPID`）。没给时个推不启用。
  static const _getuiAppId = String.fromEnvironment('FLARE_GETUI_APP_ID');

  final FlarePushHost Function() _host;
  final FlarePush _push;
  final FlareNotificationPresenter _presenter;

  /// 这次运行里已经问过的账号：会话列表每次出现都会来问，同一个账号只在第一次出面板。
  final Set<String> _askedThisRun = {};

  /// 这个平台有没有系统推送（Android、iOS）。
  bool get isSupported => _push.isSupported;

  /// 这个平台有没有要接线的系统通知：系统推送（Android、iOS），或链路在线时的展示方（Android、桌面）。
  bool get hasSystemNotifications => _push.isSupported || _presenter.isSupported;

  /// 点击通知要去的会话：推送的通知已经由引擎核对属于当前账号；桌面通知来自登录着的这个客户端。每个平台只有
  /// 其中一路有点击。
  Stream<PlatformTapRoute> get routes =>
      Stream<PlatformTapRoute>.multi((controller) {
        final subscriptions = [
          _push.routes.listen(controller.add),
          _presenter.routes.listen(controller.add),
        ];
        controller.onCancel = () =>
            Future.wait([for (final s in subscriptions) s.cancel()]);
      });

  /// 系统通知权限：先给已知的当前值，之后原生模块在启动、申请之后与每次回到前台重读，变了才发。
  Stream<FlarePushPermissionStatus> get permissionChanges =>
      _push.permissionChanges;

  /// 登录或恢复会话之后：接上客户端的宿主，原生模块补报令牌与权限、解析排队的点击。构建给了个推 app id
  /// 才在这时启用个推：推送 SDK 不在用户登录之前初始化（只有 Android 有个推）。
  ///
  /// 同一个宿主再接给展示方：Android 要后台展示器（通知权限允许时原生告诉引擎接上），桌面开始出系统通知。
  /// macOS 的系统通知要授权：登录之后问这一次，用户这时知道是谁在要；决定过的不再弹框。
  Future<void> signedIn() async {
    final host = _host();
    if (_push.isSupported) {
      await _push.attach(host);
      if (_getuiAppId.isNotEmpty) await _push.installGetui();
      await _push.installJpush();
    }
    if (_presenter.isSupported) {
      await _presenter.attach(host);
      if (_presenter.kind == FlareNotificationPresenterKind.desktop) {
        await _presenter.requestPermission();
      }
    }
  }

  /// 登出之后：原生模块摘下宿主，清掉本 SDK 的通知（iOS 还把角标归零），下一个账号重新登记令牌；展示方摘下，
  /// 桌面上撤掉它出的通知、角标归零。
  Future<void> signedOut() async {
    await _presenter.signOut();
    await _push.signOut();
  }

  /// 应用内选的语言（BCP 47）：令牌登记用它，服务端兜底文案才和界面一致。
  Future<void> setLocale(String languageTag) => _push.setLocale(languageTag);

  /// 现在申请会不会弹出系统授权框；为 false 而通知没开时只能去系统设置。
  Future<bool> canRequestPermission() => _push.canRequestPermission();

  /// 弹系统授权框（系统会弹时），返回之后的权限；系统不会弹时不申请，直接返回现状。
  Future<FlarePushPermissionStatus> requestPermission() =>
      _push.requestPermission();

  /// 打开本应用的系统通知设置。
  Future<bool> openSettings() => _push.openNotificationSettings();

  /// 设置里的「新消息通知」：系统授权框还会弹就弹，弹不出来了（拒绝到不再弹框，或已经开着）去系统设置里改。
  Future<void> changeFromSettings() async {
    if (await _push.canRequestPermission()) {
      await _push.requestPermission();
    } else {
      await _push.openNotificationSettings();
    }
  }

  /// 后台限制（只有 Android），给设置里的「后台接收消息」：先给已知的现状，之后原生模块在启动与每次回到前台
  /// 重读，电池设置的档位变了才发。其余平台什么也不发。
  Stream<FlarePushBackgroundStatus> get backgroundChanges =>
      _push.backgroundChanges;

  /// 电池优化设置（只有 Android）。
  Future<bool> openBatterySettings() => _push.openBatterySettings();

  /// 厂商的自启动管理页（只有 Android）。
  Future<bool> openAutoStartSettings() => _push.openAutoStartSettings();

  /// 该不该给 [userId] 出首次通知引导：这次运行还没问过、这个账号也没答过、通知还没开。该出时记为这次运行问过；
  /// 请求还是引导去系统设置，由 [canRequestPermission] 决定。
  Future<bool> claimSoftAsk(String userId) async {
    if (!isSupported || userId.isEmpty || !_askedThisRun.add(userId)) {
      return false;
    }
    if (await _push.permissionStatus() == FlarePushPermissionStatus.granted) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_answeredKey(userId)) ?? false);
  }

  /// 记住这个账号答过首次引导（开启、前往设置或以后再说）：以后不再主动问，设置里随时能开。
  Future<void> answerSoftAsk(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_answeredKey(userId), true);
  }

  static String _answeredKey(String userId) =>
      'flare.push.softAskAnswered.$userId';
}
