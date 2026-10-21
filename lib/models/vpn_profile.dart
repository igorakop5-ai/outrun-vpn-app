import 'dart:convert';

enum VpnProtocol {
  vless,
  vmess,
  trojan,
  shadowsocks,
  subscription,
  unknown,
}

class VpnProfile {
  final String id;
  final String name;
  final VpnProtocol protocol;
  final String server;
  final int port;
  final String rawConfig;
  int? pingMs;
  final DateTime addedAt;

  VpnProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.server,
    required this.port,
    required this.rawConfig,
    this.pingMs,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'protocol': protocol.name,
      'server': server,
      'port': port,
      'rawConfig': rawConfig,
      'pingMs': pingMs,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory VpnProfile.fromMap(Map<String, dynamic> map) {
    return VpnProfile(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Outrun Server',
      protocol: VpnProtocol.values.firstWhere(
        (p) => p.name == map['protocol'],
        orElse: () => VpnProtocol.unknown,
      ),
      server: map['server'] ?? '',
      port: map['port'] ?? 443,
      rawConfig: map['rawConfig'] ?? '',
      pingMs: map['pingMs'],
      addedAt: map['addedAt'] != null
          ? DateTime.tryParse(map['addedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory VpnProfile.fromJson(String source) =>
      VpnProfile.fromMap(json.decode(source));
}
