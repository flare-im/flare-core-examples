import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

void main() =>
    runApp(const MaterialApp(home: FlareTheme(child: CoreWorkbench())));

class CoreWorkbench extends StatefulWidget {
  const CoreWorkbench({super.key});

  @override
  State<CoreWorkbench> createState() => _CoreWorkbenchState();
}

class _CoreWorkbenchState extends State<CoreWorkbench> {
  final baseUrl = TextEditingController();
  final websocketUrl = TextEditingController();
  final quicUrl = TextEditingController();
  final mediaUrl = TextEditingController();
  final tenant = TextEditingController();
  final user = TextEditingController();
  final token = TextEditingController();
  final peer = TextEditingController();
  final draft = TextEditingController();
  final subscriptions = <core.EventSubscription>[];
  core.FlareImClient? client;
  core.Conversation? selected;
  List<core.Conversation> conversations = [];
  List<core.Message> messages = [];
  String status = '';
  bool busy = false;

  core.CoreEndpoints get endpoints => core.CoreEndpoints(
    baseUrl: baseUrl.text.trim(),
    websocketUrl: websocketUrl.text.trim(),
    quicUrl: optional(quicUrl.text),
    mediaBaseUrl: optional(mediaUrl.text),
  );

  String? optional(String input) => input.trim().isEmpty ? null : input.trim();

  void perform(Future<void> Function() action) {
    if (!busy) unawaited(run(action));
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      status = '';
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => status = error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> signIn() async {
    final sdk = core.FlareCoreSdk.createClient();
    final endpoint = endpoints;
    final development =
        kDebugMode &&
        Platform.isAndroid &&
        endpoint.baseUrl.startsWith('http://');
    try {
      final directory = await getApplicationSupportDirectory();
      await sdk.init({
        'environment': development ? 'development' : 'production',
        'sdkConfig': {
          'dataUrl': directory.uri.toString(),
          'tenantId': tenant.text.trim(),
          'endpoints': {
            'baseUrl': endpoint.baseUrl,
            'websocketUrl': endpoint.websocketUrl,
            if (endpoint.quicUrl != null) 'quicUrl': endpoint.quicUrl,
            if (endpoint.mediaBaseUrl != null)
              'mediaBaseUrl': endpoint.mediaBaseUrl,
          },
          if (development) 'auth': <String, Object?>{},
        },
      });
      await sdk.login({
        'userId': user.text.trim(),
        if (token.text.isNotEmpty) 'token': token.text.trim(),
      });
    } catch (_) {
      await sdk.dispose();
      rethrow;
    }
    if (!mounted) {
      await sdk.dispose();
      return;
    }
    setState(() => client = sdk);
    token.clear();
    subscriptions.addAll([
      sdk.events.onMessageReceived((_) => unawaited(refreshOnEvent(sdk))),
      sdk.events.onMessageReceivedBatch((_) => unawaited(refreshOnEvent(sdk))),
    ]);
    await refresh(sdk);
  }

  Future<void> refreshOnEvent(core.FlareImClient sdk) async {
    try {
      await refresh(sdk);
    } catch (error) {
      if (mounted && client == sdk) setState(() => status = error.toString());
    }
  }

  Future<void> refresh(core.FlareImClient sdk) async {
    final active = selected;
    final nextConversations =
        (await sdk.conversations.listConversations()).conversations;
    final nextMessages = active == null
        ? <core.Message>[]
        : (await sdk.messages.listMessages(
            core.ListMessagesRequest(
              conversationId: active.conversationId,
              limit: 50,
            ),
          )).messages.toList();
    nextMessages.sort((a, b) => a.conversationSeq.compareTo(b.conversationSeq));
    if (mounted && client == sdk && selected == active) {
      setState(() {
        conversations = nextConversations;
        messages = nextMessages;
      });
    }
  }

  void unsubscribe() {
    for (final subscription in subscriptions) {
      subscription.unsubscribe();
    }
    subscriptions.clear();
  }

  Future<void> attachFile(
    core.FlareImClient sdk,
    core.Conversation conversation,
  ) async {
    final selection = await FilePicker.platform.pickFiles();
    final path = selection?.files.single.path;
    if (path == null) return;
    final uploaded = await sdk.media.uploadFile({'absolutePath': path});
    final fileId = uploaded['fileId'];
    if (fileId is! String || fileId.isEmpty) {
      throw StateError('Media service returned no file ID');
    }
    final message = await sdk.messageBuilder.buildFile(
      core.BuildFileMessageRequest(
        conversationId: conversation.conversationId,
        fileId: fileId,
      ),
    );
    await sdk.messages.sendMessage(core.SendMessageRequest(message: message));
    await refresh(sdk);
  }

  Future<void> signOut(core.FlareImClient sdk) async {
    await sdk.logout();
    unsubscribe();
    if (mounted) {
      setState(() {
        client = null;
        selected = null;
        messages = [];
        conversations = [];
      });
    }
    await sdk.dispose();
  }

  @override
  void dispose() {
    unsubscribe();
    final sdk = client;
    if (sdk != null) unawaited(sdk.dispose());
    for (final controller in [
      baseUrl,
      websocketUrl,
      quicUrl,
      mediaUrl,
      tenant,
      user,
      token,
      peer,
      draft,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sdk = client;
    final conversation = selected;
    return Scaffold(
      appBar: AppBar(title: const Text('Flare Core')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FlareInput(controller: baseUrl, placeholder: 'Core HTTP base URL'),
          const SizedBox(height: 8),
          FlareInput(controller: websocketUrl, placeholder: 'WebSocket URL'),
          FlareInput(controller: quicUrl, placeholder: 'QUIC URL (optional)'),
          FlareInput(
            controller: mediaUrl,
            placeholder: 'Media base URL (optional)',
          ),
          const SizedBox(height: 8),
          if (sdk == null) ...[
            FlareInput(controller: tenant, placeholder: 'Tenant ID'),
            FlareInput(controller: user, placeholder: 'User ID'),
            FlareInput(
              controller: token,
              placeholder: 'Access token',
              secure: true,
            ),
            FlareButton(
              label: 'Sign in',
              loading: busy,
              onPressed: () => perform(signIn),
            ),
          ] else ...[
            Wrap(
              spacing: 8,
              children: [
                FlareButton(
                  label: 'Apply endpoints',
                  disabled: busy,
                  onPressed: () => perform(() async {
                    final result = await sdk.connection.replaceEndpoints(
                      endpoints,
                    );
                    if (mounted) {
                      setState(
                        () => status = 'Endpoint revision ${result.revision}',
                      );
                    }
                  }),
                ),
                FlareButton(
                  label: 'Sign out',
                  disabled: busy,
                  variant: FlareButtonVariant.secondary,
                  onPressed: () => perform(() => signOut(sdk)),
                ),
              ],
            ),
            FlareInput(controller: peer, placeholder: 'Peer user ID'),
            FlareButton(
              label: 'Open chat',
              disabled: busy,
              onPressed: () => perform(() async {
                final row = await sdk.conversations.getOneConversation({
                  'sourceId': peer.text.trim(),
                  'conversationType': 'single',
                });
                if (mounted) {
                  setState(() {
                    selected = row;
                    messages = [];
                  });
                }
                await refresh(sdk);
              }),
            ),
            for (final row in conversations)
              FlareButton(
                label: row.channelId,
                disabled: busy,
                variant: FlareButtonVariant.text,
                onPressed: () => perform(() async {
                  setState(() {
                    selected = row;
                    messages = [];
                  });
                  await refresh(sdk);
                }),
              ),
            for (final message in messages)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${message.senderId}: ${message.content?.data['text'] ?? 'Message'}',
                ),
              ),
            if (conversation != null) ...[
              FlareButton(
                label: 'Attach file',
                disabled: busy,
                onPressed: () => perform(() => attachFile(sdk, conversation)),
              ),
              FlareInput(
                controller: draft,
                placeholder: 'Message',
                multiline: true,
              ),
              FlareButton(
                label: 'Send',
                disabled: busy,
                onPressed: () => perform(() async {
                  if (draft.text.trim().isEmpty) return;
                  final message = await sdk.messageBuilder.buildText(
                    core.BuildTextMessageRequest(
                      conversationId: conversation.conversationId,
                      text: draft.text,
                    ),
                  );
                  await sdk.messages.sendMessage(
                    core.SendMessageRequest(message: message),
                  );
                  if (mounted) draft.clear();
                  await refresh(sdk);
                }),
              ),
            ],
          ],
          if (status.isNotEmpty)
            Semantics(liveRegion: true, child: Text(status)),
        ],
      ),
    );
  }
}
