import 'package:flare_im/shared/i18n/flare_locale.dart';

/// 与 Vue `flareMessages` 核心键对齐的文案树（登录 / 会话 / 聊天 / 连接 / 设置）。
final class FlareMessages {
  const FlareMessages._(this.locale, this._root);

  final FlareLocale locale;
  final Map<String, dynamic> _root;

  factory FlareMessages.of(FlareLocale locale) {
    return FlareMessages._(
      locale,
      _catalog[locale] ?? _catalog[FlareLocale.zhCn]!,
    );
  }

  String t(String path) {
    final parts = path.split('.');
    Object? node = _root;
    for (final part in parts) {
      if (node is! Map) return path;
      node = node[part];
    }
    if (node is String) return node;
    return path;
  }

  FlareNavCopy get nav => FlareNavCopy(this);
  FlareLoginCopy get login => FlareLoginCopy(this);
  FlareConversationCopy get conversation => FlareConversationCopy(this);
  FlareChatCopy get chat => FlareChatCopy(this);
  FlareComposerCopy get composer => FlareComposerCopy(this);
  FlareConnectionCopy get connection => FlareConnectionCopy(this);
  FlareSettingsCopy get settings => FlareSettingsCopy(this);
  FlareSdkLabCopy get sdkLab => FlareSdkLabCopy(this);
  FlareSearchCopy get search => FlareSearchCopy(this);
  FlareDetailsCopy get details => FlareDetailsCopy(this);
}

final class FlareNavCopy {
  const FlareNavCopy(this._m);
  final FlareMessages _m;
  String get login => _m.t('nav.login');
  String get conversations => _m.t('nav.conversations');
  String get sdkLab => _m.t('nav.sdkLab');
  String get settings => _m.t('nav.settings');
}

final class FlareLoginCopy {
  const FlareLoginCopy(this._m);
  final FlareMessages _m;
  String get brandTitle => _m.t('login.brandTitle');
  String get brandSubtitle => _m.t('login.brandSubtitle');
  String get welcomeTitle => _m.t('login.welcomeTitle');
  String get welcomeSubtitle => _m.t('login.welcomeHint');
  String get welcomeHint => _m.t('login.welcomeHint');
  String get userIdLabel => _m.t('login.userIdLabel');
  String get userIdPlaceholder => _m.t('login.userIdPlaceholder');
  String get serverToggle => _m.t('login.serverToggle');
  String get protocol => _m.t('login.protocol');
  String get wsAddress => _m.t('login.wsAddress');
  String get gatewayAddress => _m.t('login.gatewayAddress');
  String get gatewayHint => _m.t('login.gatewayHint');
  String get quicAddress => _m.t('login.quicAddress');
  String get transportRace => _m.t('login.transportRace');
  String get wsUrlLabel => _m.t('login.wsUrlLabel');
  String get wsUrlInvalid => _m.t('login.wsUrlInvalid');
  String get loginButton => _m.t('login.loginButton');
  String get userIdHint => _m.t('login.userIdHint');
  String get userIdRequired => _m.t('login.userIdRequired');
  String get advancedWsHint => _m.t('login.advancedWsHint');
  String get footerPrimary => _m.t('login.footerPrimary');
  String get footerSecondary => _m.t('login.footerSecondary');
  String get cancel => _m.t('login.cancel');
  String get connected => _m.t('login.connected');
  String get disconnected => _m.t('login.disconnected');
  String get stagePreparing => _m.t('login.stagePreparing');
  String get stageInitializing => _m.t('login.stageInitializing');
  String get stageConnecting => _m.t('login.stageConnecting');
  String get tokenRejected => _m.t('login.tokenRejected');
}

final class FlareConversationCopy {
  const FlareConversationCopy(this._m);
  final FlareMessages _m;
  String get title => _m.t('conversation.title');
  String get searchPlaceholder => _m.t('conversation.searchPlaceholder');
  String get pinnedSection => _m.t('conversation.pinnedSection');
  String get allSection => _m.t('conversation.allSection');
  String get emptyTitle => _m.t('conversation.emptyTitle');
  String get emptyHint => _m.t('conversation.emptyHint');
  String get startChat => _m.t('conversation.startChat');
  String get emptySearchTitle => _m.t('conversation.emptySearchTitle');
  String get emptySearchHint => _m.t('conversation.emptySearchHint');
  String get filterAll => _m.t('conversation.filterAll');
  String get filterUnread => _m.t('conversation.filterUnread');
  String get filterMention => _m.t('conversation.filterMention');
  String get filterPinned => _m.t('conversation.filterPinned');
  String get filterMuted => _m.t('conversation.filterMuted');
  String get filterArchived => _m.t('conversation.filterArchived');
  String get filterDraft => _m.t('conversation.filterDraft');
  String get draftPrefix => _m.t('conversation.draftPrefix');
  String get noMessagePreview => _m.t('conversation.noMessagePreview');
  String get previewSticker => _m.t('conversation.previewSticker');
  String get previewEmoji => _m.t('conversation.previewEmoji');
  String get currentAccount => _m.t('conversation.currentAccount');
  String get sdkLabSubtitle => _m.t('conversation.sdkLabSubtitle');
  String get language => _m.t('conversation.language');
  String get languageZh => _m.t('conversation.languageZh');
  String get languageEn => _m.t('conversation.languageEn');
}

final class FlareChatCopy {
  const FlareChatCopy(this._m);
  final FlareMessages _m;

  String _fmt(String path, Map<String, Object?> args) {
    var s = _m.t(path);
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  // 连接 / 输入态
  String composerPlaceholder(String name) => _fmt('chat.composerPlaceholder', {'name': name});
  String get send => _m.t('chat.send');
  String get typing => _m.t('chat.typing');
  String get connectionStable => _m.t('chat.connectionStable');
  String get connectionConnecting => _m.t('chat.connectionConnecting');
  String get connectionDisconnected => _m.t('chat.connectionDisconnected');
  String get connectionSendingHint => _m.t('chat.connectionSendingHint');
  String get searchMessages => _m.t('chat.searchMessages');
  String get syncConversation => _m.t('chat.syncConversation');
  String get pullFromServer => _m.t('chat.pullFromServer');
  String get conversationDetails => _m.t('chat.conversationDetails');
  String get multiSelectCount => _m.t('chat.multiSelectCount');
  String get selectTitle => _m.t('chat.selectTitle');
  String get selectHint => _m.t('chat.selectHint');
  String multiSelectCountOf(int count) => _fmt('chat.multiSelectCount', {'count': count});
  String get peerTyping => _m.t('chat.peerTyping');
  String typingMany(int count) => _fmt('chat.typingMany', {'count': count});
  String get online => _m.t('chat.online');
  String get offline => _m.t('chat.offline');
  String get chatTitle => _m.t('chat.chatTitle');
  String get defaultUserName => _m.t('chat.defaultUserName');

  // 消息类型短标签
  String get typeText => _m.t('chat.typeText');
  String get typeImage => _m.t('chat.typeImage');
  String get typeVideo => _m.t('chat.typeVideo');
  String get typeAudio => _m.t('chat.typeAudio');
  String get typeFile => _m.t('chat.typeFile');
  String get typeLocation => _m.t('chat.typeLocation');
  String get typeCard => _m.t('chat.typeCard');
  String get typeSticker => _m.t('chat.typeSticker');
  String get typeEmoji => _m.t('chat.typeEmoji');
  String get typeLink => _m.t('chat.typeLink');
  String get typeMiniProgram => _m.t('chat.typeMiniProgram');
  String get typeForward => _m.t('chat.typeForward');
  String get typeQuote => _m.t('chat.typeQuote');
  String get typeTopic => _m.t('chat.typeTopic');
  String get typeRichText => _m.t('chat.typeRichText');
  String get typeImageGroup => _m.t('chat.typeImageGroup');
  String get typeSystem => _m.t('chat.typeSystem');
  String get typeNotification => _m.t('chat.typeNotification');
  String get typeVote => _m.t('chat.typeVote');
  String get typeTask => _m.t('chat.typeTask');
  String get typeSchedule => _m.t('chat.typeSchedule');
  String get typeAnnouncement => _m.t('chat.typeAnnouncement');
  String get typeCustom => _m.t('chat.typeCustom');
  String get typePlaceholder => _m.t('chat.typePlaceholder');
  String get typeMessage => _m.t('chat.typeMessage');
  String typeUnknown(Object wire) => _fmt('chat.typeUnknown', {'wire': wire});

  // 业务状态
  String get statusUnknown => _m.t('chat.statusUnknown');
  String get statusTodo => _m.t('chat.statusTodo');
  String get statusPending => _m.t('chat.statusPending');
  String get statusInProgress => _m.t('chat.statusInProgress');
  String get statusDone => _m.t('chat.statusDone');
  String get statusClosed => _m.t('chat.statusClosed');
  String get statusCancelled => _m.t('chat.statusCancelled');

  // 送达 / 气泡
  String get sending => _m.t('chat.sending');
  String get read => _m.t('chat.read');
  String get resend => _m.t('chat.resend');
  String get resendUnsupported => _m.t('chat.resendUnsupported');
  String get recalled => _m.t('chat.recalled');
  String get recallExpired => _m.t('chat.recallExpired');
  String get recallWhileSending => _m.t('chat.recallWhileSending');
  String get forwardWhileSending => _m.t('chat.forwardWhileSending');
  String get markedImportant => _m.t('chat.markedImportant');
  String get copied => _m.t('chat.copied');
  String reactionFailed(Object e) => _fmt('chat.reactionFailed', {'e': e});
  String markFailed(Object e) => _fmt('chat.markFailed', {'e': e});

  // 长按菜单
  String get menuReply => _m.t('chat.menuReply');
  String get menuForward => _m.t('chat.menuForward');
  String get menuRecall => _m.t('chat.menuRecall');
  String get menuMultiSelect => _m.t('chat.menuMultiSelect');
  String get menuMark => _m.t('chat.menuMark');
  String get menuCopy => _m.t('chat.menuCopy');
  String get menuEdit => _m.t('chat.menuEdit');
  String get menuSave => _m.t('chat.menuSave');
  String get menuCollapse => _m.t('chat.menuCollapse');
  String get menuDelete => _m.t('chat.menuDelete');
  String get menuDeleteMessage => _m.t('chat.menuDeleteMessage');
  String get menuDeleteSelf => _m.t('chat.menuDeleteSelf');
  String get menuDeleteSelfHint => _m.t('chat.menuDeleteSelfHint');
  String get menuDeleteForAll => _m.t('chat.menuDeleteForAll');
  String get menuDeleteForAllHint => _m.t('chat.menuDeleteForAllHint');
  String get menuPinSelf => _m.t('chat.menuPinSelf');
  String get menuNoActions => _m.t('chat.menuNoActions');
  String get menuPickEmoji => _m.t('chat.menuPickEmoji');
  String get menuNoEmojiAssets => _m.t('chat.menuNoEmojiAssets');
  String get menuNothingToCopy => _m.t('chat.menuNothingToCopy');
  String get pinMessage => _m.t('chat.pinMessage');
  String get unpin => _m.t('chat.unpin');

  // 编辑 / 转发 / 撤回 (屏幕层动作)
  String get editMessage => _m.t('chat.editMessage');
  String get editRichText => _m.t('chat.editRichText');
  String get save => _m.t('chat.save');
  String get close => _m.t('chat.close');
  String get cancel => _m.t('chat.cancel');
  String get forwardSingle => _m.t('chat.forwardSingle');
  String get forwardMerged => _m.t('chat.forwardMerged');
  String forwardMergedCount(int count) => _fmt('chat.forwardMergedCount', {'count': count});
  String forwardMergedTitle(int count) => _fmt('chat.forwardMergedTitle', {'count': count});
  String get forwardMessage => _m.t('chat.forwardMessage');
  String get exitMultiSelect => _m.t('chat.exitMultiSelect');
  String get recallLatestSelf => _m.t('chat.recallLatestSelf');
  String get deleteSelfShort => _m.t('chat.deleteSelfShort');
  String get forwardedToCurrent => _m.t('chat.forwardedToCurrent');
  String get nothingToForward => _m.t('chat.nothingToForward');
  String get sdkMessageType => _m.t('chat.sdkMessageType');
  String get sdkMessageSent => _m.t('chat.sdkMessageSent');
  String get syncRequested => _m.t('chat.syncRequested');
  String forwardFailed(Object e) => _fmt('chat.forwardFailed', {'e': e});
  String deleteFailed(Object e) => _fmt('chat.deleteFailed', {'e': e});
  String sendFailed(Object e) => _fmt('chat.sendFailed', {'e': e});
  String richTextSendFailed(Object e) => _fmt('chat.richTextSendFailed', {'e': e});
  String richTextEditFailed(Object e) => _fmt('chat.richTextEditFailed', {'e': e});
  String quoteSendFailed(Object e) => _fmt('chat.quoteSendFailed', {'e': e});
  String get quoteFallbackPlain => _m.t('chat.quoteFallbackPlain');

  // 录音
  String get holdToRecord => _m.t('chat.holdToRecord');
  String get holdButtonToRecord => _m.t('chat.holdButtonToRecord');
  String get slideUpToCancel => _m.t('chat.slideUpToCancel');
  String get releaseToSend => _m.t('chat.releaseToSend');
  String get releaseToCancel => _m.t('chat.releaseToCancel');
  String get releaseToSendSlideCancel => _m.t('chat.releaseToSendSlideCancel');
  String get pickAudioFile => _m.t('chat.pickAudioFile');
  String get noMicPermission => _m.t('chat.noMicPermission');
  String get recordFailedRetry => _m.t('chat.recordFailedRetry');
  String recordFailed(Object msg) => _fmt('chat.recordFailed', {'msg': msg});
  String get recordPluginNotLoaded => _m.t('chat.recordPluginNotLoaded');

  // 下拉 / 空态
  String get pullToSync => _m.t('chat.pullToSync');
  String get noMessages => _m.t('chat.noMessages');

  // 名片 / 任务 / 日程 表单与卡片
  String get sendCard => _m.t('chat.sendCard');
  String get sendCardDesc => _m.t('chat.sendCardDesc');
  String get sendTask => _m.t('chat.sendTask');
  String get taskCardDesc => _m.t('chat.taskCardDesc');
  String get sendSchedule => _m.t('chat.sendSchedule');
  String get scheduleCardDesc => _m.t('chat.scheduleCardDesc');
  String get displayName => _m.t('chat.displayName');
  String get userId => _m.t('chat.userId');
  String get subtitleLabel => _m.t('chat.subtitleLabel');
  String get avatarUrlOptional => _m.t('chat.avatarUrlOptional');
  String get taskTitleLabel => _m.t('chat.taskTitleLabel');
  String get taskTitleDefault => _m.t('chat.taskTitleDefault');
  String get participantIds => _m.t('chat.participantIds');
  String get commaOrSpaceSeparated => _m.t('chat.commaOrSpaceSeparated');
  String get statusLabel => _m.t('chat.statusLabel');
  String get scheduleTitleLabel => _m.t('chat.scheduleTitleLabel');
  String get scheduleTitleDefault => _m.t('chat.scheduleTitleDefault');
  String get minutesUntilStart => _m.t('chat.minutesUntilStart');
  String get durationMinutes => _m.t('chat.durationMinutes');
  String get latitude => _m.t('chat.latitude');
  String get longitude => _m.t('chat.longitude');
  String mustBeNumber(String label) => _fmt('chat.mustBeNumber', {'label': label});
  String get atLeastOneImageRow => _m.t('chat.atLeastOneImageRow');
  String get voteMinOptions => _m.t('chat.voteMinOptions');

  // 图片 / 图组
  String get originalImage => _m.t('chat.originalImage');
  String originalImageBytes(Object s) => _fmt('chat.originalImageBytes', {'s': s});
  String originalImageKb(Object s) => _fmt('chat.originalImageKb', {'s': s});
  String originalImageMb(Object s) => _fmt('chat.originalImageMb', {'s': s});
  String get imageLoadFailed => _m.t('chat.imageLoadFailed');
  String get cannotShowLocalImage => _m.t('chat.cannotShowLocalImage');
  String get photos => _m.t('chat.photos');
  String photosCount(int total) => _fmt('chat.photosCount', {'total': total});

  // 投票
  String get joinVote => _m.t('chat.joinVote');
  String get startVote => _m.t('chat.startVote');
  String get voteNoId => _m.t('chat.voteNoId');
  String get voteInAppHint => _m.t('chat.voteInAppHint');
  String voteParticipants(int count) => _fmt('chat.voteParticipants', {'count': count});
  String voteOptionsHint(int count) => _fmt('chat.voteOptionsHint', {'count': count});
  String voteParticipantLine(String value) => _fmt('chat.voteParticipantLine', {'value': value});

  // 日程
  String get businessParams => _m.t('chat.businessParams');
  String get meeting => _m.t('chat.meeting');
  String get meetingLink => _m.t('chat.meetingLink');
  String get participationStatus => _m.t('chat.participationStatus');
  String get scheduleReminder => _m.t('chat.scheduleReminder');
  String get viewSchedule => _m.t('chat.viewSchedule');
  String get communicationMeeting => _m.t('chat.communicationMeeting');
  String schedulePrefix(String value) => _fmt('chat.schedulePrefix', {'value': value});
  String scheduleParticipants(String value) => _fmt('chat.scheduleParticipants', {'value': value});

  // 任务
  String get assignTask => _m.t('chat.assignTask');
  String get deadline => _m.t('chat.deadline');
  String get assign => _m.t('chat.assign');
  String get viewTask => _m.t('chat.viewTask');
  String taskPrefix(String value) => _fmt('chat.taskPrefix', {'value': value});
  String deadlinePrefix(String value) => _fmt('chat.deadlinePrefix', {'value': value});
  String assignedTo(String value) => _fmt('chat.assignedTo', {'value': value});

  // 转发详情
  String get noForwardContent => _m.t('chat.noForwardContent');
  String get unknownSender => _m.t('chat.unknownSender');
  String get tapForDetails => _m.t('chat.tapForDetails');
  String get chatHistory => _m.t('chat.chatHistory');
  String get remark => _m.t('chat.remark');
  String remarkPrefix(String value) => _fmt('chat.remarkPrefix', {'value': value});
  String forwardTotalMessages(int total) => _fmt('chat.forwardTotalMessages', {'total': total});
  String forwardMore(int more) => _fmt('chat.forwardMore', {'more': more});

  // 公告 / 通知 / 小程序 / 位置 / 链接 / 文件
  String get groupAnnouncement => _m.t('chat.groupAnnouncement');
  String get publishedByOwner => _m.t('chat.publishedByOwner');
  String get viewDetails => _m.t('chat.viewDetails');
  String announcementA11y(String value) => _fmt('chat.announcementA11y', {'value': value});
  String get systemNotification => _m.t('chat.systemNotification');
  String get miniProgramWip => _m.t('chat.miniProgramWip');
  String miniProgramWipId(Object id) => _fmt('chat.miniProgramWipId', {'id': id});
  String get tapToOpenMiniProgram => _m.t('chat.tapToOpenMiniProgram');
  String get cannotOpenMap => _m.t('chat.cannotOpenMap');
  String get cannotOpenLink => _m.t('chat.cannotOpenLink');
  String get attachment => _m.t('chat.attachment');

  // 保存到本机
  String get saving => _m.t('chat.saving');
  String savedTo(String location) => _fmt('chat.savedTo', {'location': location});
  String get saveFailed => _m.t('chat.saveFailed');
  String get showInFolder => _m.t('chat.showInFolder');

  // 内容占位标签
  String get richTextTag => _m.t('chat.richTextTag');
  String get topicTagPlain => _m.t('chat.topicTagPlain');
  String topicTag(String value) => _fmt('chat.topicTag', {'value': value});
  String get imageGroupTag => _m.t('chat.imageGroupTag');
  String get placeholderTag => _m.t('chat.placeholderTag');

  // 时间格式
  String yesterdayAt(String hm) => _fmt('chat.yesterdayAt', {'hm': hm});
  String dateMonthDayAt(Object month, Object day, String hm) =>
      _fmt('chat.dateMonthDayAt', {'month': month, 'day': day, 'hm': hm});
  String dateFullAt(Object year, Object month, Object day, String hm) =>
      _fmt('chat.dateFullAt', {'year': year, 'month': month, 'day': day, 'hm': hm});
}

final class FlareComposerCopy {
  const FlareComposerCopy(this._m);
  final FlareMessages _m;

  String _fmt(String path, Map<String, Object?> args) {
    var s = _m.t(path);
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  // 输入行 / 引用条
  String hint(String name) => _fmt('composer.hint', {'name': name});
  String get multilineHint => _m.t('composer.multilineHint');
  String get expandInput => _m.t('composer.expandInput');
  String get collapse => _m.t('composer.collapse');
  String get cancelReply => _m.t('composer.cancelReply');
  String replyTo(String name) => _fmt('composer.replyTo', {'name': name});
  String get send => _m.t('composer.send');

  // 工具栏 / 附件动作
  String get more => _m.t('composer.more');
  String get mention => _m.t('composer.mention');
  String get richText => _m.t('composer.richText');
  String get voice => _m.t('composer.voice');
  String get image => _m.t('composer.image');
  String get video => _m.t('composer.video');
  String get file => _m.t('composer.file');
  String get emojiSticker => _m.t('composer.emojiSticker');
  String get emojiStickerDesc => _m.t('composer.emojiStickerDesc');
  String get album => _m.t('composer.album');
  String get imageAndVideo => _m.t('composer.imageAndVideo');
  String get albumImageVideo => _m.t('composer.albumImageVideo');
  String get folder => _m.t('composer.folder');
  String get localFile => _m.t('composer.localFile');
  String get localFolder => _m.t('composer.localFolder');
  String get sendMessage => _m.t('composer.sendMessage');
  String get emojiNotWired => _m.t('composer.emojiNotWired');
  String get attachNotWired => _m.t('composer.attachNotWired');
  String get insertNotWired => _m.t('composer.insertNotWired');
  String inDev(String name) => _fmt('composer.inDev', {'name': name});
  String placeholderName(String name) => _fmt('composer.placeholderName', {'name': name});
  String placeholderLabel(String label) => _fmt('composer.placeholderLabel', {'label': label});

  // 表情选择器
  String get emojiSearchHint => _m.t('composer.emojiSearchHint');
  String get emojiAssetsMissing => _m.t('composer.emojiAssetsMissing');
  String get frequentlyUsed => _m.t('composer.frequentlyUsed');
  String get defaultEmoji => _m.t('composer.defaultEmoji');
  String get noWebpInPack => _m.t('composer.noWebpInPack');
  String get moreEmojiPacks => _m.t('composer.moreEmojiPacks');
  String get customEmojiPackPlaceholder => _m.t('composer.customEmojiPackPlaceholder');

  // 富文本格式
  String get indent => _m.t('composer.indent');
  String get increaseIndent => _m.t('composer.increaseIndent');
  String get decreaseIndent => _m.t('composer.decreaseIndent');
  String get bold => _m.t('composer.bold');
  String get italic => _m.t('composer.italic');
  String get strike => _m.t('composer.strike');
  String get inlineCode => _m.t('composer.inlineCode');
  String get codeBlock => _m.t('composer.codeBlock');
  String get heading => _m.t('composer.heading');
  String get quote => _m.t('composer.quote');
  String get bulletList => _m.t('composer.bulletList');
  String get orderedList => _m.t('composer.orderedList');
  String get link => _m.t('composer.link');

  // 业务消息类型（附件构建入口）
  String get location => _m.t('composer.location');
  String get contact => _m.t('composer.contact');
  String get schedule => _m.t('composer.schedule');
  String get task => _m.t('composer.task');
  String get vote => _m.t('composer.vote');
  String get miniProgram => _m.t('composer.miniProgram');
  String get topic => _m.t('composer.topic');
  String get notification => _m.t('composer.notification');
  String get announcement => _m.t('composer.announcement');

  // SDK 消息构建 sheet
  String get sdkMessageType => _m.t('composer.sdkMessageType');
  String get sdkMessageDesc => _m.t('composer.sdkMessageDesc');
  String get close => _m.t('composer.close');
  String get messageType => _m.t('composer.messageType');
  String get cancel => _m.t('composer.cancel');
  String get createAndSend => _m.t('composer.createAndSend');

  // SDK 构建目录:分组
  String get catGroupBase => _m.t('composer.catGroupBase');
  String get catGroupCardLink => _m.t('composer.catGroupCardLink');
  String get catGroupBusiness => _m.t('composer.catGroupBusiness');
  String get catGroupOther => _m.t('composer.catGroupOther');

  // SDK 构建目录:条目标签(中文部分 + 保留英文枚举名)
  String get catThreadReply => _m.t('composer.catThreadReply');
  String get catImageGroup => _m.t('composer.catImageGroup');
  String get catLocation => _m.t('composer.catLocation');
  String get catCard => _m.t('composer.catCard');
  String get catSticker => _m.t('composer.catSticker');
  String get catLinkCard => _m.t('composer.catLinkCard');
  String get catMiniProgram => _m.t('composer.catMiniProgram');
  String get catNotification => _m.t('composer.catNotification');
  String get catVote => _m.t('composer.catVote');
  String get catTask => _m.t('composer.catTask');
  String get catSchedule => _m.t('composer.catSchedule');
  String get catAnnouncement => _m.t('composer.catAnnouncement');
  String get catCustom => _m.t('composer.catCustom');
  String get catPlaceholder => _m.t('composer.catPlaceholder');

  // SDK 构建目录:字段标签 / 占位
  String get fieldBody => _m.t('composer.fieldBody');
  String get fieldImageUrls => _m.t('composer.fieldImageUrls');
  String get fieldImageUrlsHint => _m.t('composer.fieldImageUrlsHint');
  String get fieldDescOptional => _m.t('composer.fieldDescOptional');
  String get fieldMetadata => _m.t('composer.fieldMetadata');
  String get fieldMetadataHint => _m.t('composer.fieldMetadataHint');
  String get fieldLongitude => _m.t('composer.fieldLongitude');
  String get fieldLatitude => _m.t('composer.fieldLatitude');
  String get fieldTitle => _m.t('composer.fieldTitle');
  String get fieldAddress => _m.t('composer.fieldAddress');
  String get fieldMapZoomOptional => _m.t('composer.fieldMapZoomOptional');
  String get fieldSnapshotUrlOptional => _m.t('composer.fieldSnapshotUrlOptional');
  String get fieldSnapshotPathOptional => _m.t('composer.fieldSnapshotPathOptional');
  String get fieldUrlOptional => _m.t('composer.fieldUrlOptional');
  String get fieldExtra => _m.t('composer.fieldExtra');
  String get fieldExtraHint => _m.t('composer.fieldExtraHint');
  String get fieldOptionsPerLine => _m.t('composer.fieldOptionsPerLine');
  String get fieldParticipants => _m.t('composer.fieldParticipants');
  String get fieldStartAfterMinutes => _m.t('composer.fieldStartAfterMinutes');
  String get fieldDurationMinutes => _m.t('composer.fieldDurationMinutes');
  String get fieldBusinessType => _m.t('composer.fieldBusinessType');
  String get scheduleProtoHint => _m.t('composer.scheduleProtoHint');
}

final class FlareConnectionCopy {
  const FlareConnectionCopy(this._m);
  final FlareMessages _m;
  String get syncConversations => _m.t('connection.syncConversations');
  String get syncDetail => _m.t('connection.syncDetail');
  String get reconnecting => _m.t('connection.reconnecting');
  String get disconnected => _m.t('connection.disconnected');
  String get retryHint => _m.t('connection.retryHint');
}

final class FlareSettingsCopy {
  const FlareSettingsCopy(this._m);
  final FlareMessages _m;
  String get title => _m.t('settings.title');
  String get appearance => _m.t('settings.appearance');
  String get language => _m.t('settings.language');
  String get themeSystem => _m.t('settings.themeSystem');
  String get themeLight => _m.t('settings.themeLight');
  String get themeDark => _m.t('settings.themeDark');
  String get storage => _m.t('settings.storage');
  String get downloadLocation => _m.t('settings.downloadLocation');
  String get downloadLocationChange => _m.t('settings.downloadLocationChange');
  String get downloadLocationReset => _m.t('settings.downloadLocationReset');
  String get downloadLocationFilesApp => _m.t('settings.downloadLocationFilesApp');
  String get downloadLocationUnwritable => _m.t('settings.downloadLocationUnwritable');
  String get downloadLocationUnavailable => _m.t('settings.downloadLocationUnavailable');
  String get mediaCache => _m.t('settings.mediaCache');
  String get notMeasured => _m.t('settings.notMeasured');
  String get clearCache => _m.t('settings.clearCache');
  String get clearCacheConfirm => _m.t('settings.clearCacheConfirm');
  String get cacheCleared => _m.t('settings.cacheCleared');
  String get clearCacheFailed => _m.t('settings.clearCacheFailed');
}

final class FlareSdkLabCopy {
  const FlareSdkLabCopy(this._m);
  final FlareMessages _m;
  String get title => _m.t('sdkLab.title');
  String get refresh => _m.t('sdkLab.refresh');
  String get tabDiagnostics => _m.t('sdkLab.tabDiagnostics');
  String get tabEvents => _m.t('sdkLab.tabEvents');
  String get tabMedia => _m.t('sdkLab.tabMedia');
  String get tabCapabilityCall => _m.t('sdkLab.tabCapabilityCall');
  String get clear => _m.t('sdkLab.clear');
  String get eventsEmpty => _m.t('sdkLab.eventsEmpty');
  String get builderEmpty => _m.t('sdkLab.builderEmpty');
  String get clearCache => _m.t('sdkLab.clearCache');
  String get setCacheLimit => _m.t('sdkLab.setCacheLimit');
  String get downloadDir => _m.t('sdkLab.downloadDir');
  String get setLabDir => _m.t('sdkLab.setLabDir');
  String get uploadFile => _m.t('sdkLab.uploadFile');
  String get uploadImage => _m.t('sdkLab.uploadImage');
  String get uploadVideo => _m.t('sdkLab.uploadVideo');
  String get uploadBytes => _m.t('sdkLab.uploadBytes');
  String get pickSourceFile => _m.t('sdkLab.pickSourceFile');
  String get downloadSave => _m.t('sdkLab.downloadSave');
  String get querySavePath => _m.t('sdkLab.querySavePath');
  String get cancelDownload => _m.t('sdkLab.cancelDownload');
  String get deleteRecord => _m.t('sdkLab.deleteRecord');
  String get queryCurrentUser => _m.t('sdkLab.queryCurrentUser');
  String get batchQuery => _m.t('sdkLab.batchQuery');
  String get subscribePresence => _m.t('sdkLab.subscribePresence');
  String get runTemplate => _m.t('sdkLab.runTemplate');
  String get syncConversationSummary => _m.t('sdkLab.syncConversationSummary');
  String get rawConversation => _m.t('sdkLab.rawConversation');
  String get pagedConversation => _m.t('sdkLab.pagedConversation');
  String get noCommandFailures => _m.t('sdkLab.noCommandFailures');
  String get uploadHint => _m.t('sdkLab.uploadHint');
}

final class FlareSearchCopy {
  const FlareSearchCopy(this._m);
  final FlareMessages _m;
  String get title => _m.t('search.title');
  String get inConversation => _m.t('search.inConversation');
  String get global => _m.t('search.global');
  String get keywordHint => _m.t('search.keywordHint');
  String get searchButton => _m.t('search.searchButton');
  String get filterLabel => _m.t('search.filterLabel');
  String get filterAll => _m.t('search.filterAll');
  String get filterText => _m.t('search.filterText');
  String get filterMedia => _m.t('search.filterMedia');
  String get filterImage => _m.t('search.filterImage');
  String get filterVideo => _m.t('search.filterVideo');
  String get filterAudio => _m.t('search.filterAudio');
  String get filterFile => _m.t('search.filterFile');
  String get noResults => _m.t('search.noResults');
  String resultCount(int n) =>
      _m.t('search.resultCount').replaceAll('{count}', '$n');
  String get openInChat => _m.t('search.openInChat');
}

final class FlareDetailsCopy {
  const FlareDetailsCopy(this._m);
  final FlareMessages _m;
  String get title => _m.t('details.title');
  String get emptyTitle => _m.t('details.emptyTitle');
  String get emptyHint => _m.t('details.emptyHint');
  String get sync => _m.t('details.sync');
  String get markRead => _m.t('details.markRead');
  String get markUnread => _m.t('details.markUnread');
  String get pin => _m.t('details.pin');
  String get unpin => _m.t('details.unpin');
  String get mute => _m.t('details.mute');
  String get unmute => _m.t('details.unmute');
  String get archive => _m.t('details.archive');
  String get unarchive => _m.t('details.unarchive');
  String get clearHistory => _m.t('details.clearHistory');
  String get delete => _m.t('details.delete');
  String get statusSection => _m.t('details.statusSection');
  String get extensions => _m.t('details.extensions');
  String get openSdkLab => _m.t('details.openSdkLab');
  String get pinTag => _m.t('details.pinTag');
  String get muteTag => _m.t('details.muteTag');
  String get archivedTag => _m.t('details.archivedTag');
  String membersCount(int n) =>
      _m.t('details.membersCount').replaceAll('{count}', '$n');
}

const _catalog = <FlareLocale, Map<String, dynamic>>{
  FlareLocale.zhCn: {
    'nav': {
      'login': '登录',
      'conversations': '消息',
      'sdkLab': 'SDK 能力中心',
      'settings': '设置',
    },
    'login': {
      'brandTitle': 'flare IM',
      'brandSubtitle': '安全、快速的即时通讯',
      'welcomeTitle': '欢迎回来',
      'welcomeHint': '请输入您的用户 ID 完成登录',
      'userIdLabel': '用户 ID',
      'userIdPlaceholder': '请输入用户 ID',
      'userIdHint': '用户 ID 由系统分配，可在账号设置中查看',
      'userIdRequired': '请输入用户 ID',
      'serverToggle': '服务器地址',
      'protocol': '连接协议',
      'wsAddress': 'WebSocket 地址',
      'gatewayAddress': 'Gateway 地址',
      'gatewayHint': 'SDK 通过该网关签发并自动刷新接入 token',
      'quicAddress': 'QUIC 地址',
      'transportRace': '竞速',
      'wsUrlLabel': 'WebSocket',
      'wsUrlInvalid':
          '请输入 access-gateway 的 WebSocket 地址，例如 ws://127.0.0.1:60051/ws',
      'advancedWsHint': '留空则使用配置文件中的默认地址',
      'loginButton': '立即登录',
      'footerPrimary': 'ID 由管理员分配，可在邀请邮件中查看',
      'footerSecondary': '仅支持 ID 登录 · 安全连接已启用',
      'cancel': '取消',
      'connected': '已连接',
      'disconnected': '未连接',
      'stagePreparing': '正在准备 SDK 运行环境',
      'stageInitializing': '正在初始化 SDK 和本地数据库',
      'stageConnecting': '正在登录并建立实时连接',
      'tokenRejected': '接入 Token 被服务端拒绝：签名密钥或签发者与服务端不一致，或 Token 已过期。请核对「签名密钥」后重试。',
    },
    'conversation': {
      'clearSearch': '清空',
      'homeSnapshot': 'Core 首页快照',
      'homeSnapshotDesc': '通过 bootstrapHomeTimeline 重建会话列表',
      'homeSnapshotLoaded': '已加载 Core 首页快照：{count} 个会话',
      'batchSync': '批量同步会话',
      'batchSyncDesc': '通过 core sync 后重载会话视图',
      'batchSyncHint': '多个 id 用逗号、空格或换行分隔',
      'synced': '已同步 {count} 个会话',
      'profile': '个人资料',
      'profileDesc': '账号资料与在线状态',
      'profileTodo': '个人资料能力待接入',
      'logout': '退出登录',
      'logoutDesc': '断开 SDK 会话并回到登录页',
      'logoutConfirm': '确定要退出登录吗？',
      'notFound': '未找到会话（请检查 userId / 权限）',
      'emptyCid': '会话创建返回空 conversationId，请检查 SDK 响应',
      'invalidConv': 'SDK 返回了无效会话，请清理空 conversationId 数据后重试',
      'openFailed': '打开会话失败，请检查 userId / 权限 / SDK 状态',
      'cancel': '取消',
      'confirm': '确定',
      'refresh': '刷新',
      'startTitle': '打开会话',
      'typeLabel': '会话类型',
      'direct': '单聊',
      'group': '群聊',
      'memberIds': '成员 userId',
      'peerHint': '单聊填对方 userId',
      'membersHint': '群聊填多个 userId，用逗号、空格或换行分隔',
      'groupName': '群名称（可选）',
      'groupNameHint': '例如 Flutter SDK Lab',
      'open': '打开',
      'notLoggedIn': '未登录',
      'untitled': '会话',
      'openA11y': '打开会话',
      'unpin': '取消置顶',
      'pin': '置顶',
      'delete': '删除',
      'a11yConv': '会话 {title}',
      'selected': '已选中',
      'pinnedA11y': '已置顶',
      'unreadCount': '未读 {count} 条',
      'mentionPrefix': '@我 ',
      'syncThis': '同步此会话',
      'syncedThis': '已同步会话',
      'deleteConv': '删除会话',
      'deleteConfirm': '确定要删除此会话吗？',
      'yesterday': '昨天',
      'weekdays': '周一,周二,周三,周四,周五,周六,周日',
      'title': '消息',
      'searchPlaceholder': '搜索会话、消息预览或用户 ID',
      'pinnedSection': '置顶',
      'allSection': '全部',
      'emptyTitle': '暂无会话',
      'emptyHint': '下拉刷新，或发起一个新的单聊 / 群聊',
      'startChat': '发起会话',
      'emptySearchTitle': '无匹配会话',
      'emptySearchHint': '换个关键词再试试',
      'filterAll': '全部',
      'filterUnread': '未读',
      'filterMention': '@我',
      'filterPinned': '置顶',
      'filterMuted': '免打扰',
      'filterArchived': '归档',
      'filterDraft': '草稿',
      'draftPrefix': '草稿：',
      'noMessagePreview': '暂无消息',
      'previewSticker': '贴纸',
      'previewEmoji': '表情',
      'currentAccount': '当前登录账号',
      'sdkLabSubtitle': '查看连接、能力、媒体缓存和诊断信息',
      'language': '界面语言',
      'languageZh': '简体中文',
      'languageEn': 'English',
    },
    'chat': {
      'composerPlaceholder': '发送给 {name}',
      'send': '发送',
      'typing': '正在输入…',
      'connectionStable': '连接稳定 · 已同步',
      'connectionConnecting': '连接中…',
      'connectionDisconnected': '连接已断开 · 将自动重试',
      'connectionSendingHint': '发送中的消息会在连接就绪后继续',
      'searchMessages': '搜索消息',
      'syncConversation': '同步会话',
      'pullFromServer': '从服务端拉取',
      'conversationDetails': '会话详情',
      'multiSelectCount': '已选择 {count} 条',
      'selectTitle': '选择一个会话',
      'selectHint': '从左侧列表打开聊天，或点击加号发起新会话',
      'peerTyping': '对方正在输入…',
      'typingMany': '{count} 人正在输入…',
      'online': '在线',
      'offline': '离线',
      'chatTitle': '聊天',
      'defaultUserName': 'Flare IM 用户',
      'typeText': '文本',
      'typeImage': '图片',
      'typeVideo': '视频',
      'typeAudio': '语音',
      'typeFile': '文件',
      'typeLocation': '位置',
      'typeCard': '名片',
      'typeSticker': '贴纸',
      'typeEmoji': '表情',
      'typeLink': '链接',
      'typeMiniProgram': '小程序',
      'typeForward': '转发',
      'typeQuote': '回复',
      'typeTopic': '话题',
      'typeRichText': '富文本',
      'typeImageGroup': '图组',
      'typeSystem': '系统',
      'typeNotification': '通知',
      'typeVote': '投票',
      'typeTask': '任务',
      'typeSchedule': '日程',
      'typeAnnouncement': '公告',
      'typeCustom': '自定义',
      'typePlaceholder': '占位',
      'typeMessage': '消息',
      'typeUnknown': '类型 {wire}',
      'statusUnknown': '状态未知',
      'statusTodo': '待办',
      'statusPending': '待处理',
      'statusInProgress': '进行中',
      'statusDone': '已完成',
      'statusClosed': '已关闭',
      'statusCancelled': '已取消',
      'sending': '发送中…',
      'read': '已读',
      'resend': '重发',
      'resendUnsupported': '该消息类型暂不支持重发',
      'recalled': '消息已撤回',
      'recallExpired': '已超过可撤回时间',
      'recallWhileSending': '发送中，请稍后再试撤回',
      'forwardWhileSending': '发送中，暂不可转发',
      'markedImportant': '已标记为重要',
      'copied': '已复制',
      'reactionFailed': '反应失败：{e}',
      'markFailed': '标记失败：{e}',
      'menuReply': '回复',
      'menuForward': '转发',
      'menuRecall': '撤回',
      'menuMultiSelect': '多选',
      'menuMark': '标记',
      'menuCopy': '复制',
      'menuEdit': '编辑',
      'menuSave': '保存',
      'menuCollapse': '收起',
      'menuDelete': '删除',
      'menuDeleteMessage': '删除消息',
      'menuDeleteSelf': '仅为自己删除',
      'menuDeleteSelfHint': '其它成员仍可见',
      'menuDeleteForAll': '为所有人删除',
      'menuDeleteForAllHint': '从会话中移除该消息',
      'menuPinSelf': '仅自己置顶',
      'menuNoActions': '暂无可执行操作',
      'menuPickEmoji': '选择表情',
      'menuNoEmojiAssets': '未发现 assets/emoji 资源',
      'menuNothingToCopy': '没有可复制的内容',
      'pinMessage': '置顶消息',
      'unpin': '取消置顶',
      'editMessage': '编辑消息',
      'editRichText': '编辑富文本',
      'save': '保存',
      'close': '关闭',
      'cancel': '取消',
      'forwardSingle': '单条转发',
      'forwardMerged': '合并转发',
      'forwardMergedCount': '合并转发 {count} 条',
      'forwardMergedTitle': '合并转发（{count} 条）',
      'forwardMessage': '转发消息',
      'exitMultiSelect': '退出多选',
      'recallLatestSelf': '撤回最近一条（自己）',
      'deleteSelfShort': '仅自己删除',
      'forwardedToCurrent': '已转发到当前会话',
      'nothingToForward': '没有可转发的消息',
      'sdkMessageType': 'SDK 消息类型',
      'sdkMessageSent': '已发送 SDK 消息',
      'syncRequested': '已请求同步会话',
      'forwardFailed': '转发失败：{e}',
      'deleteFailed': '删除失败：{e}',
      'sendFailed': '发送失败：{e}',
      'richTextSendFailed': '富文本发送失败：{e}',
      'richTextEditFailed': '富文本编辑失败：{e}',
      'quoteSendFailed': '引用发送失败：{e}',
      'quoteFallbackPlain': '原消息已不可用，已按纯文本发送',
      'holdToRecord': '按住录音',
      'holdButtonToRecord': '请长按按钮开始录音',
      'slideUpToCancel': '上滑取消录音',
      'releaseToSend': '松开发送',
      'releaseToCancel': '松开取消',
      'releaseToSendSlideCancel': '松开发送，上滑取消',
      'pickAudioFile': '选择音频文件',
      'noMicPermission': '没有麦克风权限',
      'recordFailedRetry': '录音失败，请稍后重试',
      'recordFailed': '录音失败：{msg}',
      'recordPluginNotLoaded': '录音插件未正确加载，请重新构建后再试',
      'pullToSync': '下拉同步',
      'noMessages': '暂无消息',
      'sendCard': '发送名片',
      'sendCardDesc': '发送联系人资料，便于对方快速识别',
      'sendTask': '发送任务',
      'taskCardDesc': '创建一个待办任务卡片并发送到会话',
      'sendSchedule': '发送日程',
      'scheduleCardDesc': '创建一条会议或提醒日程并同步给成员',
      'displayName': '显示名称',
      'userId': '用户 ID',
      'subtitleLabel': '副标题',
      'avatarUrlOptional': '头像 URL（可选）',
      'taskTitleLabel': '任务标题',
      'taskTitleDefault': '跟进本次沟通',
      'participantIds': '参与人 ID',
      'commaOrSpaceSeparated': '用逗号或空格分隔',
      'statusLabel': '状态',
      'scheduleTitleLabel': '日程标题',
      'scheduleTitleDefault': '沟通会议',
      'minutesUntilStart': '多少分钟后开始',
      'durationMinutes': '持续分钟数',
      'latitude': '纬度',
      'longitude': '经度',
      'mustBeNumber': '{label} 必须为数字',
      'atLeastOneImageRow': '请至少填写一行图片',
      'voteMinOptions': '投票至少需要 2 个选项',
      'originalImage': '原图',
      'originalImageBytes': '原图 {s}B',
      'originalImageKb': '原图 {s}KB',
      'originalImageMb': '原图 {s}MB',
      'imageLoadFailed': '图片加载失败',
      'cannotShowLocalImage': '无法显示本地路径图片',
      'photos': '照片',
      'photosCount': '{total} 张照片',
      'joinVote': '参与投票',
      'startVote': '发起投票',
      'voteNoId': '暂无法打开投票（缺少 voteId）',
      'voteInAppHint': '选项与投票请在 App 内完成',
      'voteParticipants': '{count} 人参与',
      'voteOptionsHint': '共 {count} 个选项 · 在 App 内完成选择',
      'voteParticipantLine': '参与人 · {value}',
      'businessParams': '业务参数',
      'meeting': '会议',
      'meetingLink': '会议链接',
      'participationStatus': '参与状态',
      'scheduleReminder': '日程提醒',
      'viewSchedule': '查看日程',
      'communicationMeeting': '沟通会议',
      'schedulePrefix': '日程：{value}',
      'scheduleParticipants': '参与人 · {value}',
      'assignTask': '分配任务',
      'deadline': '截止',
      'assign': '指派',
      'viewTask': '查看任务',
      'taskPrefix': '任务：{value}',
      'deadlinePrefix': '截止：{value}',
      'assignedTo': '指派给：{value}',
      'noForwardContent': '暂无转发内容',
      'unknownSender': '未知发送者',
      'tapForDetails': '点击查看详情',
      'chatHistory': '聊天记录',
      'remark': '附言 ',
      'remarkPrefix': '附言 {value}',
      'forwardTotalMessages': '共 {total} 条消息',
      'forwardMore': '还有 {more} 条消息…',
      'groupAnnouncement': '群公告',
      'publishedByOwner': '群主 发布',
      'viewDetails': '查看详情',
      'announcementA11y': '公告：{value}',
      'systemNotification': '系统通知',
      'miniProgramWip': '打开小程序功能开发中',
      'miniProgramWipId': '打开小程序（{id}）功能开发中',
      'tapToOpenMiniProgram': '点击打开小程序 →',
      'cannotOpenMap': '无法打开地图',
      'cannotOpenLink': '无法打开链接',
      'attachment': '附件',
      'saving': '正在保存…',
      'savedTo': '已保存到 {location}',
      'saveFailed': '没有保存成功，请重试',
      'showInFolder': '在文件夹中显示',
      'richTextTag': '[富文本]',
      'topicTagPlain': '[话题]',
      'topicTag': '[话题] {value}',
      'imageGroupTag': '[图片组]',
      'placeholderTag': '[占位]',
      'yesterdayAt': '昨天 {hm}',
      'dateMonthDayAt': '{month}月{day}日 {hm}',
      'dateFullAt': '{year}年{month}月{day}日 {hm}',
    },
    'composer': {
      'hint': '发送给 {name}',
      'multilineHint': '多行模式 · 发送键或回车发送，Shift+回车换行',
      'expandInput': '展开输入',
      'collapse': '收起',
      'cancelReply': '取消回复',
      'replyTo': '回复 {name}:',
      'send': '发送',
      'more': '更多功能',
      'mention': '@提及',
      'richText': '富文本',
      'voice': '语音',
      'image': '图片',
      'video': '视频',
      'file': '文件',
      'emojiSticker': '表情与贴纸',
      'emojiStickerDesc': '来自 assets/emoji 与 assets/stickers',
      'album': '相册',
      'imageAndVideo': '图片与视频',
      'albumImageVideo': '相册（图片与视频）',
      'folder': '文件夹',
      'localFile': '本地文件',
      'localFolder': '本地文件夹',
      'sendMessage': '发消息',
      'emojiNotWired': '表情（未接入）',
      'attachNotWired': '附件（未接入）',
      'insertNotWired': '插入（未接入）',
      'inDev': '{name}（开发中）',
      'placeholderName': '{name}（占位）',
      'placeholderLabel': '{label}（占位）',
      'emojiSearchHint': '输入或选择表情',
      'emojiAssetsMissing':
          '未在打包资源中发现 assets/emoji/*.webp。\n请确认 pubspec 已声明 assets/emoji/ 且目录内有文件。',
      'frequentlyUsed': '最常使用',
      'defaultEmoji': '默认表情',
      'noWebpInPack': '当前分包下无 .webp 资源',
      'moreEmojiPacks': '更多表情包',
      'customEmojiPackPlaceholder': '自定义表情包（占位）',
      'indent': '缩进',
      'increaseIndent': '增加缩进',
      'decreaseIndent': '减少缩进',
      'bold': '加粗',
      'italic': '斜体',
      'strike': '删除线',
      'inlineCode': '行内代码',
      'codeBlock': '代码块',
      'heading': '标题',
      'quote': '引用',
      'bulletList': '无序列表',
      'orderedList': '有序列表',
      'link': '链接',
      'location': '位置',
      'contact': '名片',
      'schedule': '日程',
      'task': '任务',
      'vote': '投票',
      'miniProgram': '小程序',
      'topic': '话题',
      'notification': '通知',
      'announcement': '公告',
      'sdkMessageType': 'SDK 消息类型',
      'sdkMessageDesc': '发送 Composer 主流程之外的保留消息能力',
      'close': '关闭',
      'messageType': '消息类型',
      'cancel': '取消',
      'createAndSend': '创建并发送',
      'catGroupBase': '基础',
      'catGroupCardLink': '卡片与链接',
      'catGroupBusiness': '业务',
      'catGroupOther': '其它',
      'catThreadReply': '线程 THREAD',
      'catImageGroup': '多图 IMAGE_GROUP',
      'catLocation': '位置 LOCATION',
      'catCard': '名片 CARD',
      'catSticker': '贴纸 STICKER',
      'catLinkCard': '链接卡片 LINK_CARD',
      'catMiniProgram': '小程序 MINI_PROGRAM',
      'catNotification': '通知 NOTIFICATION',
      'catVote': '投票 POLL',
      'catTask': '任务 TASK',
      'catSchedule': '日程 SCHEDULE',
      'catAnnouncement': '公告 ANNOUNCEMENT',
      'catCustom': '自定义 CUSTOM',
      'catPlaceholder': '占位 PLACEHOLDER',
      'fieldBody': '正文',
      'fieldImageUrls': '图片 URL / imageId',
      'fieldImageUrlsHint': '输入真实图片 URL 或 imageId',
      'fieldDescOptional': '说明（可选）',
      'fieldMetadata': 'metadata（每行 key: value）',
      'fieldMetadataHint': 'albumId: <真实相册 ID>',
      'fieldLongitude': '经度',
      'fieldLatitude': '纬度',
      'fieldTitle': '标题',
      'fieldAddress': '详细地址',
      'fieldMapZoomOptional': '地图缩放（可选）',
      'fieldSnapshotUrlOptional': '快照 URL（可选）',
      'fieldSnapshotPathOptional': '本地快照路径（可选）',
      'fieldUrlOptional': 'url（可选）',
      'fieldExtra': 'extra（每行 key: value）',
      'fieldExtraHint': '输入真实扩展字段，每行 key: value',
      'fieldOptionsPerLine': '选项（每行一个）',
      'fieldParticipants': '参与人 ID（逗号/换行分隔）',
      'fieldStartAfterMinutes': '多少分钟后开始',
      'fieldDurationMinutes': '持续分钟数',
      'fieldBusinessType': '业务 type 字符串',
      'scheduleProtoHint': '82 SCHEDULE · start/end 毫秒',
    },
    'connection': {
      'syncConversations': '正在同步会话',
      'syncDetail': '连接建立后会继续同步离线数据',
      'reconnecting': '正在重连服务器',
      'disconnected': '连接已断开',
      'retryHint': '请检查服务地址和网络状态',
    },
    'settings': {
      'title': '设置',
      'appearance': '外观',
      'language': '语言',
      'themeSystem': '跟随系统',
      'themeLight': '浅色',
      'themeDark': '深色',
      'storage': '存储',
      'downloadLocation': '下载位置',
      'downloadLocationChange': '更改位置',
      'downloadLocationReset': '恢复默认位置',
      'downloadLocationFilesApp': '「文件」App › 本应用 › flare',
      'downloadLocationUnwritable': '这个文件夹不能写入，请换一个',
      'downloadLocationUnavailable': '暂时读不到下载位置，请稍后再试',
      'mediaCache': '图片与文件缓存',
      'notMeasured': '未统计',
      'clearCache': '清除缓存',
      'clearCacheConfirm': '清除后，看过的图片需要重新下载。',
      'cacheCleared': '缓存已清除',
      'clearCacheFailed': '缓存没有清除，请重试',
    },
    'sdkLab': {
      'title': 'SDK 能力中心',
      'refresh': '刷新',
      'tabDiagnostics': '诊断',
      'tabEvents': '事件',
      'tabMedia': '媒体',
      'tabCapabilityCall': '能力/通话',
      'clear': '清空',
      'eventsEmpty': '暂无事件。登录、同步、发送消息或执行 Lab 操作后会记录。',
      'builderEmpty': '暂无 builder catalog，刷新后查看 SDK 返回的构建能力。',
      'clearCache': '清理缓存',
      'setCacheLimit': '设 256MB 上限',
      'downloadDir': '下载目录',
      'setLabDir': '设 Lab 目录',
      'uploadFile': '上传文件',
      'uploadImage': '上传图片',
      'uploadVideo': '上传视频',
      'uploadBytes': '上传 Bytes',
      'pickSourceFile': '选择源文件',
      'downloadSave': '下载/保存',
      'querySavePath': '查询保存路径',
      'cancelDownload': '取消下载',
      'deleteRecord': '删除记录',
      'queryCurrentUser': '查询当前用户',
      'batchQuery': '批量查询',
      'subscribePresence': '订阅 Presence',
      'runTemplate': '执行模板',
      'syncConversationSummary': '同步会话摘要',
      'rawConversation': 'Raw 会话',
      'pagedConversation': '分页会话',
      'noCommandFailures': '暂无命令失败。',
      'uploadHint':
          '文件上传请先确认已登录且 SDK 已初始化；下载/保存至少提供 source_path、source_url 或 remoteFileId 之一。',
    },
    'search': {
      'title': '搜索消息',
      'inConversation': '当前会话',
      'global': '全部会话',
      'keywordHint': '输入关键词',
      'searchButton': '搜索',
      'filterLabel': '搜索类型',
      'filterAll': '全部',
      'filterText': '文本',
      'filterMedia': '媒体',
      'filterImage': '图片',
      'filterVideo': '视频',
      'filterAudio': '音频',
      'filterFile': '文件',
      'noResults': '无匹配消息',
      'resultCount': '共 {count} 条结果',
      'openInChat': '在聊天中查看',
    },
    'details': {
      'title': '会话详情',
      'emptyTitle': '选择会话',
      'emptyHint': '会话资料、状态与操作会显示在这里',
      'sync': '同步',
      'markRead': '标为已读',
      'markUnread': '标为未读',
      'pin': '置顶',
      'unpin': '取消置顶',
      'mute': '免打扰',
      'unmute': '取消免打扰',
      'archive': '归档',
      'unarchive': '取消归档',
      'clearHistory': '清空本地记录',
      'delete': '删除会话',
      'statusSection': '会话状态',
      'extensions': '扩展入口',
      'openSdkLab': 'SDK 诊断',
      'pinTag': '置顶',
      'muteTag': '免打扰',
      'archivedTag': '已归档',
      'membersCount': '{count} 位成员',
    },
  },
  FlareLocale.enUs: {
    'nav': {
      'login': 'Sign in',
      'conversations': 'Messages',
      'sdkLab': 'SDK Lab',
      'settings': 'Settings',
    },
    'login': {
      'brandTitle': 'flare IM',
      'brandSubtitle': 'Secure, fast messaging',
      'welcomeTitle': 'Welcome back',
      'welcomeHint': 'Enter your user ID to continue',
      'userIdLabel': 'User ID',
      'userIdPlaceholder': 'Enter user ID',
      'userIdHint': 'Your user ID is assigned by the system',
      'userIdRequired': 'User ID is required',
      'serverToggle': 'Server address',
      'protocol': 'Protocol',
      'wsAddress': 'WebSocket URL',
      'gatewayAddress': 'Gateway URL',
      'gatewayHint': 'The SDK issues and refreshes access tokens from this gateway',
      'quicAddress': 'QUIC URL',
      'transportRace': 'Race',
      'wsUrlLabel': 'WebSocket',
      'wsUrlInvalid':
          'Enter the access-gateway WebSocket URL, for example ws://127.0.0.1:60051/ws',
      'advancedWsHint': 'Leave empty to use the default from config',
      'loginButton': 'Sign in',
      'footerPrimary': 'ID is assigned by your administrator',
      'footerSecondary': 'ID sign-in only · secure connection',
      'cancel': 'Cancel',
      'connected': 'Connected',
      'disconnected': 'Disconnected',
      'stagePreparing': 'Preparing the SDK runtime',
      'stageInitializing': 'Initializing the SDK and local database',
      'stageConnecting': 'Signing in and connecting',
      'tokenRejected': 'The access token was rejected by the server: the signing secret or issuer does not match, or the token has expired. Check the signing secret and try again.',
    },
    'conversation': {
      'clearSearch': 'Clear',
      'homeSnapshot': 'Core home snapshot',
      'homeSnapshotDesc': 'Rebuild the list via bootstrapHomeTimeline',
      'homeSnapshotLoaded': 'Loaded Core home snapshot: {count} conversations',
      'batchSync': 'Batch sync conversations',
      'batchSyncDesc': 'Reload the conversation view after core sync',
      'batchSyncHint': 'Separate multiple ids with commas, spaces, or newlines',
      'synced': 'Synced {count} conversations',
      'profile': 'Profile',
      'profileDesc': 'Account profile and presence',
      'profileTodo': 'Profile is not wired up yet',
      'logout': 'Log out',
      'logoutDesc': 'Disconnect the SDK session and return to sign-in',
      'logoutConfirm': 'Log out now?',
      'notFound': 'Conversation not found (check userId / permissions)',
      'emptyCid': 'Creation returned an empty conversationId; check the SDK response',
      'invalidConv': 'The SDK returned an invalid conversation; clear empty conversationId data and retry',
      'openFailed': 'Failed to open the conversation; check userId / permissions / SDK state',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'refresh': 'Refresh',
      'startTitle': 'Open conversation',
      'typeLabel': 'Conversation type',
      'direct': 'Direct',
      'group': 'Group',
      'memberIds': 'Member userIds',
      'peerHint': "Enter the peer's userId for a direct chat",
      'membersHint': 'For a group, enter multiple userIds separated by commas, spaces, or newlines',
      'groupName': 'Group name (optional)',
      'groupNameHint': 'e.g. Flutter SDK Lab',
      'open': 'Open',
      'notLoggedIn': 'Not signed in',
      'untitled': 'Conversation',
      'openA11y': 'Open conversation',
      'unpin': 'Unpin',
      'pin': 'Pin',
      'delete': 'Delete',
      'a11yConv': 'Conversation {title}',
      'selected': 'Selected',
      'pinnedA11y': 'Pinned',
      'unreadCount': '{count} unread',
      'mentionPrefix': '@me ',
      'syncThis': 'Sync this conversation',
      'syncedThis': 'Conversation synced',
      'deleteConv': 'Delete conversation',
      'deleteConfirm': 'Delete this conversation?',
      'yesterday': 'Yesterday',
      'weekdays': 'Mon,Tue,Wed,Thu,Fri,Sat,Sun',
      'title': 'Messages',
      'searchPlaceholder': 'Search conversations or previews',
      'pinnedSection': 'Pinned',
      'allSection': 'All',
      'emptyTitle': 'No conversations yet',
      'emptyHint': 'Pull to refresh or start a new chat',
      'startChat': 'Start chat',
      'emptySearchTitle': 'No matches',
      'emptySearchHint': 'Try another keyword',
      'filterAll': 'All',
      'filterUnread': 'Unread',
      'filterMention': 'Mentions',
      'filterPinned': 'Pinned',
      'filterMuted': 'Muted',
      'filterArchived': 'Archived',
      'filterDraft': 'Drafts',
      'draftPrefix': 'Draft: ',
      'noMessagePreview': 'No messages yet',
      'previewSticker': 'Sticker',
      'previewEmoji': 'Emoji',
      'currentAccount': 'Signed in as',
      'sdkLabSubtitle': 'Connection, capabilities, media cache, diagnostics',
      'language': 'Language',
      'languageZh': '简体中文',
      'languageEn': 'English',
    },
    'chat': {
      'composerPlaceholder': 'Message {name}',
      'send': 'Send',
      'typing': 'Typing…',
      'connectionStable': 'Connected · synced',
      'connectionConnecting': 'Connecting…',
      'connectionDisconnected': 'Disconnected · retrying',
      'connectionSendingHint': 'Sending messages will continue when ready',
      'searchMessages': 'Search messages',
      'syncConversation': 'Sync conversation',
      'pullFromServer': 'Pull from server',
      'conversationDetails': 'Conversation details',
      'multiSelectCount': '{count} selected',
      'selectTitle': 'Select a conversation',
      'selectHint': 'Open a chat from the list or start a new one',
      'peerTyping': 'Typing…',
      'typingMany': '{count} people are typing…',
      'online': 'Online',
      'offline': 'Offline',
      'chatTitle': 'Chat',
      'defaultUserName': 'Flare IM user',
      'typeText': 'Text',
      'typeImage': 'Image',
      'typeVideo': 'Video',
      'typeAudio': 'Voice',
      'typeFile': 'File',
      'typeLocation': 'Location',
      'typeCard': 'Contact',
      'typeSticker': 'Sticker',
      'typeEmoji': 'Emoji',
      'typeLink': 'Link',
      'typeMiniProgram': 'Mini program',
      'typeForward': 'Forward',
      'typeQuote': 'Reply',
      'typeTopic': 'Topic',
      'typeRichText': 'Rich text',
      'typeImageGroup': 'Photos',
      'typeSystem': 'System',
      'typeNotification': 'Notice',
      'typeVote': 'Vote',
      'typeTask': 'Task',
      'typeSchedule': 'Schedule',
      'typeAnnouncement': 'Announcement',
      'typeCustom': 'Custom',
      'typePlaceholder': 'Placeholder',
      'typeMessage': 'Message',
      'typeUnknown': 'Type {wire}',
      'statusUnknown': 'Unknown',
      'statusTodo': 'To do',
      'statusPending': 'Pending',
      'statusInProgress': 'In progress',
      'statusDone': 'Done',
      'statusClosed': 'Closed',
      'statusCancelled': 'Cancelled',
      'sending': 'Sending…',
      'read': 'Read',
      'resend': 'Resend',
      'resendUnsupported': "This message type can't be resent",
      'recalled': 'Message recalled',
      'recallExpired': 'The recall window has passed',
      'recallWhileSending': 'Still sending — try recalling in a moment',
      'forwardWhileSending': "Still sending — can't forward yet",
      'markedImportant': 'Marked as important',
      'copied': 'Copied',
      'reactionFailed': 'Reaction failed: {e}',
      'markFailed': 'Flag failed: {e}',
      'menuReply': 'Reply',
      'menuForward': 'Forward',
      'menuRecall': 'Recall',
      'menuMultiSelect': 'Select',
      'menuMark': 'Flag',
      'menuCopy': 'Copy',
      'menuEdit': 'Edit',
      'menuSave': 'Save',
      'menuCollapse': 'Collapse',
      'menuDelete': 'Delete',
      'menuDeleteMessage': 'Delete message',
      'menuDeleteSelf': 'Delete for me',
      'menuDeleteSelfHint': 'Others can still see it',
      'menuDeleteForAll': 'Delete for everyone',
      'menuDeleteForAllHint': 'Remove this message from the chat',
      'menuPinSelf': 'Pin for me',
      'menuNoActions': 'No actions available',
      'menuPickEmoji': 'Pick an emoji',
      'menuNoEmojiAssets': 'No assets/emoji resources found',
      'menuNothingToCopy': 'Nothing to copy',
      'pinMessage': 'Pin message',
      'unpin': 'Unpin',
      'editMessage': 'Edit message',
      'editRichText': 'Edit rich text',
      'save': 'Save',
      'close': 'Close',
      'cancel': 'Cancel',
      'forwardSingle': 'Forward individually',
      'forwardMerged': 'Forward as one',
      'forwardMergedCount': 'Forward {count} merged',
      'forwardMergedTitle': 'Merged forward ({count})',
      'forwardMessage': 'Forward message',
      'exitMultiSelect': 'Exit selection',
      'recallLatestSelf': 'Recall latest (mine)',
      'deleteSelfShort': 'Delete for me',
      'forwardedToCurrent': 'Forwarded to this chat',
      'nothingToForward': 'No messages to forward',
      'sdkMessageType': 'SDK message type',
      'sdkMessageSent': 'SDK message sent',
      'syncRequested': 'Conversation sync requested',
      'forwardFailed': 'Forward failed: {e}',
      'deleteFailed': 'Delete failed: {e}',
      'sendFailed': 'Send failed: {e}',
      'richTextSendFailed': 'Rich text send failed: {e}',
      'richTextEditFailed': 'Rich text edit failed: {e}',
      'quoteSendFailed': 'Quote send failed: {e}',
      'quoteFallbackPlain': 'The original message is unavailable; sent as plain text',
      'holdToRecord': 'Hold to record',
      'holdButtonToRecord': 'Press and hold the button to record',
      'slideUpToCancel': 'Slide up to cancel',
      'releaseToSend': 'Release to send',
      'releaseToCancel': 'Release to cancel',
      'releaseToSendSlideCancel': 'Release to send, slide up to cancel',
      'pickAudioFile': 'Pick an audio file',
      'noMicPermission': 'No microphone permission',
      'recordFailedRetry': 'Recording failed, please try again',
      'recordFailed': 'Recording failed: {msg}',
      'recordPluginNotLoaded': 'The recorder plugin failed to load; rebuild and try again',
      'pullToSync': 'Pull to sync',
      'noMessages': 'No messages yet',
      'sendCard': 'Send contact',
      'sendCardDesc': 'Share a contact card so others can recognize them quickly',
      'sendTask': 'Send task',
      'taskCardDesc': 'Create a to-do task card and send it to the chat',
      'sendSchedule': 'Send schedule',
      'scheduleCardDesc': 'Create a meeting or reminder and sync it to members',
      'displayName': 'Display name',
      'userId': 'User ID',
      'subtitleLabel': 'Subtitle',
      'avatarUrlOptional': 'Avatar URL (optional)',
      'taskTitleLabel': 'Task title',
      'taskTitleDefault': 'Follow up on this chat',
      'participantIds': 'Participant IDs',
      'commaOrSpaceSeparated': 'Separate with commas or spaces',
      'statusLabel': 'Status',
      'scheduleTitleLabel': 'Schedule title',
      'scheduleTitleDefault': 'Sync meeting',
      'minutesUntilStart': 'Minutes until start',
      'durationMinutes': 'Duration (minutes)',
      'latitude': 'Latitude',
      'longitude': 'Longitude',
      'mustBeNumber': '{label} must be a number',
      'atLeastOneImageRow': 'Add at least one image row',
      'voteMinOptions': 'A poll needs at least 2 options',
      'originalImage': 'Original',
      'originalImageBytes': 'Original {s}B',
      'originalImageKb': 'Original {s}KB',
      'originalImageMb': 'Original {s}MB',
      'imageLoadFailed': 'Failed to load image',
      'cannotShowLocalImage': "Can't show a local-path image",
      'photos': 'Photos',
      'photosCount': '{total} photos',
      'joinVote': 'Vote',
      'startVote': 'Start poll',
      'voteNoId': "Can't open the poll (missing voteId)",
      'voteInAppHint': 'Options and voting are completed in the app',
      'voteParticipants': '{count} joined',
      'voteOptionsHint': '{count} options · vote in the app',
      'voteParticipantLine': 'Participants · {value}',
      'businessParams': 'Details',
      'meeting': 'Meeting',
      'meetingLink': 'Meeting link',
      'participationStatus': 'Attendance',
      'scheduleReminder': 'Schedule reminder',
      'viewSchedule': 'View schedule',
      'communicationMeeting': 'Sync meeting',
      'schedulePrefix': 'Schedule: {value}',
      'scheduleParticipants': 'Participants · {value}',
      'assignTask': 'Assign task',
      'deadline': 'Due',
      'assign': 'Assignee',
      'viewTask': 'View task',
      'taskPrefix': 'Task: {value}',
      'deadlinePrefix': 'Due: {value}',
      'assignedTo': 'Assigned to: {value}',
      'noForwardContent': 'No forwarded content',
      'unknownSender': 'Unknown sender',
      'tapForDetails': 'Tap for details',
      'chatHistory': 'Chat history',
      'remark': 'Note ',
      'remarkPrefix': 'Note {value}',
      'forwardTotalMessages': '{total} messages',
      'forwardMore': '{more} more messages…',
      'groupAnnouncement': 'Group announcement',
      'publishedByOwner': 'Posted by owner',
      'viewDetails': 'View details',
      'announcementA11y': 'Announcement: {value}',
      'systemNotification': 'System notice',
      'miniProgramWip': 'Opening mini programs is under development',
      'miniProgramWipId': 'Opening mini program ({id}) is under development',
      'tapToOpenMiniProgram': 'Tap to open mini program →',
      'cannotOpenMap': "Can't open the map",
      'cannotOpenLink': "Can't open the link",
      'attachment': 'Attachment',
      'saving': 'Saving…',
      'savedTo': 'Saved to {location}',
      'saveFailed': 'Could not save. Try again.',
      'showInFolder': 'Show in folder',
      'richTextTag': '[Rich text]',
      'topicTagPlain': '[Topic]',
      'topicTag': '[Topic] {value}',
      'imageGroupTag': '[Photos]',
      'placeholderTag': '[Placeholder]',
      'yesterdayAt': 'Yesterday {hm}',
      'dateMonthDayAt': '{month}/{day} {hm}',
      'dateFullAt': '{year}/{month}/{day} {hm}',
    },
    'composer': {
      'hint': 'Message {name}',
      'multilineHint': 'Multiline · Enter or Send to send, Shift+Enter for newline',
      'expandInput': 'Expand',
      'collapse': 'Collapse',
      'cancelReply': 'Cancel reply',
      'replyTo': 'Replying to {name}:',
      'send': 'Send',
      'more': 'More',
      'mention': 'Mention',
      'richText': 'Rich text',
      'voice': 'Voice',
      'image': 'Image',
      'video': 'Video',
      'file': 'File',
      'emojiSticker': 'Emoji & stickers',
      'emojiStickerDesc': 'From assets/emoji and assets/stickers',
      'album': 'Album',
      'imageAndVideo': 'Photos & videos',
      'albumImageVideo': 'Album (photos & videos)',
      'folder': 'Folder',
      'localFile': 'Local file',
      'localFolder': 'Local folder',
      'sendMessage': 'Message',
      'emojiNotWired': 'Emoji (not wired)',
      'attachNotWired': 'Attachments (not wired)',
      'insertNotWired': 'Insert (not wired)',
      'inDev': '{name} (in development)',
      'placeholderName': '{name} (placeholder)',
      'placeholderLabel': '{label} (placeholder)',
      'emojiSearchHint': 'Search or pick emoji',
      'emojiAssetsMissing':
          'No assets/emoji/*.webp found in the bundle.\nMake sure pubspec declares assets/emoji/ and the folder has files.',
      'frequentlyUsed': 'Frequently used',
      'defaultEmoji': 'Default emoji',
      'noWebpInPack': 'No .webp assets in this pack',
      'moreEmojiPacks': 'More emoji packs',
      'customEmojiPackPlaceholder': 'Custom emoji pack (placeholder)',
      'indent': 'Indent',
      'increaseIndent': 'Increase indent',
      'decreaseIndent': 'Decrease indent',
      'bold': 'Bold',
      'italic': 'Italic',
      'strike': 'Strikethrough',
      'inlineCode': 'Inline code',
      'codeBlock': 'Code block',
      'heading': 'Heading',
      'quote': 'Quote',
      'bulletList': 'Bulleted list',
      'orderedList': 'Numbered list',
      'link': 'Link',
      'location': 'Location',
      'contact': 'Contact',
      'schedule': 'Schedule',
      'task': 'Task',
      'vote': 'Vote',
      'miniProgram': 'Mini program',
      'topic': 'Topic',
      'notification': 'Notice',
      'announcement': 'Announcement',
      'sdkMessageType': 'SDK message type',
      'sdkMessageDesc': 'Send reserved message types outside the main composer flow',
      'close': 'Close',
      'messageType': 'Message type',
      'cancel': 'Cancel',
      'createAndSend': 'Create & send',
      'catGroupBase': 'Basics',
      'catGroupCardLink': 'Cards & links',
      'catGroupBusiness': 'Business',
      'catGroupOther': 'Other',
      'catThreadReply': 'Thread THREAD',
      'catImageGroup': 'Photos IMAGE_GROUP',
      'catLocation': 'Location LOCATION',
      'catCard': 'Contact CARD',
      'catSticker': 'Sticker STICKER',
      'catLinkCard': 'Link card LINK_CARD',
      'catMiniProgram': 'Mini program MINI_PROGRAM',
      'catNotification': 'Notice NOTIFICATION',
      'catVote': 'Poll POLL',
      'catTask': 'Task TASK',
      'catSchedule': 'Schedule SCHEDULE',
      'catAnnouncement': 'Announcement ANNOUNCEMENT',
      'catCustom': 'Custom CUSTOM',
      'catPlaceholder': 'Placeholder PLACEHOLDER',
      'fieldBody': 'Body',
      'fieldImageUrls': 'Image URL / imageId',
      'fieldImageUrlsHint': 'Enter a real image URL or imageId',
      'fieldDescOptional': 'Description (optional)',
      'fieldMetadata': 'metadata (key: value per line)',
      'fieldMetadataHint': 'albumId: <real album ID>',
      'fieldLongitude': 'Longitude',
      'fieldLatitude': 'Latitude',
      'fieldTitle': 'Title',
      'fieldAddress': 'Address',
      'fieldMapZoomOptional': 'Map zoom (optional)',
      'fieldSnapshotUrlOptional': 'Snapshot URL (optional)',
      'fieldSnapshotPathOptional': 'Local snapshot path (optional)',
      'fieldUrlOptional': 'url (optional)',
      'fieldExtra': 'extra (key: value per line)',
      'fieldExtraHint': 'Enter real extension fields, key: value per line',
      'fieldOptionsPerLine': 'Options (one per line)',
      'fieldParticipants': 'Participant IDs (comma / newline separated)',
      'fieldStartAfterMinutes': 'Minutes until start',
      'fieldDurationMinutes': 'Duration (minutes)',
      'fieldBusinessType': 'Business type string',
      'scheduleProtoHint': '82 SCHEDULE · start/end ms',
    },
    'connection': {
      'syncConversations': 'Syncing conversations',
      'syncDetail': 'Offline data will sync after connect',
      'reconnecting': 'Reconnecting',
      'disconnected': 'Disconnected',
      'retryHint': 'Check server URL and network',
    },
    'settings': {
      'title': 'Settings',
      'appearance': 'Appearance',
      'language': 'Language',
      'themeSystem': 'System',
      'themeLight': 'Light',
      'themeDark': 'Dark',
      'storage': 'Storage',
      'downloadLocation': 'Download location',
      'downloadLocationChange': 'Change location',
      'downloadLocationReset': 'Use the default location',
      'downloadLocationFilesApp': 'Files app › this app › flare',
      'downloadLocationUnwritable': 'This folder cannot be written to. Choose another one.',
      'downloadLocationUnavailable': 'The download location is not available yet. Try again later.',
      'mediaCache': 'Image and file cache',
      'notMeasured': 'Not measured',
      'clearCache': 'Clear cache',
      'clearCacheConfirm': 'Pictures you have seen will be downloaded again.',
      'cacheCleared': 'Cache cleared',
      'clearCacheFailed': 'Could not clear the cache. Try again.',
    },
    'sdkLab': {
      'title': 'SDK Lab',
      'refresh': 'Refresh',
      'tabDiagnostics': 'Diagnostics',
      'tabEvents': 'Events',
      'tabMedia': 'Media',
      'tabCapabilityCall': 'Capability / Call',
      'clear': 'Clear',
      'eventsEmpty': 'No events yet. Sign in, sync, send a message, or run a Lab action to log here.',
      'builderEmpty': 'No builder catalog yet. Refresh to see the build capabilities the SDK returns.',
      'clearCache': 'Clear cache',
      'setCacheLimit': 'Set 256MB limit',
      'downloadDir': 'Download folder',
      'setLabDir': 'Set Lab folder',
      'uploadFile': 'Upload file',
      'uploadImage': 'Upload image',
      'uploadVideo': 'Upload video',
      'uploadBytes': 'Upload bytes',
      'pickSourceFile': 'Pick source file',
      'downloadSave': 'Download / save',
      'querySavePath': 'Query save path',
      'cancelDownload': 'Cancel download',
      'deleteRecord': 'Delete record',
      'queryCurrentUser': 'Query current user',
      'batchQuery': 'Batch query',
      'subscribePresence': 'Subscribe presence',
      'runTemplate': 'Run template',
      'syncConversationSummary': 'Sync conversation summary',
      'rawConversation': 'Raw conversation',
      'pagedConversation': 'Paged conversation',
      'noCommandFailures': 'No command failures.',
      'uploadHint':
          'For uploads, make sure you are signed in and the SDK is initialized; for download/save, provide at least one of source_path, source_url, or remoteFileId.',
    },
    'search': {
      'title': 'Search messages',
      'inConversation': 'This chat',
      'global': 'All chats',
      'keywordHint': 'Keyword',
      'searchButton': 'Search',
      'filterLabel': 'Search type',
      'filterAll': 'All',
      'filterText': 'Text',
      'filterMedia': 'Media',
      'filterImage': 'Images',
      'filterVideo': 'Videos',
      'filterAudio': 'Audio',
      'filterFile': 'Files',
      'noResults': 'No matches',
      'resultCount': '{count} results',
      'openInChat': 'Open in chat',
    },
    'details': {
      'title': 'Details',
      'emptyTitle': 'Select a conversation',
      'emptyHint': 'Metadata and actions appear here',
      'sync': 'Sync',
      'markRead': 'Mark read',
      'markUnread': 'Mark unread',
      'pin': 'Pin',
      'unpin': 'Unpin',
      'mute': 'Mute',
      'unmute': 'Unmute',
      'archive': 'Archive',
      'unarchive': 'Unarchive',
      'clearHistory': 'Clear local history',
      'delete': 'Delete',
      'statusSection': 'Status',
      'extensions': 'Extensions',
      'openSdkLab': 'SDK diagnostics',
      'pinTag': 'Pinned',
      'muteTag': 'Muted',
      'archivedTag': 'Archived',
      'membersCount': '{count} members',
    },
  },
};
