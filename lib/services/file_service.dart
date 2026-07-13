import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../models/file_entry.dart';

/// Postep dlugiej operacji.
class Postep {
  final int wykonane;
  final int wszystkie;
  final String biezacy;
  const Postep(this.wykonane, this.wszystkie, this.biezacy);
  double get ulamek => wszystkie == 0 ? 0 : wykonane / wszystkie;
}

class FileService {
  /// Listuje katalog. Zwraca posortowana liste (foldery zawsze na gorze).
  static Future<List<FileEntry>> listuj(
    String sciezka, {
    required SortBy sortuj,
    required bool rosnaco,
    required bool pokazUkryte,
  }) async {
    final dir = Directory(sciezka);
    final wynik = <FileEntry>[];

    await for (final e in dir.list(followLinks: false)) {
      final fe = FileEntry.from(e);
      if (fe == null) continue;
      if (!pokazUkryte && fe.isHidden) continue;
      wynik.add(fe);
    }

    int cmp(FileEntry a, FileEntry b) {
      // Foldery zawsze przed plikami, niezaleznie od kierunku sortowania.
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      int r;
      switch (sortuj) {
        case SortBy.nazwa:
          r = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case SortBy.data:
          r = a.modified.compareTo(b.modified);
          break;
        case SortBy.rozmiar:
          r = a.size.compareTo(b.size);
          break;
        case SortBy.typ:
          r = a.ext.compareTo(b.ext);
          if (r == 0) r = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
      }
      return rosnaco ? r : -r;
    }

    wynik.sort(cmp);
    return wynik;
  }

  /// Zwraca nazwe wolna w katalogu docelowym: "plik.txt" -> "plik (1).txt".
  static String wolnaNazwa(String katalog, String nazwa) {
    var kandydat = p.join(katalog, nazwa);
    if (!_istnieje(kandydat)) return kandydat;

    final rozsz = p.extension(nazwa);
    final baza = p.basenameWithoutExtension(nazwa);
    for (var i = 1; i < 10000; i++) {
      kandydat = p.join(katalog, '$baza ($i)$rozsz');
      if (!_istnieje(kandydat)) return kandydat;
    }
    return p.join(katalog, '$baza (${DateTime.now().millisecondsSinceEpoch})$rozsz');
  }

  static bool _istnieje(String sciezka) =>
      File(sciezka).existsSync() || Directory(sciezka).existsSync();

  /// Rekurencyjne kopiowanie folderu.
  static Future<void> _kopiujFolder(Directory zrodlo, Directory cel) async {
    await cel.create(recursive: true);
    await for (final e in zrodlo.list(followLinks: false)) {
      final nazwa = p.basename(e.path);
      if (e is Directory) {
        await _kopiujFolder(e, Directory(p.join(cel.path, nazwa)));
      } else if (e is File) {
        await e.copy(p.join(cel.path, nazwa));
      }
    }
  }

  /// Kopiuje liste elementow do katalogu docelowego.
  static Future<void> kopiuj(
    List<String> zrodla,
    String katalogDocelowy, {
    void Function(Postep)? onPostep,
  }) async {
    for (var i = 0; i < zrodla.length; i++) {
      final sciezka = zrodla[i];
      final nazwa = p.basename(sciezka);
      onPostep?.call(Postep(i, zrodla.length, nazwa));

      final cel = wolnaNazwa(katalogDocelowy, nazwa);
      final dir = Directory(sciezka);
      if (dir.existsSync()) {
        // Blokada kopiowania folderu do samego siebie (nieskonczona petla).
        if (p.isWithin(sciezka, katalogDocelowy) || sciezka == katalogDocelowy) {
          throw FileSystemException('Nie mozna kopiowac folderu do samego siebie', sciezka);
        }
        await _kopiujFolder(dir, Directory(cel));
      } else {
        await File(sciezka).copy(cel);
      }
    }
    onPostep?.call(Postep(zrodla.length, zrodla.length, ''));
  }

  /// Przenosi elementy. Probuje rename (szybkie), fallback na kopiuj+usun
  /// gdy przenosimy miedzy roznymi wolumenami (np. pamiec -> karta SD).
  static Future<void> przenies(
    List<String> zrodla,
    String katalogDocelowy, {
    void Function(Postep)? onPostep,
  }) async {
    for (var i = 0; i < zrodla.length; i++) {
      final sciezka = zrodla[i];
      final nazwa = p.basename(sciezka);
      onPostep?.call(Postep(i, zrodla.length, nazwa));

      final cel = wolnaNazwa(katalogDocelowy, nazwa);
      final dir = Directory(sciezka);
      final plik = File(sciezka);

      if (dir.existsSync()) {
        if (p.isWithin(sciezka, katalogDocelowy) || sciezka == katalogDocelowy) {
          throw FileSystemException('Nie mozna przeniesc folderu do samego siebie', sciezka);
        }
        try {
          await dir.rename(cel);
        } on FileSystemException {
          await _kopiujFolder(dir, Directory(cel));
          await dir.delete(recursive: true);
        }
      } else {
        try {
          await plik.rename(cel);
        } on FileSystemException {
          await plik.copy(cel);
          await plik.delete();
        }
      }
    }
    onPostep?.call(Postep(zrodla.length, zrodla.length, ''));
  }

  static Future<void> usun(
    List<String> sciezki, {
    void Function(Postep)? onPostep,
  }) async {
    for (var i = 0; i < sciezki.length; i++) {
      final s = sciezki[i];
      onPostep?.call(Postep(i, sciezki.length, p.basename(s)));
      final dir = Directory(s);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      } else {
        final f = File(s);
        if (f.existsSync()) await f.delete();
      }
    }
    onPostep?.call(Postep(sciezki.length, sciezki.length, ''));
  }

  static Future<void> zmienNazwe(String sciezka, String nowaNazwa) async {
    final cel = p.join(p.dirname(sciezka), nowaNazwa);
    if (_istnieje(cel)) {
      throw FileSystemException('Element o tej nazwie juz istnieje', cel);
    }
    final dir = Directory(sciezka);
    if (dir.existsSync()) {
      await dir.rename(cel);
    } else {
      await File(sciezka).rename(cel);
    }
  }

  static Future<void> nowyFolder(String katalog, String nazwa) async {
    final cel = p.join(katalog, nazwa);
    if (_istnieje(cel)) {
      throw FileSystemException('Element o tej nazwie juz istnieje', cel);
    }
    await Directory(cel).create();
  }

  // ---------- ZIP ----------

  /// Rozpakowuje archiwum do katalogu docelowego.
  /// Chroni przed Zip Slip (wpisy typu ../../etc/passwd).
  static Future<void> rozpakuj(
    String sciezkaZip,
    String katalogDocelowy, {
    void Function(Postep)? onPostep,
  }) async {
    final bajty = await File(sciezkaZip).readAsBytes();
    final archiwum = ZipDecoder().decodeBytes(bajty);
    final baza = Directory(katalogDocelowy);
    await baza.create(recursive: true);
    final bazaNorm = p.normalize(baza.absolute.path);

    final wpisy = archiwum.files;
    for (var i = 0; i < wpisy.length; i++) {
      final wpis = wpisy[i];
      onPostep?.call(Postep(i, wpisy.length, wpis.name));

      final docelowa = p.normalize(p.join(bazaNorm, wpis.name));
      // Zip Slip guard
      if (!p.isWithin(bazaNorm, docelowa) && docelowa != bazaNorm) {
        continue;
      }

      if (wpis.isFile) {
        final f = File(docelowa);
        await f.parent.create(recursive: true);
        await f.writeAsBytes(wpis.content as List<int>);
      } else {
        await Directory(docelowa).create(recursive: true);
      }
    }
    onPostep?.call(Postep(wpisy.length, wpisy.length, ''));
  }

  /// Pakuje wskazane elementy do jednego archiwum ZIP.
  static Future<String> spakuj(
    List<String> zrodla,
    String katalogDocelowy,
    String nazwaZip, {
    void Function(Postep)? onPostep,
  }) async {
    if (!nazwaZip.toLowerCase().endsWith('.zip')) nazwaZip = '$nazwaZip.zip';
    final wyjscie = wolnaNazwa(katalogDocelowy, nazwaZip);

    final koder = ZipFileEncoder();
    koder.create(wyjscie);
    try {
      for (var i = 0; i < zrodla.length; i++) {
        final s = zrodla[i];
        onPostep?.call(Postep(i, zrodla.length, p.basename(s)));
        final dir = Directory(s);
        if (dir.existsSync()) {
          await koder.addDirectory(dir);
        } else {
          await koder.addFile(File(s));
        }
      }
    } finally {
      koder.close();
    }
    onPostep?.call(Postep(zrodla.length, zrodla.length, ''));
    return wyjscie;
  }

  /// Podglad zawartosci ZIP bez rozpakowywania.
  static Future<List<String>> pokazZawartoscZip(String sciezkaZip) async {
    final bajty = await File(sciezkaZip).readAsBytes();
    final archiwum = ZipDecoder().decodeBytes(bajty);
    return archiwum.files.map((f) => f.name).toList();
  }

  // ---------- Wyszukiwanie ----------

  /// Rekurencyjne wyszukiwanie po fragmencie nazwy (case-insensitive).
  static Stream<FileEntry> szukaj(
    String katalogStartowy,
    String fraza, {
    int maxWynikow = 500,
  }) async* {
    final szukane = fraza.toLowerCase();
    var licznik = 0;
    final kolejka = <Directory>[Directory(katalogStartowy)];

    while (kolejka.isNotEmpty && licznik < maxWynikow) {
      final dir = kolejka.removeAt(0);
      try {
        await for (final e in dir.list(followLinks: false)) {
          if (licznik >= maxWynikow) return;
          final fe = FileEntry.from(e);
          if (fe == null) continue;
          if (fe.name.toLowerCase().contains(szukane)) {
            licznik++;
            yield fe;
          }
          if (fe.isDir) kolejka.add(Directory(fe.path));
        }
      } catch (_) {
        // brak uprawnien do katalogu - pomijamy
      }
    }
  }
}
