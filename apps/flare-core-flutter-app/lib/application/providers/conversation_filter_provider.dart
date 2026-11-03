import 'package:flare_im/domain/value_objects/conversation_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final conversationFilterProvider = StateProvider<ConversationFilter>(
  (ref) => ConversationFilter.all,
);
