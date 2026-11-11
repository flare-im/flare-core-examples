import React from 'react';
import { Pressable, Text, View } from 'react-native';
import { IconOutline } from '@ant-design/icons-react-native';
import Button from '@ant-design/react-native/lib/button';
import WhiteSpace from '@ant-design/react-native/lib/white-space';
import { colors } from '../../theme/tokens';
import { styles } from '../../styles';
import type { ComposerPanel, ConversationItem, SdkStatus, TimelineMessage, UploadTask } from '../../types';
import { conversationSubtitle, presenceDotStyle } from '../../utils';
import { IconAction, RuntimeBanner } from '../common';
import { Composer } from './Composer';
import { ConversationDetailsCard } from './ConversationDetailsCard';
import { MessageRow } from './MessageRow';
import { UploadTaskRow } from './UploadTaskRow';

export function ChatScreen(props: {
  conversation: ConversationItem;
  messages: TimelineMessage[];
  composer: string;
  composerPanel: ComposerPanel;
  composerRichMode: boolean;
  sending: boolean;
  sdkStatus: SdkStatus;
  pinnedMessages: TimelineMessage[];
  replyMessage?: TimelineMessage;
  uploadTasks: UploadTask[];
  multiSelectMode: boolean;
  selectedMessageIds: string[];
  selectedCount: number;
  onBack: () => void;
  onOpenSdk: () => void;
  onOpenMore: () => void;
  onComposerChange: (value: string) => void;
  onPanelChange: (panel: ComposerPanel) => void;
  onRichModeChange: (enabled: boolean) => void;
  onInsertEmoji: (value: string) => void;
  onSendSticker: (value: string) => void;
  onSend: () => void;
  onReply: (id: string) => void;
  onClearReply: () => void;
  onReact: (id: string, emoji: string) => void;
  onRetry: (id: string) => void;
  onEnterMultiSelect: (id: string) => void;
  onToggleSelected: (id: string) => void;
  onExitMultiSelect: () => void;
  onRemoveUploadTask: (id: string) => void;
}) {
  return (
    <>
      <View style={styles.chatAppBar}>
        <IconAction name={props.multiSelectMode ? 'close' : 'arrow-left'} label="返回" onPress={props.onBack} />
        <View style={[styles.avatarSmall, { backgroundColor: props.conversation.avatarColor }]}>
          <Text style={styles.avatarSmallText}>{props.conversation.avatar}</Text>
          <View style={[styles.presenceDot, presenceDotStyle(props.conversation.presence)]} />
        </View>
        <View style={styles.chatIdentity}>
          <Text style={styles.chatTitle}>
            {props.multiSelectMode ? `已选择 ${props.selectedCount} 条` : props.conversation.title}
          </Text>
          <Text style={styles.presenceText}>{conversationSubtitle(props.conversation)}</Text>
        </View>
        <IconAction name="phone" label="语音" onPress={() => undefined} />
        <IconAction name="video-camera" label="视频" onPress={() => undefined} />
        <IconAction name="search" label="搜索" onPress={props.onOpenMore} />
        <IconAction name="build" label="SDK" onPress={props.onOpenSdk} />
        <IconAction name="ellipsis" label="更多" onPress={props.onOpenMore} />
      </View>

      <WhiteSpace size="lg" />
      <RuntimeBanner sdkStatus={props.sdkStatus} context="chat" />

      {props.pinnedMessages.length > 0 && (
        <>
          <WhiteSpace size="lg" />
          <View style={styles.pinnedBar}>
            <IconOutline name="pushpin" size={16} color={colors.primary} />
            <Text numberOfLines={1} style={styles.pinnedText}>
              置顶消息 · {props.pinnedMessages[0].text}
            </Text>
          </View>
        </>
      )}

      <WhiteSpace size="lg" />
      <View style={styles.timelineCard}>
        {props.messages.length ? (
          <View style={styles.timeline}>
            <Text style={styles.timeDivider}>今天 09:41</Text>
            {props.messages.map((message) => (
              <MessageRow
                key={message.id}
                message={message}
                selected={props.selectedMessageIds.includes(message.id)}
                multiSelectMode={props.multiSelectMode}
                onReact={props.onReact}
                onReply={props.onReply}
                onRetry={props.onRetry}
                onEnterMultiSelect={props.onEnterMultiSelect}
                onToggleSelected={props.onToggleSelected}
              />
            ))}
          </View>
        ) : (
          <View style={styles.emptyState}>
            <IconOutline name="comment" size={36} color={colors.primary} />
            <Text style={styles.emptyTitle}>暂无消息</Text>
            <Text style={styles.emptyDetail}>点击同步或发送一条消息开始会话。</Text>
          </View>
        )}
      </View>

      {props.multiSelectMode && (
        <>
          <WhiteSpace size="lg" />
          <View style={styles.batchToolbar}>
            <Text style={styles.batchTitle}>已选择 {props.selectedCount} 条</Text>
            <Button size="small" onPress={() => undefined}>逐条转发</Button>
            <Button size="small" onPress={() => undefined}>合并转发</Button>
            <Button size="small" onPress={props.onExitMultiSelect}>退出</Button>
          </View>
        </>
      )}

      {!!props.uploadTasks.length && (
        <>
          <WhiteSpace size="lg" />
          <View style={styles.card}>
            <Text style={styles.sectionTitle}>上传队列</Text>
            {props.uploadTasks.map((task) => (
              <UploadTaskRow key={task.id} task={task} onRemove={props.onRemoveUploadTask} />
            ))}
          </View>
        </>
      )}

      <WhiteSpace size="lg" />
      <Composer
        value={props.composer}
        panel={props.composerPanel}
        richMode={props.composerRichMode}
        sending={props.sending}
        replyMessage={props.replyMessage}
        targetName={props.conversation.title}
        onChange={props.onComposerChange}
        onPanelChange={props.onPanelChange}
        onRichModeChange={props.onRichModeChange}
        onInsertEmoji={props.onInsertEmoji}
        onSendSticker={props.onSendSticker}
        onClearReply={props.onClearReply}
        onSend={props.onSend}
      />

      <WhiteSpace size="lg" />
      <ConversationDetailsCard conversation={props.conversation} messageCount={props.messages.length} latestMessageId={props.messages.at(-1)?.id ?? ''} />
    </>
  );
}
