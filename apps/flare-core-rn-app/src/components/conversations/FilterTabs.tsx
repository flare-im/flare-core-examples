import React from 'react';
import { ScrollView } from 'react-native';
import { styles } from '../../styles';
import type { ConversationFilter } from '../../types';
import { filters } from '../../data/rnWorkbenchData';
import { SegmentButton } from '../common';

export function FilterTabs(props: { activeFilter: ConversationFilter; onChange: (filter: ConversationFilter) => void }) {
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterRow}>
      {filters.map((filter) => (
        <SegmentButton
          key={filter.value}
          active={props.activeFilter === filter.value}
          label={filter.label}
          onPress={() => props.onChange(filter.value)}
        />
      ))}
    </ScrollView>
  );
}
