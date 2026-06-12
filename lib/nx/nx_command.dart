/// Central NX-2200 wire-format builder.
///
/// Keep every TCP command string here so UI and routing code never know the
/// transport format.
class NxCommand {
  NxCommand._();

  static const String terminator = '\r\n';

  static String relay(int ch, int value) =>
      'set/relay/$ch/${_bit(value)}$terminator';

  static String ir(int port, int ch) => 'set/ir/$port/$ch$terminator';

  static String serial(int port, String message) {
    final sanitized = message.replaceAll('\r', ' ').replaceAll('\n', ' ');
    return 'set/serial/$port/$sanitized$terminator';
  }

  static String io(int port, int ch, int value) =>
      'set/io/$port/$ch/${_bit(value)}$terminator';

  static int _bit(int value) => value == 0 ? 0 : 1;
}
