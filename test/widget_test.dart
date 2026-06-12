import 'package:flutter_test/flutter_test.dart';
import 'package:nx2200_controller/nx/feedback_parser.dart';
import 'package:nx2200_controller/nx/nx_command.dart';

void main() {
  group('NxCommand', () {
    test('builds relay command', () {
      expect(NxCommand.relay(3, 1), 'set/relay/3/1\r\n');
    });

    test('builds ir command', () {
      expect(NxCommand.ir(2, 5), 'set/ir/2/5\r\n');
    });

    test('builds serial command', () {
      expect(NxCommand.serial(1, 'PWR ON'), 'set/serial/1/PWR ON\r\n');
    });

    test('builds io command', () {
      expect(NxCommand.io(1, 3, 1), 'set/io/1/3/1\r\n');
    });
  });

  group('FeedbackParser', () {
    const parser = FeedbackParser();

    test('parses relay feedback', () {
      final parsed = parser.parse('relay/3/1') as RelayFeedback;
      expect(parsed.ch, 3);
      expect(parsed.value, isTrue);
    });

    test('parses io feedback', () {
      final parsed = parser.parse('io/1/3/0') as IoFeedback;
      expect(parsed.port, 1);
      expect(parsed.ch, 3);
      expect(parsed.value, isFalse);
    });

    test('keeps slashes in serial payload', () {
      final parsed = parser.parse('serial/2/a/b/c') as SerialFeedback;
      expect(parsed.port, 2);
      expect(parsed.message, 'a/b/c');
    });

    test('ignores invalid lines', () {
      expect(parser.parse('noise'), isNull);
      expect(parser.parse('set/relay/1/1'), isNull);
    });
  });
}
