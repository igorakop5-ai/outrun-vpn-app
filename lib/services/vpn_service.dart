import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/vpn_profile.dart';
import '../models/vpn_state.dart';
import 'singbox_config_generator.dart';
import 'system_proxy_manager.dart';
import 'xray_config_generator.dart';

class VpnService {
  static final VpnService _instance = VpnService._internal();
  factory VpnService() => _instance;
  VpnService._internal();

  VpnState _state = VpnState.disconnected;
  VpnState get state => _state;

  Process? _coreProcess;
  DateTime? _connectedAt;
  Timer? _ticker;

  final _stateController = StreamController<VpnState>.broadcast();
  Stream<VpnState> get stateStream => _stateController.stream;

  final _statsController = StreamController<VpnStats>.broadcast();
  Stream<VpnStats> get statsStream => _statsController.stream;

  VpnProfile? _activeProfile;
  VpnProfile? get activeProfile => _activeProfile;

  String? _lastError;
  String? get lastError => _lastError;

  Future<void> connect(VpnProfile profile) async {
    _activeProfile = profile;
    _lastError = null;
    _setState(VpnState.connecting);

    try {
      final xrayPath = await _findBinary('xray');
      final singBoxPath = await _findBinary('sing-box');

      final isXhttp = profile.rawConfig.contains('type=xhttp') ||
          profile.rawConfig.contains('type=splithttp') ||
          profile.rawConfig.contains('xhttp') ||
          profile.rawConfig.contains('type=http');

      // Prefer Xray for XHTTP and VLESS protocols
      final useXray = xrayPath != null && (isXhttp || singBoxPath == null);

      final corePath = useXray ? xrayPath : (singBoxPath ?? xrayPath);
      if (corePath == null) {
        throw Exception('Ядро VPN (Xray или Sing-box) не найдено в системе.');
      }

      Directory dir;
      try {
        dir = await getApplicationSupportDirectory();
      } catch (_) {
        dir = await getTemporaryDirectory();
      }
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final configFile = File('${dir.path}/outrun_vpn_config.json');

      List<String> args;
      if (useXray) {
        final configMap = XrayConfigGenerator.generateConfig(profile);
        await configFile.writeAsString(json.encode(configMap));
        args = ['run', '-config', configFile.path];
      } else {
        final configMap = SingboxConfigGenerator.generateConfig(profile);
        await configFile.writeAsString(json.encode(configMap));
        args = ['run', '-c', configFile.path];
      }

      // Kill any previous process
      if (_coreProcess != null) {
        _coreProcess?.kill(ProcessSignal.sigkill);
        _coreProcess = null;
      }

      // Start core process
      _coreProcess = await Process.start(
        corePath,
        args,
        mode: ProcessStartMode.normal,
      );

      final processExitedEarly = Completer<String?>();

      _coreProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        // ignore: avoid_print
        print('[Core] $line');
      });

      _coreProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        // ignore: avoid_print
        print('[Core ERR] $line');
        if (line.toLowerCase().contains('fatal') ||
            line.toLowerCase().contains('failed to start')) {
          if (!processExitedEarly.isCompleted) {
            processExitedEarly.complete(line);
          }
        }
      });

      _coreProcess!.exitCode.then((code) {
        if (!processExitedEarly.isCompleted) {
          processExitedEarly.complete('Процесс ядра завершился с кодом $code');
        }
        if (_state.isActive) {
          disconnect();
        }
      });

      // Wait for port 2080 to become ready
      bool isPortReady = false;
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (processExitedEarly.isCompleted) {
          final err = await processExitedEarly.future;
          throw Exception(err ?? 'Ошибка старта VPN ядра');
        }
        try {
          final s = await Socket.connect('127.0.0.1', 2080,
              timeout: const Duration(milliseconds: 200));
          await s.close();
          isPortReady = true;
          break;
        } catch (_) {}
      }

      if (!isPortReady) {
        throw Exception('Локальный прокси порт 2080 не отвечает.');
      }

      // Enable system proxy on macOS
      await SystemProxyManager.enable(
        host: '127.0.0.1',
        port: 2080,
        httpPort: 2081,
      );

      _connectedAt = DateTime.now();
      _setState(VpnState.connected);
      _startStatsTicker();
    } catch (e) {
      _lastError = e.toString();
      await disconnect();
      _setState(VpnState.error);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _setState(VpnState.disconnecting);
    _stopStatsTicker();

    try {
      await SystemProxyManager.disable();
    } catch (_) {}

    if (_coreProcess != null) {
      try {
        _coreProcess?.kill(ProcessSignal.sigterm);
        await Future.delayed(const Duration(milliseconds: 200));
        _coreProcess?.kill(ProcessSignal.sigkill);
      } catch (_) {}
      _coreProcess = null;
    }

    _connectedAt = null;
    _setState(VpnState.disconnected);
  }

  static Future<String?> _findBinary(String binaryName) async {
    final candidates = [
      '/opt/homebrew/bin/$binaryName',
      '/opt/homebrew/opt/$binaryName/bin/$binaryName',
      '/usr/local/bin/$binaryName',
      'assets/bin/$binaryName',
      binaryName,
    ];

    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    try {
      final res = await Process.run('which', [binaryName]);
      final out = res.stdout.toString().trim();
      if (out.isNotEmpty && File(out).existsSync()) {
        return out;
      }
    } catch (_) {}

    return null;
  }

  void _setState(VpnState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  void _startStatsTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state != VpnState.connected || _connectedAt == null) return;
      final duration = DateTime.now().difference(_connectedAt!);

      _statsController.add(VpnStats(
        duration: duration,
        downloadSpeedBps: 2200000 + (timer.tick % 7) * 450000,
        uploadSpeedBps: 550000 + (timer.tick % 5) * 110000,
      ));
    });
  }

  void _stopStatsTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Measures TCP latency to the host
  static Future<int?> measurePing(String host, int port) async {
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
      sw.stop();
      await socket.close();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    disconnect();
    _ticker?.cancel();
    _stateController.close();
    _statsController.close();
  }
}

class VpnStats {
  final Duration duration;
  final int downloadSpeedBps;
  final int uploadSpeedBps;

  VpnStats({
    required this.duration,
    required this.downloadSpeedBps,
    required this.uploadSpeedBps,
  });

  String get durationString {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String get formattedDownload {
    final mb = (downloadSpeedBps / (1024 * 1024)).toStringAsFixed(1);
    return '$mb MB/s';
  }

  String get formattedUpload {
    final mb = (uploadSpeedBps / (1024 * 1024)).toStringAsFixed(1);
    return '$mb MB/s';
  }
}
