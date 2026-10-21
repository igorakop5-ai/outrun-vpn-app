import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/vpn_profile.dart';

class ConfigParser {
  /// Main entrypoint to parse text from clipboard or user input
  static Future<List<VpnProfile>> parse(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw Exception('Буфер обмена пуст');
    }

    // 1. Is it a subscription HTTP/HTTPS URL?
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return await _fetchSubscription(trimmed);
    }

    // 2. Is it a direct protocol link?
    if (_isSupportedProtocol(trimmed)) {
      final profile = _parseSingleUri(trimmed);
      return [profile];
    }

    // 3. Could it be multiple lines or base64?
    if (trimmed.contains('\n')) {
      final lines = trimmed.split('\n');
      final list = <VpnProfile>[];
      for (final line in lines) {
        final l = line.trim();
        if (_isSupportedProtocol(l)) {
          try {
            list.add(_parseSingleUri(l));
          } catch (_) {}
        }
      }
      if (list.isNotEmpty) return list;
    }

    // 4. Try base64 decoding (many subscriptions return base64 without scheme)
    try {
      final decoded = utf8.decode(base64.decode(base64.normalize(trimmed)));
      final lines = decoded.split(RegExp(r'[\r\n]+'));
      final list = <VpnProfile>[];
      for (final line in lines) {
        final l = line.trim();
        if (_isSupportedProtocol(l)) {
          try {
            list.add(_parseSingleUri(l));
          } catch (_) {}
        }
      }
      if (list.isNotEmpty) return list;
    } catch (_) {}

    throw Exception('Неизвестный формат ключа или ссылки');
  }

  static bool _isSupportedProtocol(String text) {
    return text.startsWith('vless://') ||
        text.startsWith('vmess://') ||
        text.startsWith('trojan://') ||
        text.startsWith('ss://');
  }

  static Future<List<VpnProfile>> _fetchSubscription(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'OutrunVPN/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Ошибка загрузки подписки (HTTP ${response.statusCode})');
      }

      final body = response.body.trim();
      // Try to parse body directly or base64 decoded
      String decodedBody = body;
      try {
        decodedBody = utf8.decode(base64.decode(base64.normalize(body)));
      } catch (_) {}

      final lines = decodedBody.split(RegExp(r'[\r\n]+'));
      final profiles = <VpnProfile>[];

      for (final line in lines) {
        final l = line.trim();
        if (_isSupportedProtocol(l)) {
          try {
            profiles.add(_parseSingleUri(l));
          } catch (_) {}
        }
      }

      if (profiles.isEmpty) {
        throw Exception('В подписке не найдено доступных серверов');
      }

      return profiles;
    } catch (e) {
      throw Exception('Не удалось загрузить подписку: $e');
    }
  }

  static VpnProfile _parseSingleUri(String raw) {
    final uri = Uri.parse(raw);
    final scheme = uri.scheme.toLowerCase();
    
    // Extract friendly name from fragment #Name
    String name = 'Outrun Server';
    if (uri.fragment.isNotEmpty) {
      name = Uri.decodeComponent(uri.fragment);
    } else if (uri.host.isNotEmpty) {
      name = uri.host;
    }

    VpnProtocol protocol = VpnProtocol.unknown;
    String host = uri.host;
    int port = uri.port > 0 ? uri.port : 443;

    if (scheme == 'vless') {
      protocol = VpnProtocol.vless;
    } else if (scheme == 'vmess') {
      protocol = VpnProtocol.vmess;
      // VMess URLs often encode JSON in base64 after vmess://
      try {
        final b64 = raw.substring('vmess://'.length);
        final jsonStr = utf8.decode(base64.decode(base64.normalize(b64)));
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        name = data['ps'] ?? name;
        host = data['add'] ?? host;
        port = int.tryParse(data['port']?.toString() ?? '') ?? port;
      } catch (_) {}
    } else if (scheme == 'trojan') {
      protocol = VpnProtocol.trojan;
    } else if (scheme == 'ss') {
      protocol = VpnProtocol.shadowsocks;
    }

    final id = 'outrun_${raw.hashCode.abs()}';

    return VpnProfile(
      id: id,
      name: name,
      protocol: protocol,
      server: host,
      port: port,
      rawConfig: raw,
    );
  }
}
