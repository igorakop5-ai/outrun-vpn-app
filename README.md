# ⚡ OutrunVPN

<div align="center">
  <h3>Минималистичный кроссплатформенный VPN клиент в стиле Synthwave / Outrun</h3>
  <p>Android • iOS • macOS • Windows • Linux</p>
</div>

---

## ✨ Особенности

- 🚀 **1-Click импорт:** вставка конфигурации или подписки из буфера обмена одной кнопкой.
- ⚡ **Минималистичный UX:** большая центральная кнопка включения/выключения со светящейся неоновой анимацией статуса.
- 🗑️ **Быстрый сброс:** очистка конфигурации в один клик.
- 🌐 **Поддержка протоколов:** VLESS (Reality), VMess, Trojan, Shadowsocks, а также HTTP/HTTPS ссылки подписок.
- 📊 **Мониторинг в реальном времени:** пинг сервера (ms), статус подключения, скорость отдачи и скачивания.

---

## 🛠️ Разработка и запуск

### Требования
- [Flutter SDK](https://flutter.dev) (v3.47.7+)
- macOS (с Xcode) для сборки под macOS и iOS
- Android Studio / Android SDK для сборки APK

### Локальный запуск на Mac
```bash
# Получить зависимости
flutter pub get

# Запуск приложения на macOS
flutter run -d macos
```

### Сборка релизов
- **macOS:** `flutter build macos --release`
- **Android:** `flutter build apk --release`
- **Windows:** собирается автоматически через GitHub Actions CI/CD при создании релиза.
