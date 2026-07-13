import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Na Androidzie 11+ potrzebujemy MANAGE_EXTERNAL_STORAGE ("All files access").
  /// Na starszych wystarczy zwykly storage.
  static Future<bool> maDostep() async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    if (await Permission.storage.isGranted) return true;
    return false;
  }

  static Future<bool> popros() async {
    // Najpierw probujemy MANAGE_EXTERNAL_STORAGE (Android 11+).
    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    // Fallback dla starszych wersji Androida.
    status = await Permission.storage.request();
    return status.isGranted;
  }

  static Future<void> otworzUstawienia() => openAppSettings();
}
