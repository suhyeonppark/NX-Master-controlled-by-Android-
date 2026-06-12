import 'dart:io';
import 'dart:typed_data';

import '../models/command_result.dart';

/// Sends Wake-on-LAN "magic packets" over UDP broadcast.
///
/// The magic packet is the standard, vendor-independent format: 6 bytes of
/// 0xFF followed by the target MAC repeated 16 times (102 bytes total),
/// broadcast to the local subnet. We send to the usual WoL ports (9 and 7) and
/// repeat a few times since UDP is best-effort.
///
/// Like the CE clients, this NEVER throws — every error is converted into a
/// friendly Korean [CommandResult].
class WolClient {
  static const List<int> _ports = [9, 7];
  static const int _repeat = 3;

  /// Broadcasts a magic packet for [mac]. [name] is only used in messages.
  Future<CommandResult> wake(String mac, {String name = 'PC'}) async {
    final macBytes = parseMac(mac);
    if (macBytes == null) {
      return CommandResult.fail('$name: 잘못된 MAC 주소입니다 ($mac)');
    }

    final packet = Uint8List(102);
    for (var i = 0; i < 6; i++) {
      packet[i] = 0xFF;
    }
    for (var rep = 0; rep < 16; rep++) {
      packet.setRange(6 + rep * 6, 6 + rep * 6 + 6, macBytes);
    }

    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final broadcast = InternetAddress('255.255.255.255');

      var sent = 0;
      for (var i = 0; i < _repeat; i++) {
        for (final port in _ports) {
          sent += socket.send(packet, broadcast, port);
        }
      }
      if (sent == 0) {
        return CommandResult.fail('$name: 매직 패킷 전송 실패');
      }
      return CommandResult.ok('$name 깨우기 패킷 전송됨', sentCommands: ['WOL $mac']);
    } catch (e) {
      return CommandResult.fail('$name: WoL 오류 - $e');
    } finally {
      socket?.close();
    }
  }

  /// Parses a MAC string into 6 bytes, accepting `:`, `-`, `.` or no separators.
  /// Returns null if it is not a valid 12-hex-digit address.
  static Uint8List? parseMac(String mac) {
    final hex = mac.replaceAll(RegExp(r'[:\-.\s]'), '').toUpperCase();
    if (hex.length != 12) return null;
    final out = Uint8List(6);
    for (var i = 0; i < 6; i++) {
      final b = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      if (b == null) return null;
      out[i] = b;
    }
    return out;
  }
}
