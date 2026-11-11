import React from 'react';
import { Pressable, Text, View } from 'react-native';
import { IconOutline } from '@ant-design/icons-react-native';
import { colors } from '../../theme/tokens';
import { styles } from '../../styles';
import type { UploadTask } from '../../types';
import { uploadStatusText } from '../../utils';

export function UploadTaskRow(props: { task: UploadTask; onRemove: (id: string) => void }) {
  return (
    <View style={styles.uploadTask}>
      <View style={styles.rowBetween}>
        <Text style={styles.uploadName}>{props.task.name}</Text>
        <Pressable onPress={() => props.onRemove(props.task.id)}>
          <IconOutline name="close" size={16} color={colors.textMuted} />
        </Pressable>
      </View>
      <Text style={styles.metaText}>{uploadStatusText(props.task.status)} · {Math.round(props.task.progress)}%</Text>
      <View style={styles.progressRail}>
        <View style={[styles.progressFill, { width: `${Math.max(4, props.task.progress)}%` }]} />
      </View>
    </View>
  );
}
