import React from 'react';
import { Pressable, Text, View } from 'react-native';
import { IconOutline } from '@ant-design/icons-react-native';
import { colors } from '../../theme/tokens';
import { styles } from '../../styles';
import type { SdkStatus } from '../../types';
import { connectionText } from '../../utils';

export function RuntimeBanner(props: { sdkStatus: SdkStatus; context: 'conversations' | 'chat' }) {
  if (props.sdkStatus === 'ready') {
    return (
      <View style={[styles.runtimeBanner, styles.runtimeBannerSuccess]}>
        <View style={[styles.runtimeDot, { backgroundColor: colors.success }]} />
        <Text style={styles.runtimeText}>{props.context === 'chat' ? '连接稳定 · 可实时收发消息' : '同步已就绪 · 会话 API 可用'}</Text>
      </View>
    );
  }
  if (props.sdkStatus === 'error') {
    return (
      <View style={[styles.runtimeBanner, styles.runtimeBannerError]}>
        <View style={[styles.runtimeDot, { backgroundColor: colors.danger }]} />
        <Text style={styles.runtimeText}>Native bridge 未注册 · 请接入 C ABI TurboModule</Text>
      </View>
    );
  }
  return (
    <View style={[styles.runtimeBanner, styles.runtimeBannerWarning]}>
      <View style={[styles.runtimeDot, { backgroundColor: colors.warning }]} />
      <Text style={styles.runtimeText}>等待初始化 · 发送会进入可重试状态</Text>
    </View>
  );
}

export function SegmentButton(props: { active: boolean; label: string; onPress: () => void }) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected: props.active }}
      onPress={props.onPress}
      style={[styles.segmentButton, props.active && styles.segmentButtonActive]}
    >
      <Text style={[styles.segmentText, props.active && styles.segmentTextActive]}>{props.label}</Text>
    </Pressable>
  );
}

export function IconAction(props: {
  name: React.ComponentProps<typeof IconOutline>['name'];
  label: string;
  primary?: boolean;
  active?: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityLabel={props.label}
      accessibilityRole="button"
      onPress={props.onPress}
      style={[styles.iconAction, props.primary && styles.iconActionPrimary, props.active && styles.iconActionActive]}
    >
      <IconOutline name={props.name} size={20} color={props.primary || props.active ? '#fff' : colors.textMuted} />
    </Pressable>
  );
}

export function MoreAction(props: {
  icon: React.ComponentProps<typeof IconOutline>['name'];
  label: string;
  danger?: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable onPress={props.onPress} style={styles.moreAction}>
      <IconOutline name={props.icon} size={18} color={props.danger ? colors.danger : colors.primary} />
      <Text style={[styles.moreActionText, props.danger && styles.dangerText]}>{props.label}</Text>
    </Pressable>
  );
}

export function KeyValue(props: { label: string; value: string }) {
  return (
    <View style={styles.keyValueRow}>
      <Text style={styles.keyText}>{props.label}</Text>
      <Text numberOfLines={1} style={styles.valueText}>{props.value}</Text>
    </View>
  );
}
