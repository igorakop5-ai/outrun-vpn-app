import 'dart:io';

class SystemProxyManager {
  static Future<void> enable({
    required String host,
    required int port,
    int? httpPort,
  }) async {
    final hPort = httpPort ?? port;
    if (Platform.isMacOS) {
      final services = await _getActiveServices();
      for (final service in services) {
        // Try regular execution first
        final res = await Process.run(
          'networksetup',
          ['-setsocksfirewallproxy', service, host, port.toString()],
        );

        if (res.exitCode == 0) {
          await Process.run('networksetup', ['-setsocksfirewallproxystate', service, 'on']);
          await Process.run('networksetup', ['-setwebproxy', service, host, hPort.toString()]);
          await Process.run('networksetup', ['-setwebproxystate', service, 'on']);
          await Process.run('networksetup', ['-setsecurewebproxy', service, host, hPort.toString()]);
          await Process.run('networksetup', ['-setsecurewebproxystate', service, 'on']);
        } else {
          // Fallback to macOS native administrator prompt (Touch ID / password)
          final cmd = 'networksetup -setsocksfirewallproxy "$service" $host $port && '
              'networksetup -setsocksfirewallproxystate "$service" on && '
              'networksetup -setwebproxy "$service" $host $hPort && '
              'networksetup -setwebproxystate "$service" on && '
              'networksetup -setsecurewebproxy "$service" $host $hPort && '
              'networksetup -setsecurewebproxystate "$service" on';
          await Process.run('osascript', ['-e', 'do shell script "$cmd" with administrator privileges']);
        }
      }
    }
  }

  static Future<void> disable() async {
    if (Platform.isMacOS) {
      final services = await _getActiveServices();
      for (final service in services) {
        final res = await Process.run('networksetup', ['-setsocksfirewallproxystate', service, 'off']);
        if (res.exitCode == 0) {
          await Process.run('networksetup', ['-setwebproxystate', service, 'off']);
          await Process.run('networksetup', ['-setsecurewebproxystate', service, 'off']);
        } else {
          final cmd = 'networksetup -setsocksfirewallproxystate "$service" off && '
              'networksetup -setwebproxystate "$service" off && '
              'networksetup -setsecurewebproxystate "$service" off';
          await Process.run('osascript', ['-e', 'do shell script "$cmd" with administrator privileges']);
        }
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
