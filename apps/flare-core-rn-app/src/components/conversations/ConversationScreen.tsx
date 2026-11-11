import React from 'react';
import { Text, View } from 'react-native';
import { IconOutline } from '@ant-design/icons-react-native';
import Button from '@ant-design/react-native/lib/button';
import InputItem from '@ant-design/react-native/lib/input-item';
import List from '@ant-design/react-native/lib/list';
import Tag from '@ant-design/react-native/lib/tag';
import WhiteSpace from '@ant-design/react-native/lib/white-space';
import { colors } from '../../theme/tokens';
import { styles } from '../../styles';
import type { ConversationFilter, ConversationItem, SdkStatus } from '../../types';
import { RuntimeBanner } from '../common';
import { ConversationSection } from './ConversationSection';
import { FilterTabs } from './FilterTabs';

export function ConversationScreen(props: {
  conversations: ConversationItem[];
  pinnedConversations: ConversationItem[];
  restConversations: ConversationItem[];
  activeConversationId: string;
  activeFilter: ConversationFilter;
  connectionText: string;
  conversationSearchOpen: boolean;
  conversationSearchQuery: string;
  pinnedCount: number;
  totalUnread: number;
  sdkStatus: SdkStatus;
  startChatOpen: boolean;
  startPeerUserId: string;
  onFilterChange: (filter: ConversationFilter) => void;
  onSearchChange: (value: string) => void;
  onSelect: (id: string) => void;
  onStartPeerChange: (value: string) => void;
  onCreateConversation: () => void;
}) {
  return (
    <>
      <View style={styles.summaryCard}>
        <Text style={styles.summaryTitle}>
          {props.conversations.length} 会话 · {props.totalUnread} 未读 · {props.pinnedCount} 置顶
        </Text>
        <Text style={styles.summaryMeta}>连接状态 · {props.connectionText}</Text>
      </View>

      <WhiteSpace size="lg" />
      <FilterTabs activeFilter={props.activeFilter} onChange={props.onFilterChange} />

      {props.conversationSearchOpen && (
        <>
          <WhiteSpace size="md" />
          <List styles={{ Body: styles.inputListBody }}>
            <InputItem clear value={props.conversationSearchQuery} placeholder="搜索会话或最新消息" onChange={props.onSearchChange}>
              搜索
            </InputItem>
          </List>
        </>
      )}

      <WhiteSpace size="lg" />
      <RuntimeBanner sdkStatus={props.sdkStatus} context="conversations" />

      {props.startChatOpen && (
        <>
          <WhiteSpace size="lg" />
          <View style={styles.card}>
            <View style={styles.cardHeader}>
              <Text style={styles.sectionTitle}>发起会话</Text>
              <Tag selected>Single</Tag>
            </View>
            <List styles={{ Body: styles.inputListBody }}>
              <InputItem clear value={props.startPeerUserId} placeholder="对端 userId" onChange={props.onStartPeerChange}>
                userId
              </InputItem>
            </List>
            <WhiteSpace size="sm" />
            <Button type="primary" onPress={props.onCreateConversation}>
              创建并打开
            </Button>
          </View>
        </>
      )}

      <WhiteSpace size="lg" />
      {props.pinnedConversations.length > 0 && (
        <ConversationSection
          label="置顶"
          items={props.pinnedConversations}
          activeConversationId={props.activeConversationId}
          onSelect={props.onSelect}
        />
      )}
      {props.pinnedConversations.length > 0 && props.restConversations.length > 0 && <WhiteSpace size="lg" />}
      <ConversationSection
        label={props.pinnedConversations.length ? '全部' : '会话'}
        items={props.restConversations}
        activeConversationId={props.activeConversationId}
        onSelect={props.onSelect}
      />
      {!props.conversations.length && (
        <View style={styles.emptyState}>
          <IconOutline name="comment" size={36} color={colors.primary} />
          <Text style={styles.emptyTitle}>没有匹配的会话</Text>
          <Text style={styles.emptyDetail}>调整筛选条件，或创建一个新的单聊会话。</Text>
        </View>
      )}
    </>
  );
}
