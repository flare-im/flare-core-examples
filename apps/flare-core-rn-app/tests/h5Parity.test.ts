import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import {
  RN_CONVERSATION_ACTIONS,
  RN_MEDIA_LAB_OPERATIONS,
  RN_MESSAGE_DISPATCH_OPERATIONS,
  RN_SDK_LAB_TABS,
  RN_WORKBENCH_STAGES,
  shouldShowLogin,
  shouldShowSync,
} from '../src/application/workbench/h5Parity.ts';

const appRoot = join(import.meta.dirname, '..');

function read(path: string): string {
  return readFileSync(join(appRoot, path), 'utf8');
}

test('RN workbench starts with the same login and sync gates as the H5 app', () => {
  assert.deepEqual(RN_WORKBENCH_STAGES, ['login', 'sync', 'conversations', 'chat', 'sdk']);
  assert.equal(shouldShowLogin({ loggedIn: false, homeSyncReady: false }), true);
  assert.equal(shouldShowLogin({ loggedIn: true, homeSyncReady: false }), false);
  assert.equal(shouldShowSync({ loggedIn: true, homeSyncReady: false }), true);
  assert.equal(shouldShowSync({ loggedIn: false, homeSyncReady: false }), false);
  assert.equal(shouldShowSync({ loggedIn: true, homeSyncReady: true }), false);

  const appSource = read('src/screens/App.tsx');
  assert.match(appSource, /workbench\.mode === 'login'/);
  assert.match(appSource, /workbench\.mode === 'sync'/);
});

test('RN workbench exposes the H5 conversation and SDK Lab operation surface', () => {
  assert.deepEqual(RN_CONVERSATION_ACTIONS, [
    'mark_read',
    'mark_unread',
    'pin',
    'unpin',
    'mute',
    'unmute',
    'archive',
    'unarchive',
    'clear_history',
    'draft',
    'delete',
  ]);
  assert.deepEqual(RN_SDK_LAB_TABS, [
    'diagnostics',
    'connection-session',
    'builder',
    'message-dispatch',
    'sync-presence',
    'capability',
    'media',
    'events',
  ]);
  assert.deepEqual(RN_MESSAGE_DISPATCH_OPERATIONS, [
    'search',
    'search_in_conversation',
    'get',
    'get_raw',
    'edit_text_by_message_id',
    'edit_rich_doc_by_message_id',
    'delete_for_self',
    'delete_for_everyone',
    'add_reaction',
    'remove_reaction',
    'pin_by_message_id',
    'unpin_by_message_id',
    'mark_by_message_id',
    'mark_with_color',
    'unmark_by_message_id',
    'typing',
    'mark_read',
    'mark_read_and_burn',
  ]);
  assert.deepEqual(RN_MEDIA_LAB_OPERATIONS, [
    'stats',
    'upload_file',
    'upload_image',
    'upload_video',
    'upload_bytes',
    'delete_file',
    'url',
    'temp_url',
    'resolve',
    'display_url',
    'cache_remote',
    'set_root',
    'set_max',
    'download_subfolder',
    'download_file',
    'cancel_download',
    'saved_path',
    'delete_download',
    'clear',
  ]);
});

test('RN chat composer routes structured content through messageBuilder instead of placeholder commands', () => {
  const controller = read('src/hooks/useRnWorkbenchController.ts');
  const service = read('src/application/sdk/rnWorkbenchSdkService.ts');

  assert.doesNotMatch(controller, /等待 native message_builder|仅通过 core SDK 文本发送/);
  assert.match(service, /buildTypedMessage/);
  assert.match(service, /CreateSticker/);
  assert.match(service, /CreateImage/);
  assert.match(service, /CreateRichDoc/);
});
