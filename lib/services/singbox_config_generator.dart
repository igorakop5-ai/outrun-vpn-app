import 'dart:convert';
import '../models/vpn_profile.dart';

class SingboxConfigGenerator {
  static const int localPort = 2080;

  static Map<String, dynamic> generateConfig(VpnProfile profile) {
    final outbound = _buildProxyOutbound(profile);

    return {
      'log': {
        'level': 'info',
        'timestamp': true,
      },
      'dns': {
        'servers': [
          {
            'tag': 'dns-remote',
            'address': 'tcp://1.1.1.1',
            'detour': 'proxy',
          },
          {
            'tag': 'dns-direct',
            'address': 'local',
            'detour': 'direct',
          }
        ],
        'rules': [
          {
            'outbound': 'any',
            'server': 'dns-direct',
          }
        ],
      },
      'inbounds': [
        {
          'type': 'mixed',
          'tag': 'mixed-in',
          'listen': '127.0.0.1',
          'listen_port': localPort,
          'sniff': true,
        }
      ],
      'outbounds': [
        outbound,
        {
          'type': 'direct',
          'tag': 'direct',
        },
        {
          'type': 'dns',
          'tag': 'dns-out',
        }
      ],
      'route': {
        'rules': [
          {
            'protocol': 'dns',
            'outbound': 'dns-out',
          },
          {
            'inbound': 'mixed-in',
            'outbound': 'proxy',
          }
        ],
        'auto_detect_interface': true,
      }
    };
  }

  static Map<String, dynamic> _buildProxyOutbound(VpnProfile profile) {
    final uri = Uri.tryParse(profile.rawConfig);
    if (uri == null) {
      throw Exception('Неверный формат ссылки: ${profile.rawConfig}');
    }

    final scheme = uri.scheme.toLowerCase();
    switch (scheme) {
      case 'vless':
        return _buildVlessOutbound(uri);
      case 'trojan':
        return _buildTrojanOutbound(uri);
      case 'ss':
        return _buildShadowsocksOutbound(uri, profile.rawConfig);
      case 'vmess':
        return _buildVmessOutbound(profile.rawConfig);
      default:
        throw Exception('Протокол $scheme пока не поддерживается ядром');
    }
  }

  static Map<String, dynamic> _buildVlessOutbound(Uri uri) {
    final uuid = uri.userInfo;
    final host = uri.host;
    final port = uri.port > 0 ? uri.port : 443;
    final q = uri.queryParameters;

    final security = q['security']?.toLowerCase() ?? 'none';
    final sni = q['sni'] ?? host;
    final fp = q['fp'] ?? 'chrome';
    final flow = q['flow'];
    final transportType = q['type']?.toLowerCase() ?? 'tcp';
    final path = q['path'] ?? '/';

    final outbound = <String, dynamic>{
      'type': 'vless',
      'tag': 'proxy',
      'server': host,
      'server_port': port,
      'uuid': uuid,
    };

    if (flow != null && flow.isNotEmpty) {
      outbound['flow'] = flow;
    }

    // TLS / Reality
    if (security == 'reality') {
      outbound['tls'] = {
        'enabled': true,
        'server_name': sni,
        'utls': {
          'enabled': true,
          'fingerprint': fp.isNotEmpty ? fp : 'chrome',
        },
        'reality': {
          'enabled': true,
          'public_key': q['pbk'] ?? '',
          'short_id': q['sid'] ?? '',
        }
      };
    } else if (security == 'tls') {
      outbound['tls'] = {
        'enabled': true,
        'server_name': sni,
        'insecure': true,
        if (fp.isNotEmpty)
          'utls': {
            'enabled': true,
            'fingerprint': fp,
          }
      };
    }

    // Transport (xhttp / http / ws / grpc)
    if (transportType == 'xhttp' || transportType == 'http' || transportType == 'splithttp') {
      outbound['transport'] = {
        'type': 'http',
        'host': [sni],
        'path': path,
      };
    } else if (transportType == 'ws') {
      outbound['transport'] = {
        'type': 'ws',
        'path': path,
        'headers': {'Host': sni},
      };
    } else if (transportType == 'grpc') {
      outbound['transport'] = {
        'type': 'grpc',
        'service_name': q['serviceName'] ?? path,
      };
    }

    return outbound;
  }

  static Map<String, dynamic> _buildTrojanOutbound(Uri uri) {
    final password = uri.userInfo;
    final host = uri.host;
    final port = uri.port > 0 ? uri.port : 443;
    final q = uri.queryParameters;
    final sni = q['sni'] ?? host;

    final outbound = <String, dynamic>{
      'type': 'trojan',
      'tag': 'proxy',
      'server': host,
      'server_port': port,
      'password': password,
      'tls': {
        'enabled': true,
        'server_name': sni,
      }
    };

    final transportType = q['type']?.toLowerCase();
    if (transportType == 'ws') {
      outbound['transport'] = {
        'type': 'ws',
        'path': q['path'] ?? '/',
        'headers': {'Host': sni},
      };
    } else if (transportType == 'grpc') {
      outbound['transport'] = {
        'type': 'grpc',
        'service_name': q['serviceName'] ?? '/',
      };
    }

    return outbound;
  }

  static Map<String, dynamic> _buildShadowsocksOutbound(Uri uri, String raw) {
    String host = uri.host;
    int port = uri.port > 0 ? uri.port : 8388;
    String method = 'aes-256-gcm';
    String password = '';

    if (uri.userInfo.isNotEmpty) {
      if (uri.userInfo.contains(':')) {
        final parts = uri.userInfo.split(':');
        method = parts[0];
        password = parts[1];
      } else {
        // base64 in userinfo
        try {
          final decoded = utf8.decode(base64.decode(base64.normalize(uri.userInfo)));
          final parts = decoded.split(':');
          method = parts[0];
          password = parts[1];
        } catch (_) {}
      }
    }

    return {
      'type': 'shadowsocks',
      'tag': 'proxy',
      'server': host,
      'server_port': port,
      'method': method,
      'password': password,
    };
  }

  static Map<String, dynamic> _buildVmessOutbound(String raw) {
    try {
      final b64 = raw.substring('vmess://'.length);
      final jsonStr = utf8.decode(base64.decode(base64.normalize(b64)));
      final d = json.decode(jsonStr) as Map<String, dynamic>;

      return {
        'type': 'vmess',
        'tag': 'proxy',
        'server': d['add'],
        'server_port': int.tryParse(d['port']?.toString() ?? '') ?? 443,
        'uuid': d['id'],
        'security': 'auto',
        'alter_id': int.tryParse(d['aid']?.toString() ?? '') ?? 0,
        if (d['tls'] == 'tls')
          'tls': {
            'enabled': true,
            'server_name': d['sni'] ?? d['add'],
          }
      };
    } catch (e) {
      throw Exception('Не удалось распарсить VMess: $e');
    }
  }
}
