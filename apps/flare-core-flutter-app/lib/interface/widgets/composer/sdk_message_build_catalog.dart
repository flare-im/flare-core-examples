import 'package:flare_im/shared/i18n/flare_messages.dart';

enum SdkMessageBuildFieldType { text, textarea }

class SdkMessageBuildField {
  final String key;
  final String label;
  final SdkMessageBuildFieldType type;
  final String? placeholder;
  final String defaultValue;

  const SdkMessageBuildField({
    required this.key,
    required this.label,
    this.type = SdkMessageBuildFieldType.text,
    this.placeholder,
    this.defaultValue = '',
  });
}

enum SdkMessageBuildKind {
  threadReply,
  imageGroup,
  location,
  card,
  sticker,
  linkCard,
  miniProgram,
  notification,
  vote,
  task,
  schedule,
  announcement,
  custom,
  placeholder,
}

class SdkMessageBuildCatalogEntry {
  final SdkMessageBuildKind kind;
  final String label;
  final String protoHint;
  final String group;
  final List<SdkMessageBuildField> fields;

  const SdkMessageBuildCatalogEntry({
    required this.kind,
    required this.label,
    required this.protoHint,
    required this.group,
    required this.fields,
  });
}

List<SdkMessageBuildCatalogEntry> sdkMessageBuildCatalog(
  FlareComposerCopy c,
) => <SdkMessageBuildCatalogEntry>[
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.threadReply,
    label: c.catThreadReply,
    protoHint: '14 THREAD',
    group: c.catGroupBase,
    fields: [
      const SdkMessageBuildField(key: 'threadId', label: 'threadId'),
      SdkMessageBuildField(
        key: 'text',
        label: c.fieldBody,
        type: SdkMessageBuildFieldType.textarea,
      ),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.imageGroup,
    label: c.catImageGroup,
    protoHint: '32 IMAGE_GROUP · create_with_content',
    group: c.catGroupBase,
    fields: [
      SdkMessageBuildField(
        key: 'imageLines',
        label: c.fieldImageUrls,
        type: SdkMessageBuildFieldType.textarea,
        placeholder: c.fieldImageUrlsHint,
      ),
      SdkMessageBuildField(key: 'description', label: c.fieldDescOptional),
      SdkMessageBuildField(
        key: 'metadata',
        label: c.fieldMetadata,
        type: SdkMessageBuildFieldType.textarea,
        placeholder: c.fieldMetadataHint,
      ),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.location,
    label: c.catLocation,
    protoHint: '6 LOCATION',
    group: c.catGroupCardLink,
    fields: [
      SdkMessageBuildField(key: 'longitude', label: c.fieldLongitude),
      SdkMessageBuildField(key: 'latitude', label: c.fieldLatitude),
      SdkMessageBuildField(key: 'title', label: c.fieldTitle),
      SdkMessageBuildField(
        key: 'address',
        label: c.fieldAddress,
        type: SdkMessageBuildFieldType.textarea,
      ),
      SdkMessageBuildField(key: 'zoom', label: c.fieldMapZoomOptional),
      SdkMessageBuildField(
        key: 'snapshotUrl',
        label: c.fieldSnapshotUrlOptional,
      ),
      SdkMessageBuildField(
        key: 'snapshotLocalPath',
        label: c.fieldSnapshotPathOptional,
      ),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.card,
    label: c.catCard,
    protoHint: '7 CARD',
    group: c.catGroupCardLink,
    fields: [
      const SdkMessageBuildField(key: 'cardType', label: 'cardType'),
      const SdkMessageBuildField(key: 'id', label: 'id'),
      const SdkMessageBuildField(key: 'title', label: 'title'),
      const SdkMessageBuildField(key: 'subtitle', label: 'subtitle'),
      const SdkMessageBuildField(key: 'avatar', label: 'avatar URL'),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.sticker,
    label: c.catSticker,
    protoHint: '8 STICKER',
    group: c.catGroupCardLink,
    fields: [
      const SdkMessageBuildField(key: 'stickerId', label: 'stickerId'),
      const SdkMessageBuildField(key: 'packageId', label: 'packageId'),
      SdkMessageBuildField(key: 'url', label: c.fieldUrlOptional),
      const SdkMessageBuildField(key: 'width', label: 'width'),
      const SdkMessageBuildField(key: 'height', label: 'height'),
      const SdkMessageBuildField(key: 'format', label: 'format'),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.linkCard,
    label: c.catLinkCard,
    protoHint: 'MessageContent.link_card',
    group: c.catGroupCardLink,
    fields: [
      const SdkMessageBuildField(key: 'url', label: 'url'),
      const SdkMessageBuildField(key: 'title', label: 'title'),
      const SdkMessageBuildField(key: 'description', label: 'description'),
      const SdkMessageBuildField(key: 'thumbnailUrl', label: 'thumbnailUrl'),
      const SdkMessageBuildField(key: 'siteName', label: 'siteName'),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.miniProgram,
    label: c.catMiniProgram,
    protoHint: 'MessageContent.mini_program',
    group: c.catGroupCardLink,
    fields: [
      const SdkMessageBuildField(key: 'appId', label: 'appId'),
      const SdkMessageBuildField(key: 'title', label: 'title'),
      const SdkMessageBuildField(key: 'path', label: 'path'),
      const SdkMessageBuildField(key: 'thumbnailUrl', label: 'thumbnailUrl'),
      SdkMessageBuildField(
        key: 'extra',
        label: c.fieldExtra,
        type: SdkMessageBuildFieldType.textarea,
        placeholder: c.fieldExtraHint,
      ),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.notification,
    label: c.catNotification,
    protoHint: '61 NOTIFICATION',
    group: c.catGroupBusiness,
    fields: [
      SdkMessageBuildField(key: 'title', label: c.fieldTitle),
      SdkMessageBuildField(
        key: 'body',
        label: c.fieldBody,
        type: SdkMessageBuildFieldType.textarea,
      ),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.vote,
    label: c.catVote,
    protoHint: '80 POLL · participantUserIds',
    group: c.catGroupBusiness,
    fields: [
      const SdkMessageBuildField(key: 'voteId', label: 'voteId'),
      SdkMessageBuildField(key: 'title', label: c.fieldTitle),
      SdkMessageBuildField(
        key: 'options',
        label: c.fieldOptionsPerLine,
        type: SdkMessageBuildFieldType.textarea,
      ),
      SdkMessageBuildField(
        key: 'participantUserIds',
        label: c.fieldParticipants,
        type: SdkMessageBuildFieldType.textarea,
      ),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.task,
    label: c.catTask,
    protoHint: '81 TASK · participantUserIds',
    group: c.catGroupBusiness,
    fields: [
      const SdkMessageBuildField(key: 'taskId', label: 'taskId'),
      SdkMessageBuildField(key: 'title', label: c.fieldTitle),
      const SdkMessageBuildField(key: 'status', label: 'status'),
      SdkMessageBuildField(
        key: 'participantUserIds',
        label: c.fieldParticipants,
        type: SdkMessageBuildFieldType.textarea,
      ),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.schedule,
    label: c.catSchedule,
    protoHint: c.scheduleProtoHint,
    group: c.catGroupBusiness,
    fields: [
      const SdkMessageBuildField(key: 'scheduleId', label: 'scheduleId'),
      SdkMessageBuildField(key: 'title', label: c.fieldTitle),
      SdkMessageBuildField(
        key: 'startAfterMinutes',
        label: c.fieldStartAfterMinutes,
      ),
      SdkMessageBuildField(
        key: 'durationMinutes',
        label: c.fieldDurationMinutes,
      ),
      SdkMessageBuildField(
        key: 'participantUserIds',
        label: c.fieldParticipants,
        type: SdkMessageBuildFieldType.textarea,
      ),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.announcement,
    label: c.catAnnouncement,
    protoHint: '83 ANNOUNCEMENT',
    group: c.catGroupBusiness,
    fields: [
      SdkMessageBuildField(key: 'title', label: c.fieldTitle),
      SdkMessageBuildField(
        key: 'body',
        label: c.fieldBody,
        type: SdkMessageBuildFieldType.textarea,
      ),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.custom,
    label: c.catCustom,
    protoHint: '100 CUSTOM',
    group: c.catGroupOther,
    fields: [SdkMessageBuildField(key: 'type', label: c.fieldBusinessType)],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.placeholder,
    label: c.catPlaceholder,
    protoHint: '111-115',
    group: c.catGroupOther,
    fields: [const SdkMessageBuildField(key: 'reason', label: 'reason')],
  ),
];

Map<String, String> initialSdkMessageBuildValues(
  SdkMessageBuildCatalogEntry entry,
) {
  return {for (final field in entry.fields) field.key: field.defaultValue};
}
