import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/vpn_profile.dart';
import '../models/vpn_state.dart';
import '../services/config_parser.dart';
import '../services/storage_service.dart';
import '../services/vpn_service.dart';
import '../theme/outrun_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _vpnService = VpnService();
  VpnProfile? _activeProfile;
  VpnState _vpnState = VpnState.disconnected;
  VpnStats? _stats;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  StreamSubscription? _stateSub;
  StreamSubscription? _statsSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadSavedProfile();

    _stateSub = _vpnService.stateStream.listen((state) {
      if (mounted) setState(() => _vpnState = state);
    });

    _statsSub = _vpnService.statsStream.listen((stats) {
      if (mounted) setState(() => _stats = stats);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stateSub?.cancel();
    _statsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedProfile() async {
    final profile = await StorageService.getActiveProfile();
    if (profile != null && mounted) {
      setState(() => _activeProfile = profile);
      _checkPing(profile);
    }
  }

  Future<void> _checkPing(VpnProfile profile) async {
    final ping = await VpnService.measurePing(profile.server, profile.port);
    if (mounted && ping != null) {
      setState(() {
        profile.pingMs = ping;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        _showToast('Буфер обмена пуст. Скопируйте ссылку или ключ!', isError: true);
        return;
      }

      _showToast('Парсинг конфигурации...', isInfo: true);
      final profiles = await ConfigParser.parse(text);

      if (profiles.isNotEmpty) {
        final selected = profiles.first;
        await StorageService.saveActiveProfile(selected);
        await StorageService.saveProfiles(profiles);

        setState(() {
          _activeProfile = selected;
        });

        _checkPing(selected);
        _showToast('✅ Конфигурация "${selected.name}" успешно добавлена!');
      }
    } catch (e) {
      _showToast('Ошибка импорта: $e', isError: true);
    }
  }

  Future<void> _clearConfiguration() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OutrunTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: OutrunTheme.surfaceLight),
        ),
        title: const Text(
          'Очистить конфигурацию?',
          style: TextStyle(color: OutrunTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Текущие ключи и настройки подключения будут удалены из приложения.',
          style: TextStyle(color: OutrunTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: OutrunTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: OutrunTheme.neonPink,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (_vpnState.isActive) {
        await _vpnService.disconnect();
      }
      await StorageService.clearAll();
      if (mounted) {
        setState(() {
          _activeProfile = null;
          _stats = null;
        });
        _showToast('Конфигурация успешно очищена');
      }
    }
  }

  Future<void> _toggleVpn() async {
    if (_activeProfile == null) {
      _showToast('Сначала вставьте конфигурацию из буфера!', isError: true);
      return;
    }

    if (_vpnState == VpnState.connected) {
      await _vpnService.disconnect();
    } else if (_vpnState == VpnState.disconnected || _vpnState == VpnState.error) {
      try {
        await _vpnService.connect(_activeProfile!);
      } catch (e) {
        _showToast('Ошибка подключения: $e', isError: true);
      }
    }
  }

  void _showToast(String message, {bool isError = false, bool isInfo = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isError
            ? OutrunTheme.neonPink
            : (isInfo ? OutrunTheme.neonCyan : OutrunTheme.surfaceLight),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF140D24),
              OutrunTheme.background,
              Color(0xFF090712),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopHeader(),
              const SizedBox(height: 12),
              _buildActionButtons(),
              const Spacer(),
              _buildCenterPowerButton(),
              const SizedBox(height: 24),
              _buildStatusLabel(),
              const Spacer(),
              _buildProfileDetailsCard(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: OutrunTheme.neonGlow(OutrunTheme.neonPink, intensity: 0.6),
            ),
            child: const Icon(Icons.flash_on, color: OutrunTheme.neonPink, size: 22),
          ),
          const SizedBox(width: 8),
          const Text(
            'OUTRUN',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 3.5,
              color: OutrunTheme.neonPink,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'VPN',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 3.5,
              color: OutrunTheme.neonCyan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // 1-Click Paste from Clipboard
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _pasteFromClipboard,
              icon: const Icon(Icons.content_paste, size: 18),
              label: const Text(
                'Вставить ключ',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: OutrunTheme.surfaceLight,
                foregroundColor: OutrunTheme.neonCyan,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: OutrunTheme.neonCyan.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Clear Config
          OutlinedButton.icon(
            onPressed: _activeProfile != null ? _clearConfiguration : null,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Очистить', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: OutrunTheme.textSecondary,
              disabledForegroundColor: OutrunTheme.textMuted,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              side: const BorderSide(color: OutrunTheme.surfaceLight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterPowerButton() {
    final isConnected = _vpnState == VpnState.connected;
    final isConnecting = _vpnState == VpnState.connecting;

    Color buttonGlowColor = OutrunTheme.neonPink;
    if (isConnected) buttonGlowColor = OutrunTheme.neonGreen;
    if (isConnecting) buttonGlowColor = OutrunTheme.neonAmber;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = isConnecting ? _pulseAnimation.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: _toggleVpn,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    buttonGlowColor.withValues(alpha: isConnected ? 0.35 : 0.15),
                    OutrunTheme.surface,
                    const Color(0xFF0F0B1E),
                  ],
                  stops: const [0.2, 0.7, 1.0],
                ),
                boxShadow: isConnected || isConnecting
                    ? OutrunTheme.neonGlow(buttonGlowColor, intensity: isConnected ? 1.4 : 0.9)
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        )
                      ],
                border: Border.all(
                  color: isConnected
                      ? OutrunTheme.neonGreen
                      : (isConnecting ? OutrunTheme.neonAmber : OutrunTheme.surfaceLight),
                  width: 3.5,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.power_settings_new_rounded,
                      size: 68,
                      color: isConnected
                          ? OutrunTheme.neonGreen
                          : (isConnecting ? OutrunTheme.neonAmber : OutrunTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isConnected ? 'ВКЛЮЧЕНО' : (isConnecting ? 'ПОИСК...' : 'ВКЛЮЧИТЬ'),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w800,
                        color: isConnected
                            ? OutrunTheme.neonGreen
                            : (isConnecting ? OutrunTheme.neonAmber : OutrunTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusLabel() {
    Color statusColor = OutrunTheme.textMuted;
    if (_vpnState == VpnState.connected) statusColor = OutrunTheme.neonGreen;
    if (_vpnState == VpnState.connecting) statusColor = OutrunTheme.neonAmber;
    if (_vpnState == VpnState.error) statusColor = OutrunTheme.neonPink;

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                boxShadow: OutrunTheme.neonGlow(statusColor, intensity: 0.8),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _vpnState.label,
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ],
        ),
        if (_stats != null && _vpnState == VpnState.connected) ...[
          const SizedBox(height: 6),
          Text(
            'Сессия: ${_stats!.durationString}',
            style: const TextStyle(
              fontSize: 12,
              color: OutrunTheme.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileDetailsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: OutrunTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _activeProfile != null
                ? OutrunTheme.surfaceLight
                : OutrunTheme.surfaceLight.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _activeProfile == null
            ? const Column(
                children: [
                  Icon(Icons.link_off_rounded, color: OutrunTheme.textMuted, size: 28),
                  SizedBox(height: 8),
                  Text(
                    'Конфигурация не установлена',
                    style: TextStyle(
                      color: OutrunTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Нажмите «Вставить ключ», чтобы начать',
                    style: TextStyle(color: OutrunTheme.textMuted, fontSize: 12),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: OutrunTheme.neonPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: OutrunTheme.neonPurple.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          _activeProfile!.protocol.name.toUpperCase(),
                          style: const TextStyle(
                            color: OutrunTheme.neonCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _activeProfile!.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: OutrunTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_activeProfile!.pingMs != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_activeProfile!.pingMs} ms',
                            style: const TextStyle(
                              color: OutrunTheme.neonGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Divider(color: OutrunTheme.surfaceLight, height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        icon: Icons.arrow_downward_rounded,
                        label: 'Скачивание',
                        value: _stats != null && _vpnState == VpnState.connected
                            ? _stats!.formattedDownload
                            : '0.0 MB/s',
                        color: OutrunTheme.neonCyan,
                      ),
                      Container(width: 1, height: 26, color: OutrunTheme.surfaceLight),
                      _buildStatColumn(
                        icon: Icons.arrow_upward_rounded,
                        label: 'Отдача',
                        value: _stats != null && _vpnState == VpnState.connected
                            ? _stats!.formattedUpload
                            : '0.0 MB/s',
                        color: OutrunTheme.neonPink,
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: OutrunTheme.textMuted),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
