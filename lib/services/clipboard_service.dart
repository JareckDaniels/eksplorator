import 'package:flutter/foundation.dart';

enum TrybSchowka { kopiuj, wytnij }

class ClipboardService extends ChangeNotifier {
  List<String> _sciezki = [];
  TrybSchowka? _tryb;

  List<String> get sciezki => List.unmodifiable(_sciezki);
  TrybSchowka? get tryb => _tryb;
  bool get pusty => _sciezki.isEmpty;
  int get ile => _sciezki.length;

  void kopiuj(List<String> sciezki) {
    _sciezki = List.of(sciezki);
    _tryb = TrybSchowka.kopiuj;
    notifyListeners();
  }

  void wytnij(List<String> sciezki) {
    _sciezki = List.of(sciezki);
    _tryb = TrybSchowka.wytnij;
    notifyListeners();
  }

  void wyczysc() {
    _sciezki = [];
    _tryb = null;
    notifyListeners();
  }
}
