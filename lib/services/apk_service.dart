import 'package:flutter/services.dart';

/// Instalacja plikow APK.
///
/// Nie uzywamy open_filex, bo dla APK Android wymaga:
///   - konkretnego MIME type (application/vnd.android.package-archive)
///   - flagi FLAG_GRANT_READ_URI_PERMISSION na content:// URI
///   - uprawnienia REQUEST_INSTALL_PACKAGES (Android 8+)
/// Robimy to natywnie po stronie Kotlina.
class ApkService {
  static const _kanal = MethodChannel('pl.reiro.eksplorator/apk');

  /// Czy uzytkownik pozwolil tej aplikacji instalowac inne aplikacje.
  /// Na Androidzie < 8 zawsze true.
  static Future<bool> czyMozeInstalowac() async {
    try {
      final wynik = await _kanal.invokeMethod<bool>('czyMozeInstalowac');
      return wynik ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Otwiera systowe ustawienie "Instaluj nieznane aplikacje" dla tej aplikacji.
  static Future<void> otworzUstawienieInstalacji() async {
    try {
      await _kanal.invokeMethod('otworzUstawienieInstalacji');
    } on PlatformException {
      // ignorujemy - i tak pokazemy komunikat
    }
  }

  /// Uruchamia instalator systemowy dla wskazanego pliku APK.
  /// Zwraca null przy sukcesie, komunikat bledu przy porazce.
  static Future<String?> zainstaluj(String sciezka) async {
    try {
      await _kanal.invokeMethod('zainstaluj', {'sciezka': sciezka});
      return null;
    } on PlatformException catch (e) {
      return e.message ?? 'Nie udało się uruchomić instalatora';
    }
  }
}
