import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/file_entry.dart';

class SettingsService extends ChangeNotifier {
  static const _kMotyw = 'motyw';
  static const _kSort = 'sort';
  static const _kRosnaco = 'rosnaco';
  static const _kUkryte = 'ukryte';
  static const _kZakladki = 'zakladki';
  static const _kMiniatury = 'miniatury';

  late SharedPreferences _prefs;

  ThemeMode motyw = ThemeMode.system;
  SortBy sortuj = SortBy.nazwa;
  bool rosnaco = true;
  bool pokazUkryte = false;
  bool miniatury = true;
  List<String> zakladki = [];

  Future<void> wczytaj() async {
    _prefs = await SharedPreferences.getInstance();
    motyw = ThemeMode.values[_prefs.getInt(_kMotyw) ?? ThemeMode.system.index];
    sortuj = SortBy.values[_prefs.getInt(_kSort) ?? SortBy.nazwa.index];
    rosnaco = _prefs.getBool(_kRosnaco) ?? true;
    pokazUkryte = _prefs.getBool(_kUkryte) ?? false;
    miniatury = _prefs.getBool(_kMiniatury) ?? true;
    zakladki = _prefs.getStringList(_kZakladki) ?? [];
    notifyListeners();
  }

  Future<void> ustawMotyw(ThemeMode m) async {
    motyw = m;
    await _prefs.setInt(_kMotyw, m.index);
    notifyListeners();
  }

  Future<void> ustawSortowanie(SortBy s, bool asc) async {
    sortuj = s;
    rosnaco = asc;
    await _prefs.setInt(_kSort, s.index);
    await _prefs.setBool(_kRosnaco, asc);
    notifyListeners();
  }

  Future<void> przelaczUkryte() async {
    pokazUkryte = !pokazUkryte;
    await _prefs.setBool(_kUkryte, pokazUkryte);
    notifyListeners();
  }

  Future<void> przelaczMiniatury() async {
    miniatury = !miniatury;
    await _prefs.setBool(_kMiniatury, miniatury);
    notifyListeners();
  }

  bool czyZakladka(String sciezka) => zakladki.contains(sciezka);

  Future<void> przelaczZakladke(String sciezka) async {
    if (zakladki.contains(sciezka)) {
      zakladki.remove(sciezka);
    } else {
      zakladki.add(sciezka);
    }
    await _prefs.setStringList(_kZakladki, zakladki);
    notifyListeners();
  }

  Future<void> usunZakladke(String sciezka) async {
    zakladki.remove(sciezka);
    await _prefs.setStringList(_kZakladki, zakladki);
    notifyListeners();
  }
}
