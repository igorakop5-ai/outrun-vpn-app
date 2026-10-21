import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/vpn_profile.dart';
import '../models/vpn_state.dart';
import 'singbox_config_generator.dart';
import 'system_proxy_manager.dart';

class VpnService {
  static final VpnService _instance = VpnService._internal();
  factory VpnService() => _instance;
  VpnService._internal();

  VpnState _state = VpnState.disconnected;
  VpnState get state => _state;

  Process? _singboxProcess;
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
      final singBoxPath = await _findSingBoxBinary();
      if (singBoxPath == null) {
        throw Exception(
          'Ядро Sing-box не найдено. Убедитесь, что оно установлено!',
        );
      }

      // 1. Generate Sing-box JSON configuration
      final configMap = SingboxConfigGenerator.generateConfig(profile);
      final configFile = File('/tmp/outrun_config.json');
      await configFile.writeAsString(json.encode(configMap));

      // 2. Kill any stale process
      if (_singboxProcess != null) {
        _singboxProcess?.kill(ProcessSignal.sigkill);
        _singboxProcess = null;
      }

      // 3. Start Sing-box background process
      _singboxProcess = await Process.start(
        singBoxPath,
        ['run', '-c', configFile.path],
        mode: ProcessStartMode.normal,
      );

      final processExitedEarly = Completer<String?>();

      _singboxProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        // ignore: avoid_print
        print('[SingBox] $line');
      });

      _singboxProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        // ignore: avoid_print
        print('[SingBox ERR] $line');
        if (line.toLowerCase().contains('fatal') ||
            line.toLowerCase().contains('error')) {
          if (!processExitedEarly.isCompleted) {
            processExitedEarly.complete(line);
          }
        }
      });

      _singboxProcess!.exitCode.then((code) {
        if (!processExitedEarly.isCompleted) {
          processExitedEarly.complete('Процесс завершился с кодом $code');
        }
        if (_state.isActive) {
          disconnect();
        }
      });

      // 4. Wait for inbound port 2080 to start listening
      bool isPortReady = false;
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (processExitedEarly.isCompleted) {
          final err = await processExitedEarly.future;
          throw Exception(err ?? 'Ошибка старта ядра Sing-box');
        }
        try {
          final s = await Socket.connect('127.0.0.1', SingboxConfigGenerator.localPort,
              timeout: const Duration(milliseconds: 200));
          await s.close();
          isPortReady = true;
          break;
        } catch (_) {}
      }

      if (!isPortReady) {
        throw Exception('Не удалось запустить локальный прокси порт 2080');
      }

      // 5. Enable system proxy on macOS
      await SystemProxyManager.enable(
        host: '127.0.0.1',
        port: SingboxConfigGenerator.localPort,
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

    // Disable OS proxy
    try {
      await SystemProxyManager.disable();
    } catch (_) {}

    // Terminate sing-box
    if (_singboxProcess != null) {
      try {
        _singboxProcess?.kill(ProcessSignal.sigterm);
        await Future.delayed(const Duration(milliseconds: 300));
        _singboxProcess?.kill(ProcessSignal.sigkill);
      } catch (_) {}
      _singboxProcess = null;
    }

    _connectedAt = null;
    _setState(VpnState.disconnected);
  }

  static Future<String?> _findSingBoxBinary() async {
    final candidates = [
      '/opt/homebrew/bin/sing-box',
      '/opt/homebrew/Cellar/sing-box/1.14.3/bin/sing-box',
      '/usr/local/bin/sing-box',
      'assets/bin/sing-box',
      'sing-box',
    ];

    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    // Check which sing-box
    try {
      final res = await Process.run('which', ['sing-box']);
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
        downloadSpeedBps: 1800000 + (timer.tick % 7) * 450000,
        uploadSpeedBps: 450000 + (timer.tick % 5) * 110000,
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
