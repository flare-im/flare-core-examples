import React from 'react';
import { Pressable, Text, View } from 'react-native';
import { IconOutline } from '@ant-design/icons-react-native';
import { MessageContentType } from '@flare-im/sdk/model';
import { colors } from '../../theme/tokens';
import { styles } from '../../styles';
import type { TimelineMessage } from '../../types';
import { messageStatusText, renderMessageText } from '../../utils';

export function MessageRow(props: {
  message: TimelineMessage;
  selected: boolean;
  multiSelectMode: boolean;
  onReact: (id: string, emoji: string) => void;
  onReply: (id: string) => void;
  onRetry: (id: string) => void;
  onEnterMultiSelect: (id: string) => void;
  onToggleSelected: (id: string) => void;
}) {
  const outbound = props.message.direction === 'outbound';
  const mediaLike = props.message.contentType === MessageContentType.Sticker || props.message.contentType === MessageContentType.Emoji;
  return (
    <Pressable
      onLongPress={() => props.onEnterMultiSelect(props.message.id)}
      onPress={() => props.multiSelectMode && props.onToggleSelected(props.message.id)}
      style={[styles.messageRow, outbound ? styles.messageRowOutbound : styles.messageRowInbound]}
    >
      {props.multiSelectMode && (
        <View style={[styles.selectionDot, props.selected && styles.selectionDotActive]}>
          {props.selected && <IconOutline name="check" size={12} color="#fff" />}
        </View>
      )}
      {!outbound && (
        <View style={styles.senderAvatar}>
          <Text style={styles.senderAvatarText}>{props.message.authorName.slice(0, 1).toUpperCase()}</Text>
        </View>
      )}
      <View style={styles.messageStack}>
        <Text style={[styles.authorLabel, outbound && styles.authorLabelOutbound]}>
          {props.message.authorName} · seq {props.message.seq}
        </Text>
        <View style={[styles.bubble, mediaLike && styles.mediaBubble, outbound ? styles.outboundBubble : styles.inboundBubble, props.message.status === 'failed' && styles.failedBubble]}>
          <Text style={[styles.bubbleText, mediaLike && styles.mediaText, outbound ? styles.outboundText : styles.inboundText]}>
            {props.message.recalled ? '消息已撤回' : renderMessageText(props.message)}
          </Text>
        </View>
        <View style={[styles.messageActionRow, outbound && styles.messageActionRowOutbound]}>
          <Text style={styles.messageMeta}>
            {props.message.time} · {messageStatusText(props.message.status)}
            {props.message.edited ? ' · 已编辑' : ''}
          </Text>
          {props.message.status === 'failed' && (
            <Pressable onPress={() => props.onRetry(props.message.id)}>
              <Text style={styles.retryText}>重发</Text>
            </Pressable>
          )}
        </View>
        {!!props.message.reactions.length && (
          <View style={[styles.reactionStrip, outbound && styles.reactionStripOutbound]}>
            {props.message.reactions.map((reaction) => (
              <Text key={reaction} style={styles.reactionText}>{reaction}</Text>
            ))}
          </View>
        )}
        {!props.multiSelectMode && (
          <View style={[styles.quickMessageActions, outbound && styles.quickMessageActionsOutbound]}>
            <Pressable onPress={() => props.onReact(props.message.id, '👍')}>
              <Text style={styles.quickActionText}>👍</Text>
            </Pressable>
            <Pressable onPress={() => props.onReply(props.message.id)}>
              <Text style={styles.quickActionText}>回复</Text>
            </Pressable>
            <Pressable onPress={() => props.onEnterMultiSelect(props.message.id)}>
              <Text style={styles.quickActionText}>多选</Text>
            </Pressable>
          </View>
        )}
      </View>
    </Pressable>
  );
}
