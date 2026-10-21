import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_profile.dart';

class StorageService {
  static const _activeProfileKey = 'outrun_active_profile';
  static const _profileListKey = 'outrun_profile_list';

  static Future<void> saveActiveProfile(VpnProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileKey, profile.toJson());
  }

  static Future<VpnProfile?> getActiveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_activeProfileKey);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return VpnProfile.fromJson(jsonStr);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveProfiles(List<VpnProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final list = profiles.map((p) => p.toJson()).toList();
    await prefs.setStringList(_profileListKey, list);
  }

  static Future<List<VpnProfile>> getProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_profileListKey);
    if (list == null) return [];
    return list
        .map((str) {
          try {
            return VpnProfile.fromJson(str);
          } catch (_) {
            return null;
          }
        })
        .whereType<VpnProfile>()
        .toList();
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeProfileKey);
    await prefs.remove(_profileListKey);
  }
}
