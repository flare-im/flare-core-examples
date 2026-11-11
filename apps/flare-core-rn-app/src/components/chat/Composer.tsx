import React from 'react';
import { Pressable, Text, View } from 'react-native';
import { IconOutline } from '@ant-design/icons-react-native';
import Button from '@ant-design/react-native/lib/button';
import InputItem from '@ant-design/react-native/lib/input-item';
import List from '@ant-design/react-native/lib/list';
import WhiteSpace from '@ant-design/react-native/lib/white-space';
import { colors } from '../../theme/tokens';
import { styles } from '../../styles';
import type { ComposerPanel, TimelineMessage } from '../../types';
import { quickEmoji, stickerPacks } from '../../data/rnWorkbenchData';
import { IconAction } from '../common';

export function Composer(props: {
  value: string;
  panel: ComposerPanel;
  richMode: boolean;
  sending: boolean;
  replyMessage?: TimelineMessage;
  targetName: string;
  onChange: (value: string) => void;
  onPanelChange: (panel: ComposerPanel) => void;
  onRichModeChange: (enabled: boolean) => void;
  onInsertEmoji: (value: string) => void;
  onSendSticker: (value: string) => void;
  onClearReply: () => void;
  onSend: () => void;
}) {
  const insertCommand = (command: string) => {
    const prefix = props.value.trim().length ? ' ' : '';
    props.onChange(`${props.value}${prefix}/${command} `);
    props.onPanelChange(null);
  };
  const moreGroups = [
    {
      title: '媒体',
      items: [
        { label: '文件', icon: 'file', command: 'file' },
        { label: '视频', icon: 'video-camera', command: 'video' },
      ],
    },
    {
      title: '位置与人',
      items: [
        { label: '位置', icon: 'environment', command: 'location' },
        { label: '名片', icon: 'idcard', command: 'card' },
      ],
    },
    {
      title: '协作',
      items: [
        { label: '任务', icon: 'check-square', command: 'task' },
        { label: '日程', icon: 'calendar', command: 'schedule' },
        { label: '投票', icon: 'bar-chart', command: 'poll' },
      ],
    },
    {
      title: '富内容',
      items: [
        { label: '链接', icon: 'link', command: 'link' },
        { label: '小程序', icon: 'appstore', command: 'miniapp' },
      ],
    },
    {
      title: '广播',
      items: [
        { label: '话题', icon: 'message', command: 'topic' },
        { label: '通知', icon: 'notification', command: 'notice' },
        { label: '公告', icon: 'sound', command: 'announcement' },
      ],
    },
  ] as const;

  return (
    <View style={styles.composerCard}>
      {props.replyMessage && (
        <View style={styles.replyPreview}>
          <View>
            <Text style={styles.replyTitle}>回复 {props.replyMessage.authorName}</Text>
            <Text style={styles.replyText} numberOfLines={1}>{props.replyMessage.text}</Text>
          </View>
          <IconAction name="close" label="清除回复" onPress={props.onClearReply} />
        </View>
      )}
      <View style={styles.composerTools}>
        <IconAction name="smile" label="表情" active={props.panel === 'emoji'} onPress={() => props.onPanelChange(props.panel === 'emoji' ? null : 'emoji')} />
        <IconAction name="picture" label="图片" onPress={() => insertCommand('image')} />
        <IconAction name="audio" label="语音" onPress={() => insertCommand('voice')} />
        <IconAction name="font-size" label="富文本" active={props.richMode} onPress={() => {
          props.onRichModeChange(!props.richMode);
          props.onPanelChange(null);
        }} />
        <IconAction name="plus" label="更多" active={props.panel === 'more'} onPress={() => props.onPanelChange(props.panel === 'more' ? null : 'more')} />
      </View>
      {props.panel === 'emoji' && (
        <View style={styles.panelGrid}>
          {quickEmoji.map((emoji) => (
            <Pressable key={emoji} style={styles.emojiTile} onPress={() => props.onInsertEmoji(emoji)}>
              <Text style={styles.emojiText}>{emoji}</Text>
            </Pressable>
          ))}
          {stickerPacks.map((sticker) => (
            <Pressable key={sticker} style={styles.stickerTile} onPress={() => props.onSendSticker(`【${sticker}贴纸】`)}>
              <Text style={styles.stickerText}>{sticker}</Text>
            </Pressable>
          ))}
        </View>
      )}
      {props.richMode && (
        <View style={styles.formatBar}>
          <Button size="small" onPress={() => props.onChange(`${props.value}**加粗**`)}>B</Button>
          <Button size="small" onPress={() => props.onChange(`${props.value}> 引用`)}>“</Button>
          <Button size="small" onPress={() => props.onChange(`${props.value}- 列表`)}>•</Button>
          <Button size="small" onPress={() => props.onChange(`${props.value}[链接](https://)`)}>↗</Button>
        </View>
      )}
      {props.panel === 'more' && (
        <View style={styles.attachmentGrid}>
          {moreGroups.map((group) => (
            <View key={group.title} style={styles.attachmentGroup}>
              <Text style={styles.attachmentGroupTitle}>{group.title}</Text>
              <View style={styles.attachmentGroupItems}>
                {group.items.map((item) => (
                  <Pressable key={item.label} style={styles.attachmentItem} onPress={() => insertCommand(item.command)}>
                    <IconOutline name={item.icon} size={20} color={colors.primary} />
                    <Text style={styles.attachmentText}>{item.label}</Text>
                  </Pressable>
                ))}
              </View>
            </View>
          ))}
        </View>
      )}
      <List styles={{ Body: styles.inputListBody }}>
        <InputItem clear value={props.value} placeholder={`发送给 ${props.targetName}`} onChange={props.onChange}>
          消息
        </InputItem>
      </List>
      <WhiteSpace size="sm" />
      <Button type="primary" loading={props.sending} disabled={!props.value.trim()} onPress={props.onSend}>
        发送
      </Button>
    </View>
  );
}
