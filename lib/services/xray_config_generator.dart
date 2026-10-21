import 'dart:convert';
import '../models/vpn_profile.dart';

class XrayConfigGenerator {
  static const int socksPort = 2080;
  static const int httpPort = 2081;

  static Map<String, dynamic> generateConfig(VpnProfile profile) {
    final outbound = _buildOutbound(profile);

    return {
      'log': {
        'loglevel': 'info',
      },
      'inbounds': [
        {
          'port': socksPort,
          'listen': '127.0.0.1',
          'protocol': 'socks',
          'settings': {
            'auth': 'noauth',
            'udp': true,
          },
        },
        {
          'port': httpPort,
          'listen': '127.0.0.1',
          'protocol': 'http',
          'settings': {
            'allowTransparent': false,
          },
        }
      ],
      'outbounds': [
        outbound,
        {
          'protocol': 'freedom',
          'tag': 'direct',
        }
      ],
    };
  }

  static Map<String, dynamic> _buildOutbound(VpnProfile profile) {
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
        return _buildShadowsocksOutbound(uri);
      case 'vmess':
        return _buildVmessOutbound(profile.rawConfig);
      default:
        throw Exception('Протокол $scheme пока не поддерживается Xray');
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

    final streamSettings = <String, dynamic>{
      'network': transportType == 'http' ? 'xhttp' : transportType,
    };

    if (security == 'reality') {
      streamSettings['security'] = 'reality';
      streamSettings['realitySettings'] = {
        'serverName': sni,
        'fingerprint': fp,
        'publicKey': q['pbk'] ?? '',
        'shortId': q['sid'] ?? '',
        'spiderX': q['spx'] ?? '',
      };
    } else if (security == 'tls') {
      streamSettings['security'] = 'tls';
      streamSettings['tlsSettings'] = {
        'serverName': sni,
        'fingerprint': fp,
      };
    }

    // Transport settings
    if (transportType == 'xhttp' || transportType == 'http' || transportType == 'splithttp') {
      streamSettings['network'] = 'xhttp';
      streamSettings['xhttpSettings'] = {
        'path': path,
        'host': sni,
        'mode': q['mode'] ?? 'auto',
      };
    } else if (transportType == 'ws') {
      streamSettings['network'] = 'ws';
      streamSettings['wsSettings'] = {
        'path': path,
        'headers': {'Host': sni},
      };
    } else if (transportType == 'grpc') {
      streamSettings['network'] = 'grpc';
      streamSettings['grpcSettings'] = {
        'serviceName': q['serviceName'] ?? path,
      };
    }

    final user = <String, dynamic>{
      'id': uuid,
      'encryption': 'none',
    };
    if (flow != null && flow.isNotEmpty) {
      user['flow'] = flow;
    }

    return {
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': host,
            'port': port,
            'users': [user],
          }
        ]
      },
      'streamSettings': streamSettings,
    };
  }

  static Map<String, dynamic> _buildTrojanOutbound(Uri uri) {
    final password = uri.userInfo;
    final host = uri.host;
    final port = uri.port > 0 ? uri.port : 443;
    final q = uri.queryParameters;
    final sni = q['sni'] ?? host;
    final transportType = q['type']?.toLowerCase() ?? 'tcp';

    return {
      'protocol': 'trojan',
      'settings': {
        'servers': [
          {
            'address': host,
            'port': port,
            'password': password,
          }
        ]
      },
      'streamSettings': {
        'network': transportType,
        'security': 'tls',
        'tlsSettings': {
          'serverName': sni,
        },
      },
    };
  }

  static Map<String, dynamic> _buildShadowsocksOutbound(Uri uri) {
    final host = uri.host;
    final port = uri.port > 0 ? uri.port : 8388;
    String method = 'aes-256-gcm';
    String password = '';

    if (uri.userInfo.isNotEmpty) {
      if (uri.userInfo.contains(':')) {
        final parts = uri.userInfo.split(':');
        method = parts[0];
        password = parts[1];
      } else {
        try {
          final decoded = utf8.decode(base64.decode(base64.normalize(uri.userInfo)));
          final parts = decoded.split(':');
          method = parts[0];
          password = parts[1];
        } catch (_) {}
      }
    }

    return {
      'protocol': 'shadowsocks',
      'settings': {
        'servers': [
          {
            'address': host,
            'port': port,
            'method': method,
            'password': password,
          }
        ]
      },
    };
  }

  static Map<String, dynamic> _buildVmessOutbound(String raw) {
    final b64 = raw.substring('vmess://'.length);
    final jsonStr = utf8.decode(base64.decode(base64.normalize(b64)));
    final d = json.decode(jsonStr) as Map<String, dynamic>;

    return {
      'protocol': 'vmess',
      'settings': {
        'vnext': [
          {
            'address': d['add'],
            'port': int.tryParse(d['port']?.toString() ?? '') ?? 443,
            'users': [
              {
                'id': d['id'],
                'alterId': int.tryParse(d['aid']?.toString() ?? '') ?? 0,
                'security': 'auto',
              }
            ],
          }
        ]
      },
      'streamSettings': {
        'network': d['net'] ?? 'tcp',
        if (d['tls'] == 'tls') ...{
          'security': 'tls',
          'tlsSettings': {
            'serverName': d['sni'] ?? d['add'],
          }
        }
      }
    };
  }
}
