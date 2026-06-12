/// A Wake-on-LAN target PC: a display name plus its NIC MAC address.
///
/// Persisted as part of [AppConfig]. The [id] is stable for the lifetime of the
/// entry so generated action ids (`wol_<id>`) stay valid across edits.
class WolPc {
  const WolPc({required this.id, required this.name, required this.mac});

  final String id;
  final String name;

  /// MAC address as typed by the user (any common separator). Normalised at
  /// send time by the WoL client.
  final String mac;

  WolPc copyWith({String? name, String? mac}) =>
      WolPc(id: id, name: name ?? this.name, mac: mac ?? this.mac);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'mac': mac};

  factory WolPc.fromJson(Map<String, dynamic> j) => WolPc(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        mac: j['mac'] as String? ?? '',
      );
}
