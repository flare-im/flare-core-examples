import React from 'react';
import { Text, TextInput, View } from 'react-native';
import Button from '@ant-design/react-native/lib/button';
import WhiteSpace from '@ant-design/react-native/lib/white-space';
import { styles } from '../../styles';
import { colors, radius, spacing } from '../../theme/tokens';
import type { TimelineMessage } from '../../types';
import { renderMessageText } from '../../utils';

export function MessageSearchScreen(props: {
  query: string;
  results: TimelineMessage[];
  busy: boolean;
  error: string;
  onQueryChange: (value: string) => void;
  onSearch: () => void;
  onBack: () => void;
}) {
  return (
    <>
      <View style={styles.card}>
        <View style={styles.cardHeader}>
          <Text style={styles.sectionTitle}>搜索消息</Text>
          <Button type="ghost" size="small" onPress={props.onBack}>
            返回
          </Button>
        </View>
        <TextInput
          value={props.query}
          onChangeText={props.onQueryChange}
          onSubmitEditing={props.onSearch}
          placeholder="按关键词搜索当前会话消息"
          placeholderTextColor={colors.textMuted}
          returnKeyType="search"
          autoCapitalize="none"
          style={{
            borderWidth: 1,
            borderColor: colors.border,
            borderRadius: radius.card,
            paddingHorizontal: 12,
            paddingVertical: 8,
            color: colors.text,
            backgroundColor: colors.background,
          }}
        />
        <WhiteSpace size="sm" />
        <Button type="primary" size="small" loading={props.busy} onPress={props.onSearch}>
          搜索
        </Button>
        {props.error ? (
          <Text style={[styles.statusLine, { color: colors.danger }]}>{props.error}</Text>
        ) : null}
      </View>

      <WhiteSpace size="lg" />
      <View style={styles.card}>
        <Text style={styles.sectionTitle}>结果 · {props.results.length}</Text>
        {props.results.length === 0 ? (
          <Text style={[styles.statusLine, { color: colors.textMuted }]}>
            {props.busy ? '搜索中…' : '输入关键词后点击搜索'}
          </Text>
        ) : (
          props.results.map((message) => (
            <View
              key={message.id}
              style={{
                paddingVertical: spacing.item,
                borderTopWidth: 1,
                borderTopColor: colors.border,
              }}
            >
              <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
                <Text style={{ color: colors.text, fontWeight: '600' }}>{message.authorName}</Text>
                <Text style={{ color: colors.textMuted, fontSize: 12 }}>
                  {message.time} · seq {message.seq}
                </Text>
              </View>
              <Text style={{ color: colors.textMuted, marginTop: 2 }} numberOfLines={2}>
                {message.recalled ? '消息已撤回' : renderMessageText(message)}
              </Text>
            </View>
          ))
        )}
      </View>
    </>
  );
}
