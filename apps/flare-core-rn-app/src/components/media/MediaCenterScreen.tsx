import React from 'react';
import { Text, TextInput, View } from 'react-native';
import Button from '@ant-design/react-native/lib/button';
import WhiteSpace from '@ant-design/react-native/lib/white-space';
import { styles } from '../../styles';
import { colors, radius } from '../../theme/tokens';
import { RN_MEDIA_LAB_OPERATIONS } from '../../application/workbench/h5Parity';
import type { MediaQueryOp } from '../../types';

const mediaLabels: Record<MediaQueryOp, string> = {
  stats: '缓存统计',
  upload_file: '上传文件',
  upload_image: '上传图片',
  upload_video: '上传视频',
  upload_bytes: '上传字节',
  delete_file: '删除文件',
  url: '访问 URL',
  temp_url: '临时下载 URL',
  resolve: '解析访问',
  display_url: '展示 URL',
  cache_remote: '缓存远端',
  set_root: '设置缓存根',
  set_max: '设置缓存上限',
  download_subfolder: '下载目录',
  download_file: '下载文件',
  cancel_download: '取消下载',
  saved_path: '保存路径',
  delete_download: '删除下载',
  clear: '清理缓存',
};

export function MediaCenterScreen(props: {
  fileId: string;
  result: string;
  busy: boolean;
  onFileIdChange: (value: string) => void;
  onRunOp: (op: MediaQueryOp) => void;
  onBack: () => void;
}) {
  return (
    <>
      <View style={styles.card}>
        <View style={styles.cardHeader}>
          <Text style={styles.sectionTitle}>媒体中心</Text>
          <Button type="ghost" size="small" onPress={props.onBack}>
            返回
          </Button>
        </View>
        <TextInput
          value={props.fileId}
          onChangeText={props.onFileIdChange}
          placeholder="输入 fileId(缓存统计可留空)"
          placeholderTextColor={colors.textMuted}
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
        <View style={{ flexDirection: 'row', flexWrap: 'wrap' }}>
          {RN_MEDIA_LAB_OPERATIONS.map((op) => (
            <View key={op} style={{ marginRight: 8, marginBottom: 8 }}>
              <Button size="small" disabled={props.busy} onPress={() => props.onRunOp(op)}>
                {mediaLabels[op]}
              </Button>
            </View>
          ))}
        </View>
      </View>

      <WhiteSpace size="lg" />
      <View style={styles.card}>
        <Text style={styles.sectionTitle}>结果</Text>
        <Text style={[styles.statusLine, { color: colors.textMuted }]} selectable>
          {props.busy ? '查询中…' : props.result || '选择上方操作查看 core 媒体接口返回'}
        </Text>
      </View>
    </>
  );
}
