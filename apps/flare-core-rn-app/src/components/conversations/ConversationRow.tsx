import React from 'react';
import { Pressable, Text, View } from 'react-native';
import { IconOutline } from '@ant-design/icons-react-native';
import Badge from '@ant-design/react-native/lib/badge';
import { colors } from '../../theme/tokens';
import { styles } from '../../styles';
import type { ConversationItem } from '../../types';
import { presenceDotStyle } from '../../utils';

export function ConversationRow(props: { item: ConversationItem; active: boolean; last: boolean; onPress: () => void }) {
  const preview = props.item.draft ? `[草稿] ${props.item.draft}` : props.item.lastMessagePreview;
  const previewIcon = props.item.draft
    ? ''
    : props.item.lastMessagePreviewKind === 'sticker'
      ? '▣ '
      : props.item.lastMessagePreviewKind === 'emoji'
        ? '☺ '
        : '';
  return (
    <Pressable
      accessibilityRole="button"
      onPress={props.onPress}
      style={[styles.conversationRow, props.active && styles.conversationRowActive, !props.last && styles.rowDivider]}
    >
      <View style={[styles.avatar, { backgroundColor: props.item.avatarColor }]}>
        <Text style={styles.avatarText}>{props.item.avatar}</Text>
        <View style={[styles.presenceDot, presenceDotStyle(props.item.presence)]} />
      </View>
      <View style={styles.conversationBody}>
        <View style={styles.rowBetween}>
          <View style={styles.titleInline}>
            <Text style={styles.conversationTitle}>{props.item.title}</Text>
            {props.item.pinned && <IconOutline name="pushpin" size={12} color={colors.primary} />}
            {props.item.muted && <IconOutline name="audio-muted" size={12} color={colors.textMuted} />}
          </View>
          <Text style={styles.metaText}>{props.item.lastMessageAt}</Text>
        </View>
        <View style={styles.rowBetween}>
          <Text numberOfLines={1} style={styles.previewText}>
            {previewIcon}{preview}
          </Text>
          {!!props.item.unreadCount && <Badge text={props.item.unreadCount} style={styles.unreadBadge} />}
        </View>
      </View>
    </Pressable>
  );
}
