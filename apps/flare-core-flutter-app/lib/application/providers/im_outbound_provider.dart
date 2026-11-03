import 'package:flare_im/application/outbound/im_outbound_facade.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 出站门面：供 `interface/` 发起所有会触达 SDK 的操作。
final imOutboundProvider = Provider<ImOutboundFacade>(
  (ref) => ImOutboundFacade(ref),
);
