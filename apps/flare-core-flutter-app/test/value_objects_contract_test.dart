import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('value object protocol mapping', () {
    test('rejects unknown local enum values instead of defaulting', () {
      expect(() => ConnectionState.fromValue(99), throwsArgumentError);
      expect(() => MessageStatus.fromValue(99), throwsArgumentError);
      expect(() => MessageSource.fromValue(99), throwsArgumentError);
    });

    test('rejects unknown proto status and source values', () {
      expect(() => MessageStatus.fromProtoWire(99), throwsArgumentError);
      expect(() => MessageSource.fromProtoWire(0), throwsArgumentError);
      expect(() => MessageSource.fromProtoWire(99), throwsArgumentError);
    });

    test('maps explicit proto source values to app display source', () {
      expect(MessageSource.fromProtoWire(1), MessageSource.remote);
      expect(MessageSource.fromProtoWire(2), MessageSource.remote);
      expect(MessageSource.fromProtoWire(3), MessageSource.remote);
      expect(MessageSource.fromProtoWire(4), MessageSource.remote);
    });
  });
}
