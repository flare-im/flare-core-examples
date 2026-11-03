import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 平板/桌面分栏断点（与 Web workbench 接近）。
const double kWorkbenchWideBreakpoint = 900;

bool isWorkbenchWide(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= kWorkbenchWideBreakpoint;
}

/// 宽屏用 [GoRouter.go] 替换栈；手机用 [push]。
void navigateToChat(BuildContext context, String conversationId) {
  final cid = conversationId.trim();
  if (cid.isEmpty) {
    context.go('/conversations');
    return;
  }
  final path = '/chat/${Uri.encodeComponent(cid)}';
  if (isWorkbenchWide(context)) {
    context.go(path);
  } else {
    context.push(path);
  }
}

void navigateToMessageSearch(BuildContext context, {String? conversationId}) {
  final cid = conversationId?.trim() ?? '';
  final path = cid.isEmpty
      ? '/search'
      : '/chat/${Uri.encodeComponent(cid)}/search';
  context.push(path);
}
