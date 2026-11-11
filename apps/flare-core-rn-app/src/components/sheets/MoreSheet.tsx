import React from 'react';
import { Text, View } from 'react-native';
import Tag from '@ant-design/react-native/lib/tag';
import WhiteSpace from '@ant-design/react-native/lib/white-space';
import { styles } from '../../styles';
import type { SdkStatus, WorkbenchMode } from '../../types';
import { connectionText } from '../../utils';
import { MoreAction } from '../common';

export function MoreSheet(props: {
  mode: WorkbenchMode;
  sdkStatus: SdkStatus;
  currentUserId: string;
  onClose: () => void;
  onOpenSdk: () => void;
  onOpenSearch: () => void;
  onOpenBuilder: () => void;
  onOpenMedia: () => void;
  onSync: () => void;
  onLogout: () => void;
  onMarkRead: () => void;
  onMarkUnread: () => void;
  onTogglePin: () => void;
  onToggleMute: () => void;
  onToggleArchive: () => void;
  onClearHistory: () => void;
  onDelete: () => void;
}) {
  const displayUserId = props.currentUserId || '-';
  return (
    <View style={styles.card}>
      <View style={styles.accountHeader}>
        <View style={styles.accountAvatar}>
          <Text style={styles.accountAvatarText}>{displayUserId.slice(0, 1).toUpperCase()}</Text>
        </View>
        <View style={styles.chatIdentity}>
          <Text style={styles.metaText}>当前登录账号</Text>
          <Text style={styles.conversationTitle}>{displayUserId}</Text>
        </View>
        <Tag selected>{connectionText(props.sdkStatus)}</Tag>
      </View>
      <WhiteSpace size="md" />
      <View style={styles.moreGrid}>
        <MoreAction icon="info-circle" label="SDK 运行状态" onPress={props.onOpenSdk} />
        <MoreAction icon="search" label="搜索消息" onPress={props.onOpenSearch} />
        <MoreAction icon="build" label="构建消息" onPress={props.onOpenBuilder} />
        <MoreAction icon="picture" label="媒体中心" onPress={props.onOpenMedia} />
        <MoreAction icon="setting" label="设置" onPress={props.onClose} />
        <MoreAction icon="cloud-sync" label="从服务端拉取" onPress={props.onSync} />
        <MoreAction icon="logout" label="退出登录" danger onPress={props.onLogout} />
        {props.mode === 'chat' && (
          <>
            <MoreAction icon="check-circle" label="标为已读" onPress={props.onMarkRead} />
            <MoreAction icon="exclamation-circle" label="标为未读" onPress={props.onMarkUnread} />
            <MoreAction icon="pushpin" label="置顶/取消" onPress={props.onTogglePin} />
            <MoreAction icon="audio-muted" label="免打扰" onPress={props.onToggleMute} />
            <MoreAction icon="folder-open" label="归档" onPress={props.onToggleArchive} />
            <MoreAction icon="delete" label="清空记录" danger onPress={props.onClearHistory} />
            <MoreAction icon="close-circle" label="删除会话" danger onPress={props.onDelete} />
          </>
        )}
      </View>
    </View>
  );
}
