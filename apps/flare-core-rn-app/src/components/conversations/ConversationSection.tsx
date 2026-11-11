import React from 'react';
import { Text, View } from 'react-native';
import WhiteSpace from '@ant-design/react-native/lib/white-space';
import { styles } from '../../styles';
import type { ConversationItem } from '../../types';
import { ConversationRow } from './ConversationRow';

export function ConversationSection(props: {
  label: string;
  items: ConversationItem[];
  activeConversationId: string;
  onSelect: (id: string) => void;
}) {
  return (
    <View>
      <Text style={styles.sectionLabel}>{props.label}</Text>
      <WhiteSpace size="sm" />
      <View style={styles.card}>
        {props.items.map((item, index) => (
          <ConversationRow
            key={item.id}
            item={item}
            active={item.id === props.activeConversationId}
            last={index === props.items.length - 1}
            onPress={() => props.onSelect(item.id)}
          />
        ))}
        {!props.items.length && <Text style={styles.emptyInline}>暂无会话</Text>}
      </View>
    </View>
  );
}
