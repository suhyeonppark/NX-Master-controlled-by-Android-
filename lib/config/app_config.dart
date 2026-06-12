import '../models/wol_pc.dart';

class NxConnectionConfig {
  const NxConnectionConfig({
    required this.host,
    required this.port,
    required this.timeout,
  });

  final String host;
  final int port;
  final Duration timeout;
}

/// User-editable settings for the NX-2200 controller app.
class AppConfig {
  const AppConfig({
    this.nxIp = '192.168.1.100',
    this.nxPort = 6600,
    this.tcpTimeoutMs = 2000,
    this.buttonLockMs = 1000,
    this.pcs = const [],
  });

  final String nxIp;
  final int nxPort;

  final List<WolPc> pcs;
  final int tcpTimeoutMs;
  final int buttonLockMs;

  Duration get tcpTimeout => Duration(milliseconds: tcpTimeoutMs);
  Duration get buttonLock => Duration(milliseconds: buttonLockMs);

  NxConnectionConfig get nx =>
      NxConnectionConfig(host: nxIp, port: nxPort, timeout: tcpTimeout);

  AppConfig copyWith({
    String? nxIp,
    int? nxPort,
    int? tcpTimeoutMs,
    int? buttonLockMs,
    List<WolPc>? pcs,
  }) {
    return AppConfig(
      nxIp: nxIp ?? this.nxIp,
      nxPort: nxPort ?? this.nxPort,
      tcpTimeoutMs: tcpTimeoutMs ?? this.tcpTimeoutMs,
      buttonLockMs: buttonLockMs ?? this.buttonLockMs,
      pcs: pcs ?? this.pcs,
    );
  }

  Map<String, dynamic> toJson() => {
        'nx_ip': nxIp,
        'nx_port': nxPort,
        'tcp_timeout_ms': tcpTimeoutMs,
        'button_lock_ms': buttonLockMs,
        'wol_pcs': [for (final p in pcs) p.toJson()],
      };

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    const defaults = AppConfig();
    final rawPcs = json['wol_pcs'] as List<dynamic>? ?? const [];
    return AppConfig(
      nxIp: json['nx_ip'] as String? ??
          json['ce_rel8_ip'] as String? ??
          defaults.nxIp,
      nxPort: json['nx_port'] as int? ?? defaults.nxPort,
      tcpTimeoutMs: json['tcp_timeout_ms'] as int? ?? defaults.tcpTimeoutMs,
      buttonLockMs: json['button_lock_ms'] as int? ?? defaults.buttonLockMs,
      pcs: [
        for (final p in rawPcs) WolPc.fromJson(p as Map<String, dynamic>),
      ],
    );
  }
}
