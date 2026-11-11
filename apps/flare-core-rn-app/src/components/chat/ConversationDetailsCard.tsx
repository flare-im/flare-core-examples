import React from 'react';
import { Text, View } from 'react-native';
import Tag from '@ant-design/react-native/lib/tag';
import { styles } from '../../styles';
import type { ConversationItem } from '../../types';
import { KeyValue } from '../common';

export function ConversationDetailsCard(props: { conversation: ConversationItem; messageCount: number; latestMessageId: string }) {
  return (
    <View style={styles.card}>
      <Text style={styles.sectionTitle}>会话详情</Text>
      <KeyValue label="Conversation ID" value={props.conversation.id} />
      <KeyValue label="Channel" value={props.conversation.channelId} />
      <KeyValue label="Unread" value={String(props.conversation.unreadCount)} />
      <KeyValue label="Messages" value={String(props.messageCount)} />
      <KeyValue label="Latest Message" value={props.latestMessageId || '-'} />
      <View style={styles.detailActions}>
        {['同步', '标为已读', '标为未读', '置顶', '免打扰', '归档'].map((item) => (
          <Tag key={item} selected>{item}</Tag>
        ))}
      </View>
    </View>
  );
}
