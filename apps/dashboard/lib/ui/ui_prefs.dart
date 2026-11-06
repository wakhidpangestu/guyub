import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-device display choices: theme, sidebar, and dashboard card order.
/// None of this is security relevant, so it stays in the browser.
class UiPrefs extends ChangeNotifier {
  /// In-memory, which is what widget tests use.
  UiPrefs() : _storage = null;

  UiPrefs._(this._storage);

  /// Loads saved choices. Blocked storage (private windows, cleared site data)
  /// falls back to in-memory defaults.
  static Future<UiPrefs> load() async {
    try {
      final storage = await SharedPreferences.getInstance();
      final prefs = UiPrefs._(storage);
      prefs._themeMode = ThemeMode.values.asNameMap()[storage.getString(_themeKey)] ?? ThemeMode.system;
      prefs._sidebarCollapsed = storage.getBool(_sidebarKey) ?? false;
      return prefs;
    } catch (_) {
      return UiPrefs();
    }
  }

  static const _themeKey = 'guyub.theme';
  static const _sidebarKey = 'guyub.sidebar_collapsed';
  static const _layoutPrefix = 'guyub.layout.';

  final SharedPreferences? _storage;
  final Map<String, List<String>> _layouts = {};

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool _sidebarCollapsed = false;
  bool get sidebarCollapsed => _sidebarCollapsed;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _storage?.setString(_themeKey, mode.name).ignore();
    notifyListeners();
  }

  void toggleSidebar() {
    _sidebarCollapsed = !_sidebarCollapsed;
    _storage?.setBool(_sidebarKey, _sidebarCollapsed).ignore();
    notifyListeners();
  }

  /// The saved card order for [key], or null for the default order.
  List<String>? layout(String key) {
    final cached = _layouts[key];
    if (cached != null) return cached;
    final raw = _storage?.getString('$_layoutPrefix$key');
    if (raw == null) return null;
    try {
      return _layouts[key] = (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return null;
    }
  }

  void saveLayout(String key, List<String> ids) {
    _layouts[key] = List.unmodifiable(ids);
    _storage?.setString('$_layoutPrefix$key', jsonEncode(ids)).ignore();
    notifyListeners();
  }

  void resetLayout(String key) {
    _layouts.remove(key);
    _storage?.remove('$_layoutPrefix$key').ignore();
    notifyListeners();
  }
}

class UiPrefsScope extends InheritedNotifier<UiPrefs> {
  const UiPrefsScope({super.key, required UiPrefs prefs, required super.child}) : super(notifier: prefs);

  static UiPrefs of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<UiPrefsScope>()!.notifier!;
}
