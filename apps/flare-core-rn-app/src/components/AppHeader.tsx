import React from 'react';
import { Text, View } from 'react-native';
import Badge from '@ant-design/react-native/lib/badge';
import { styles } from '../styles';
import type { WorkbenchMode } from '../types';
import { IconAction, SegmentButton } from './common';

export function AppHeader(props: {
  mode: WorkbenchMode;
  totalUnread: number;
  onModeChange: (mode: WorkbenchMode) => void;
  onSearch: () => void;
  onStartChat: () => void;
  onMore: () => void;
}) {
  return (
    <View style={styles.header}>
      <View>
        <Text style={styles.kicker}>FLARE CORE</Text>
        <Text style={styles.title}>{props.mode === 'chat' ? '聊天' : props.mode === 'sdk' ? 'SDK' : '消息'}</Text>
      </View>
      <View style={styles.headerActions}>
        <IconAction name="search" label="搜索" onPress={props.onSearch} />
        <IconAction name="plus" label="新建" primary onPress={props.onStartChat} />
        <IconAction name="ellipsis" label="更多" onPress={props.onMore} />
        <Badge text={props.totalUnread} overflowCount={99}>
          <View style={styles.headerBadgeAnchor} />
        </Badge>
      </View>
      <View style={styles.modeTabs}>
        <SegmentButton active={props.mode === 'conversations'} label="消息" onPress={() => props.onModeChange('conversations')} />
        <SegmentButton active={props.mode === 'chat'} label="聊天" onPress={() => props.onModeChange('chat')} />
        <SegmentButton active={props.mode === 'sdk'} label="SDK" onPress={() => props.onModeChange('sdk')} />
      </View>
    </View>
  );
}
