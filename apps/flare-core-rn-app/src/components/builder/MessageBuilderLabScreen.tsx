import React from 'react';
import { Text, View } from 'react-native';
import Button from '@ant-design/react-native/lib/button';
import WhiteSpace from '@ant-design/react-native/lib/white-space';
import { MessageBuildOp } from '@flare-im/sdk/model';
import { styles } from '../../styles';
import { colors, spacing } from '../../theme/tokens';

const BUILDER_OPS: Array<{ op: MessageBuildOp; label: string }> = [
  { op: MessageBuildOp.CreateText, label: '文本' },
  { op: MessageBuildOp.CreateEmoji, label: '表情' },
  { op: MessageBuildOp.CreateLocation, label: '位置' },
  { op: MessageBuildOp.CreateLinkCard, label: '链接卡片' },
  { op: MessageBuildOp.CreateCard, label: '卡片' },
  { op: MessageBuildOp.CreateMiniProgram, label: '小程序' },
  { op: MessageBuildOp.CreateSystem, label: '系统消息' },
  { op: MessageBuildOp.CreateNotification, label: '通知' },
  { op: MessageBuildOp.CreateAnnouncement, label: '公告' },
  { op: MessageBuildOp.CreateVote, label: '投票' },
  { op: MessageBuildOp.CreateTask, label: '任务' },
  { op: MessageBuildOp.CreateSchedule, label: '日程' },
  { op: MessageBuildOp.CreateCustom, label: '自定义' },
  { op: MessageBuildOp.CreatePlaceholder, label: '占位' },
];

export function MessageBuilderLabScreen(props: {
  busy: boolean;
  message: string;
  hasConversation: boolean;
  onRunOp: (op: MessageBuildOp) => void;
  onBack: () => void;
}) {
  return (
    <>
      <View style={styles.card}>
        <View style={styles.cardHeader}>
          <Text style={styles.sectionTitle}>消息构建 Lab</Text>
          <Button type="ghost" size="small" onPress={props.onBack}>
            返回
          </Button>
        </View>
        <Text
          style={[styles.statusLine, { color: props.hasConversation ? colors.textMuted : colors.warning }]}
        >
          {props.hasConversation
            ? '点击任一类型,通过 core messageBuilder 构建并发送到当前会话'
            : '请先选择一个会话再构建消息'}
        </Text>
        {props.message ? (
          <Text style={[styles.statusLine, { color: colors.primary }]}>{props.message}</Text>
        ) : null}
      </View>

      <WhiteSpace size="lg" />
      <View style={styles.card}>
        <Text style={styles.sectionTitle}>结构化构建操作 · {BUILDER_OPS.length}</Text>
        <WhiteSpace size="sm" />
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginHorizontal: -spacing.item / 2 }}>
          {BUILDER_OPS.map((entry) => (
            <View
              key={entry.op}
              style={{ width: '33.33%', paddingHorizontal: spacing.item / 2, marginBottom: spacing.item }}
            >
              <Button
                size="small"
                disabled={props.busy || !props.hasConversation}
                onPress={() => props.onRunOp(entry.op)}
              >
                {entry.label}
              </Button>
            </View>
          ))}
        </View>
      </View>
    </>
  );
}
