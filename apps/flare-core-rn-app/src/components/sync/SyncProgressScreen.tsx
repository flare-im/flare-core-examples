import React from 'react';
import { Text, View } from 'react-native';
import { IconOutline } from '@ant-design/icons-react-native';
import Button from '@ant-design/react-native/lib/button';
import Progress from '@ant-design/react-native/lib/progress';
import Tag from '@ant-design/react-native/lib/tag';
import WhiteSpace from '@ant-design/react-native/lib/white-space';
import { colors } from '../../theme/tokens';
import { styles } from '../../styles';
import type { HomeSyncProgress, SdkStatus } from '../../types';
import { connectionText } from '../../utils';
import { KeyValue } from '../common';

export function SyncProgressScreen(props: {
  progress: HomeSyncProgress;
  conversationCount: number;
  totalUnread: number;
  sdkStatus: SdkStatus;
  running: boolean;
  onRunSync: () => void;
}) {
  const failed = props.progress.step === 'failed';
  const done = props.progress.step === 'ready';

  return (
    <View style={styles.syncPanel}>
      <View style={[styles.syncIcon, done && styles.syncIconDone, failed && styles.syncIconFailed]}>
        <IconOutline name={done ? 'check-circle' : failed ? 'close-circle' : 'comment'} size={34} color={done ? colors.success : failed ? colors.danger : colors.primary} />
      </View>
      <Text style={styles.kicker}>FLARE CORE RN</Text>
      <Text style={styles.syncTitle}>{props.progress.title}</Text>
      <Text style={styles.syncDetail}>{props.progress.detail}</Text>
      <Progress percent={props.progress.percent} position="normal" />

      <WhiteSpace size="lg" />
      <View style={styles.syncStats}>
        <KeyValue label="会话" value={String(props.conversationCount)} />
        <KeyValue label="未读" value={String(props.totalUnread)} />
        <KeyValue label="连接" value={connectionText(props.sdkStatus)} />
      </View>

      <WhiteSpace size="lg" />
      <View style={styles.rowBetween}>
        <Tag selected>{failed ? '同步失败' : done ? '已完成' : '同步中'}</Tag>
        {(failed || !props.running) && (
          <Button size="small" type="primary" loading={props.running} onPress={props.onRunSync}>
            {failed ? '重试' : '继续同步'}
          </Button>
        )}
      </View>
    </View>
  );
}
