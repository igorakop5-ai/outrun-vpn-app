enum VpnState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error;

  String get label {
    switch (this) {
      case VpnState.disconnected:
        return 'ОТКЛЮЧЕНО';
      case VpnState.connecting:
        return 'ПОДКЛЮЧЕНИЕ...';
      case VpnState.connected:
        return 'ЗАЩИЩЕНО (ОНЛАЙН)';
      case VpnState.disconnecting:
        return 'ОТКЛЮЧЕНИЕ...';
      case VpnState.error:
        return 'ОШИБКА';
    }
  }

  bool get isActive => this == VpnState.connected || this == VpnState.connecting;
}
