sealed class NxFeedback {
  const NxFeedback();
}

class RelayFeedback extends NxFeedback {
  const RelayFeedback({required this.ch, required this.value});

  final int ch;
  final bool value;
}

class IoFeedback extends NxFeedback {
  const IoFeedback({
    required this.port,
    required this.ch,
    required this.value,
  });

  final int port;
  final int ch;
  final bool value;
}

class SerialFeedback extends NxFeedback {
  const SerialFeedback({required this.port, required this.message});

  final int port;
  final String message;
}

class FeedbackParser {
  const FeedbackParser();

  NxFeedback? parse(String rawLine) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('set/')) return null;

    if (line.startsWith('serial/')) {
      final first = line.indexOf('/');
      final second = line.indexOf('/', first + 1);
      if (second < 0) return null;
      final port = int.tryParse(line.substring(first + 1, second));
      if (port == null) return null;
      return SerialFeedback(port: port, message: line.substring(second + 1));
    }

    final parts = line.split('/');
    switch (parts.first) {
      case 'relay':
        if (parts.length != 3) return null;
        final ch = int.tryParse(parts[1]);
        final value = _parseBit(parts[2]);
        if (ch == null || value == null) return null;
        return RelayFeedback(ch: ch, value: value);
      case 'io':
        if (parts.length != 4) return null;
        final port = int.tryParse(parts[1]);
        final ch = int.tryParse(parts[2]);
        final value = _parseBit(parts[3]);
        if (port == null || ch == null || value == null) return null;
        return IoFeedback(port: port, ch: ch, value: value);
    }
    return null;
  }

  bool? _parseBit(String raw) {
    if (raw == '1') return true;
    if (raw == '0') return false;
    return null;
  }
}
