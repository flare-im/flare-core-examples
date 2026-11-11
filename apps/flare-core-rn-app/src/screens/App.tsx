import React from 'react';
import Provider from '@ant-design/react-native/lib/provider';
import WhiteSpace from '@ant-design/react-native/lib/white-space';
import WingBlank from '@ant-design/react-native/lib/wing-blank';
import { KeyboardAvoidingView, Platform, SafeAreaView, ScrollView, StatusBar } from 'react-native';
import { colors } from '../theme/tokens';
import { styles } from '../styles';
import { AppHeader } from '../components/AppHeader';
import { LoginScreen } from '../components/auth/LoginScreen';
import { ChatScreen } from '../components/chat/ChatScreen';
import { ConversationScreen } from '../components/conversations/ConversationScreen';
import { MoreSheet } from '../components/sheets/MoreSheet';
import { SdkScreen } from '../components/sdk/SdkScreen';
import { MessageSearchScreen } from '../components/search/MessageSearchScreen';
import { MessageBuilderLabScreen } from '../components/builder/MessageBuilderLabScreen';
import { MediaCenterScreen } from '../components/media/MediaCenterScreen';
import { SyncProgressScreen } from '../components/sync/SyncProgressScreen';
import { useRnWorkbenchController } from '../hooks/useRnWorkbenchController';
import { connectionText } from '../utils';

export default function App() {
  const workbench = useRnWorkbenchController();
  const showWorkbenchChrome = workbench.mode !== 'login' && workbench.mode !== 'sync';
  const showLogin = workbench.mode === 'login';

  return (
    <Provider>
      <SafeAreaView style={[styles.safeArea, showLogin && styles.loginSafeArea]}>
        <StatusBar barStyle={showLogin ? 'light-content' : 'dark-content'} backgroundColor={showLogin ? '#171a20' : colors.background} />
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.keyboardAvoiding}>
          <ScrollView contentContainerStyle={[styles.content, showLogin && styles.loginContent]} keyboardShouldPersistTaps="handled">
            {showWorkbenchChrome && (
              <AppHeader
                mode={workbench.mode}
                totalUnread={workbench.totalUnread}
                onModeChange={workbench.setMode}
                onSearch={() => workbench.setConversationSearchOpen((open) => !open)}
                onStartChat={() => workbench.setStartChatOpen((open) => !open)}
                onMore={() => workbench.setMoreOpen((open) => !open)}
              />
            )}

            {showWorkbenchChrome && <WhiteSpace size="lg" />}

            {showLogin ? (
              <LoginScreen
                form={workbench.loginForm}
                sdkStatus={workbench.sdkStatus}
                sdkMessage={workbench.sdkMessage}
                loading={workbench.sdkStatus === 'connecting'}
                onChange={workbench.updateLoginForm}
                onLogin={workbench.initializeSdk}
              />
            ) : (
              <WingBlank size="lg">
                {workbench.mode === 'sync' && (
                  <SyncProgressScreen
                    progress={workbench.homeSyncProgress}
                    conversationCount={workbench.conversations.length}
                    totalUnread={workbench.totalUnread}
                    sdkStatus={workbench.sdkStatus}
                    running={workbench.homeSyncRunning}
                    onRunSync={() => workbench.runHomeSync()}
                  />
                )}

                {workbench.mode === 'conversations' && (
                  <ConversationScreen
                    conversations={workbench.visibleConversations}
                    pinnedConversations={workbench.pinnedConversations}
                    restConversations={workbench.restConversations}
                    activeConversationId={workbench.activeConversationId}
                    activeFilter={workbench.activeFilter}
                    connectionText={connectionText(workbench.sdkStatus)}
                    conversationSearchOpen={workbench.conversationSearchOpen}
                    conversationSearchQuery={workbench.conversationSearchQuery}
                    pinnedCount={workbench.pinnedCount}
                    totalUnread={workbench.totalUnread}
                    sdkStatus={workbench.sdkStatus}
                    startChatOpen={workbench.startChatOpen}
                    startPeerUserId={workbench.startPeerUserId}
                    onFilterChange={workbench.setActiveFilter}
                    onSearchChange={workbench.setConversationSearchQuery}
                    onSelect={workbench.selectConversation}
                    onStartPeerChange={workbench.setStartPeerUserId}
                    onCreateConversation={workbench.createConversation}
                  />
                )}

                {workbench.mode === 'chat' && workbench.activeConversation && (
                  <ChatScreen
                    conversation={workbench.activeConversation}
                    messages={workbench.messages}
                    composer={workbench.composer}
                    composerPanel={workbench.composerPanel}
                    composerRichMode={workbench.composerRichMode}
                    sending={workbench.sending}
                    sdkStatus={workbench.sdkStatus}
                    pinnedMessages={workbench.pinnedMessages}
                    replyMessage={workbench.messages.find((item) => item.id === workbench.replyMessageId)}
                    uploadTasks={workbench.uploadTasks}
                    multiSelectMode={workbench.multiSelectMode}
                    selectedMessageIds={workbench.selectedMessageIds}
                    selectedCount={workbench.selectedCount}
                    onBack={() => (workbench.multiSelectMode ? workbench.exitMultiSelect() : workbench.setMode('conversations'))}
                    onOpenSdk={() => workbench.setMode('sdk')}
                    onOpenMore={() => workbench.setMoreOpen((open) => !open)}
                    onComposerChange={workbench.setComposer}
                    onPanelChange={workbench.setComposerPanel}
                    onRichModeChange={workbench.setComposerRichMode}
                    onInsertEmoji={workbench.appendEmoji}
                    onSendSticker={workbench.sendSticker}
                    onSend={() => workbench.sendLocalMessage()}
                    onReply={(id) => {
                      workbench.setReplyMessageId(id);
                      workbench.setComposerPanel(null);
                    }}
                    onClearReply={() => workbench.setReplyMessageId('')}
                    onReact={workbench.reactMessage}
                    onRetry={workbench.retryMessage}
                    onEnterMultiSelect={workbench.enterMultiSelect}
                    onToggleSelected={workbench.toggleMessageSelection}
                    onExitMultiSelect={workbench.exitMultiSelect}
                    onRemoveUploadTask={workbench.removeUploadTask}
                  />
                )}

                {workbench.mode === 'sdk' && (
                  <SdkScreen
                    sdkStatus={workbench.sdkStatus}
                    sdkMessage={workbench.sdkMessage}
                    sdkDiagnostics={workbench.sdkDiagnostics}
                    activeConversation={workbench.activeConversation}
                    messageCount={workbench.messages.length}
                    latestMessageId={workbench.latestMessage?.id ?? ''}
                    onInitialize={workbench.initializeSdk}
                    sdkLabInputs={workbench.sdkLabInputs}
                    sdkLabResult={workbench.sdkLabResult}
                    messageBuildCatalog={workbench.messageBuildCatalog}
                    onUpdateSdkLabInputs={workbench.updateSdkLabInputs}
                    onRunBuilderOp={workbench.runBuilderOp}
                    onRunMessageDispatch={workbench.runMessageDispatch}
                    onRunMediaOperation={workbench.runMediaQuery}
                    onRunCapabilityOperation={workbench.runCapabilityOperation}
                    onRunConnectionOperation={workbench.runConnectionOperation}
                    onRunSessionOperation={workbench.runSessionOperation}
                    onRunEventOperation={workbench.runEventOperation}
                  />
                )}

                {workbench.mode === 'search' && (
                  <MessageSearchScreen
                    query={workbench.messageSearchQuery}
                    results={workbench.messageSearchResults}
                    busy={workbench.messageSearchBusy}
                    error={workbench.messageSearchError}
                    onQueryChange={workbench.setMessageSearchQuery}
                    onSearch={workbench.runMessageSearch}
                    onBack={() => workbench.setMode(workbench.activeConversation ? 'chat' : 'conversations')}
                  />
                )}

                {workbench.mode === 'builder' && (
                  <MessageBuilderLabScreen
                    busy={workbench.builderBusy}
                    message={workbench.builderMessage}
                    hasConversation={Boolean(workbench.activeConversation)}
                    onRunOp={workbench.runBuilderOp}
                    onBack={() => workbench.setMode(workbench.activeConversation ? 'chat' : 'conversations')}
                  />
                )}

                {workbench.mode === 'media' && (
                  <MediaCenterScreen
                    fileId={workbench.mediaFileId}
                    result={workbench.mediaResult}
                    busy={workbench.mediaBusy}
                    onFileIdChange={workbench.setMediaFileId}
                    onRunOp={workbench.runMediaQuery}
                    onBack={() => workbench.setMode(workbench.activeConversation ? 'chat' : 'conversations')}
                  />
                )}

                {workbench.moreOpen && (
                  <>
                    <WhiteSpace size="lg" />
                    <MoreSheet
                      mode={workbench.mode}
                      sdkStatus={workbench.sdkStatus}
                      currentUserId={workbench.currentUserId}
                      onClose={() => workbench.setMoreOpen(false)}
                      onOpenSdk={() => {
                        workbench.setMode('sdk');
                        workbench.setMoreOpen(false);
                      }}
                      onOpenSearch={() => {
                        workbench.setMode('search');
                        workbench.setMoreOpen(false);
                      }}
                      onOpenBuilder={() => {
                        workbench.setMode('builder');
                        workbench.setMoreOpen(false);
                      }}
                      onOpenMedia={() => {
                        workbench.setMode('media');
                        workbench.setMoreOpen(false);
                      }}
                      onSync={() => {
                        workbench.runHomeSync();
                        workbench.setMoreOpen(false);
                      }}
                      onLogout={workbench.logout}
                      onMarkRead={workbench.markActiveRead}
                      onMarkUnread={workbench.markActiveUnread}
                      onTogglePin={() => workbench.toggleConversationFlag('pinned')}
                      onToggleMute={() => workbench.toggleConversationFlag('muted')}
                      onToggleArchive={() => workbench.toggleConversationFlag('archived')}
                      onClearHistory={workbench.clearActiveHistory}
                      onDelete={workbench.deleteActiveConversation}
                    />
                  </>
                )}
              </WingBlank>
            )}
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </Provider>
  );
}
