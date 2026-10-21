import 'dart:io';

class SystemProxyManager {
  static Future<void> enable({required String host, required int port}) async {
    if (Platform.isMacOS) {
      final services = await _getActiveServices();
      for (final service in services) {
        // Mixed inbound supports SOCKS5 and HTTP
        await Process.run('networksetup', ['-setsocksfirewallproxy', service, host, port.toString()]);
        await Process.run('networksetup', ['-setsocksfirewallproxystate', service, 'on']);
        await Process.run('networksetup', ['-setwebproxy', service, host, port.toString()]);
        await Process.run('networksetup', ['-setwebproxystate', service, 'on']);
        await Process.run('networksetup', ['-setsecurewebproxy', service, host, port.toString()]);
        await Process.run('networksetup', ['-setsecurewebproxystate', service, 'on']);
      }
    } else if (Platform.isWindows) {
      // Windows system proxy can be set via netsh or registry
      // E.g. reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 1 /f
    }
  }

  static Future<void> disable() async {
    if (Platform.isMacOS) {
      final services = await _getActiveServices();
      for (final service in services) {
        await Process.run('networksetup', ['-setsocksfirewallproxystate', service, 'off']);
        await Process.run('networksetup', ['-setwebproxystate', service, 'off']);
        await Process.run('networksetup', ['-setsecurewebproxystate', service, 'off']);
      }
    }
  }

  static Future<List<String>> _getActiveServices() async {
    try {
      final res = await Process.run('networksetup', ['-listallnetworkservices']);
      final lines = res.stdout.toString().split('\n');
      final list = <String>[];
      for (final line in lines) {
        final l = line.trim();
        if (l.isEmpty || l.startsWith('*') || l.contains('denotes')) continue;
        if (l == 'Wi-Fi' || l.toLowerCase().contains('ethernet') || l.toLowerCase().contains('lan')) {
          list.add(l);
        }
      }
      return list.isNotEmpty ? list : ['Wi-Fi'];
    } catch (_) {
      return ['Wi-Fi'];
    }
  }
}
