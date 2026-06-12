/// Connectivity state of a single CE device, shown in the status bar and the
/// settings connection test.
///
/// Named `DeviceConnectionState` (not `ConnectionState`) to avoid clashing
/// with Flutter's `ConnectionState` from material/async.
enum DeviceConnectionState {
  /// Not tested yet this session.
  unknown,

  /// A test/connect is in progress.
  checking,

  /// Last connection attempt succeeded.
  online,

  /// Last connection attempt failed.
  offline,
}

/// Immutable snapshot of one device's connection status plus an optional
/// detail string (e.g. an error reason for OFFLINE).
class DeviceStatus {
  const DeviceStatus({
    this.state = DeviceConnectionState.unknown,
    this.detail,
  });

  final DeviceConnectionState state;
  final String? detail;

  bool get isOnline => state == DeviceConnectionState.online;

  /// Short label such as "ONLINE", "OFFLINE", "확인 중...".
  String get label {
    switch (state) {
      case DeviceConnectionState.online:
        return 'ONLINE';
      case DeviceConnectionState.offline:
        return 'OFFLINE';
      case DeviceConnectionState.checking:
        return '확인 중...';
      case DeviceConnectionState.unknown:
        return '미확인';
    }
  }

  DeviceStatus copyWith({DeviceConnectionState? state, String? detail}) {
    return DeviceStatus(
      state: state ?? this.state,
      detail: detail,
    );
  }
}
