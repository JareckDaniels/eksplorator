import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../models/file_entry.dart';
import '../services/apk_service.dart';
import '../services/clipboard_service.dart';
import '../services/file_service.dart';
import '../services/settings_service.dart';
import '../widgets/file_tile.dart';
import 'search_screen.dart';

const String kKorzen = '/storage/emulated/0';

class BrowserScreen extends StatefulWidget {
  final SettingsService ustawienia;
  final ClipboardService schowek;

  const BrowserScreen({
    super.key,
    required this.ustawienia,
    required this.schowek,
  });

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  String _sciezka = kKorzen;
  List<FileEntry> _wpisy = [];
  final Set<String> _zaznaczone = {};
  bool _laduje = true;
  String? _blad;

  // Zapamietana pozycja scrolla dla kazdego katalogu.
  final Map<String, double> _pozycje = {};
  final ScrollController _scroll = ScrollController();

  bool get _trybSelekcji => _zaznaczone.isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.ustawienia.addListener(_odswiez);
    widget.schowek.addListener(_naSchowek);
    _odswiez();
  }

  @override
  void dispose() {
    widget.ustawienia.removeListener(_odswiez);
    widget.schowek.removeListener(_naSchowek);
    _scroll.dispose();
    super.dispose();
  }

  void _naSchowek() => setState(() {});

  Future<void> _odswiez() async {
    setState(() {
      _laduje = true;
      _blad = null;
    });
    try {
      final lista = await FileService.listuj(
        _sciezka,
        sortuj: widget.ustawienia.sortuj,
        rosnaco: widget.ustawienia.rosnaco,
        pokazUkryte: widget.ustawienia.pokazUkryte,
      );
      if (!mounted) return;
      setState(() {
        _wpisy = lista;
        _laduje = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _blad = 'Brak dostępu do tego katalogu';
        _wpisy = [];
        _laduje = false;
      });
    }
  }

  Future<void> _wejdz(String nowa) async {
    // Zapamietaj gdzie bylismy w biezacym katalogu.
    if (_scroll.hasClients) _pozycje[_sciezka] = _scroll.offset;
    setState(() {
      _sciezka = nowa;
      _zaznaczone.clear();
    });
    await _odswiez();
    // Przywroc pozycje scrolla jesli wracamy do odwiedzonego katalogu.
    final zapisana = _pozycje[nowa];
    if (zapisana != null && _scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(zapisana.clamp(0, _scroll.position.maxScrollExtent));
        }
      });
    }
  }

  bool get _mozeWyzej => _sciezka != kKorzen && _sciezka != '/';

  Future<void> _wyzej() async {
    if (!_mozeWyzej) return;
    await _wejdz(p.dirname(_sciezka));
  }

  Future<bool> _naWstecz() async {
    if (_trybSelekcji) {
      setState(() => _zaznaczone.clear());
      return false;
    }
    if (_mozeWyzej) {
      await _wyzej();
      return false;
    }
    return true;
  }

  void _przelaczZaznaczenie(FileEntry w) {
    setState(() {
      if (_zaznaczone.contains(w.path)) {
        _zaznaczone.remove(w.path);
      } else {
        _zaznaczone.add(w.path);
      }
    });
  }

  Future<void> _otworz(FileEntry w) async {
    if (w.isDir) {
      await _wejdz(w.path);
      return;
    }
    if (w.isZip) {
      await _menuZip(w);
      return;
    }
    if (w.isApk) {
      await _zainstalujApk(w);
      return;
    }
    final wynik = await OpenFilex.open(w.path);
    if (wynik.type != ResultType.done && mounted) {
      _pokazSnack('Nie znaleziono aplikacji do otwarcia tego pliku');
    }
  }

  /// Instalacja APK. Android 8+ wymaga zgody "Instaluj nieznane aplikacje"
  /// przyznanej osobno dla tej aplikacji - jesli jej nie ma, prowadzimy
  /// uzytkownika do wlasciwego ekranu ustawien.
  Future<void> _zainstalujApk(FileEntry w) async {
    final moze = await ApkService.czyMozeInstalowac();

    if (!moze) {
      if (!mounted) return;
      final idz = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Potrzebna zgoda'),
          content: const Text(
            'Aby instalować aplikacje, Android wymaga włączenia opcji '
            '"Instaluj nieznane aplikacje" dla Eksploratora.\n\n'
            'Przejść do ustawień?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ustawienia'),
            ),
          ],
        ),
      );
      if (idz == true) await ApkService.otworzUstawienieInstalacji();
      return;
    }

    if (!mounted) return;
    final wybor = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    w.sizeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Zainstaluj'),
              subtitle: const Text('Uruchomi instalator systemowy'),
              onTap: () => Navigator.pop(ctx, 'instaluj'),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Otwórz inną aplikacją'),
              onTap: () => Navigator.pop(ctx, 'otworz'),
            ),
          ],
        ),
      ),
    );

    if (wybor == null || !mounted) return;

    if (wybor == 'instaluj') {
      final blad = await ApkService.zainstaluj(w.path);
      if (blad != null && mounted) _pokazSnack(blad);
    } else {
      await OpenFilex.open(w.path);
    }
  }

  void _pokazSnack(String tekst) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tekst)));
  }

  // ---------- Operacje ----------

  /// Uruchamia dluga operacje pokazujac dialog z postepem.
  Future<void> _zPostepem(
    String tytul,
    Future<void> Function(void Function(Postep)) operacja,
  ) async {
    final postep = ValueNotifier<Postep>(const Postep(0, 1, ''));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(tytul),
        content: ValueListenableBuilder<Postep>(
          valueListenable: postep,
          builder: (_, wart, __) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: wart.wszystkie <= 1 ? null : wart.ulamek,
              ),
              const SizedBox(height: 12),
              Text(
                wart.biezacy.isEmpty
                    ? 'Kończę...'
                    : '${wart.wykonane + 1} / ${wart.wszystkie}  ·  ${wart.biezacy}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await operacja((pz) => postep.value = pz);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _pokazSnack('Błąd: ${e is FileSystemException ? e.message : e}');
    } finally {
      postep.dispose();
    }
    await _odswiez();
  }

  Future<void> _wklej() async {
    final schowek = widget.schowek;
    if (schowek.pusty) return;
    final zrodla = schowek.sciezki;
    final wytnij = schowek.tryb == TrybSchowka.wytnij;

    await _zPostepem(
      wytnij ? 'Przenoszenie' : 'Kopiowanie',
      (onPostep) => wytnij
          ? FileService.przenies(zrodla, _sciezka, onPostep: onPostep)
          : FileService.kopiuj(zrodla, _sciezka, onPostep: onPostep),
    );

    if (wytnij) schowek.wyczysc();
    setState(() => _zaznaczone.clear());
  }

  Future<void> _usunZaznaczone() async {
    final ile = _zaznaczone.length;
    final potwierdz = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć?'),
        content: Text(
          ile == 1
              ? 'Element zostanie trwale usunięty.'
              : '$ile elementów zostanie trwale usuniętych.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (potwierdz != true) return;

    final sciezki = _zaznaczone.toList();
    setState(() => _zaznaczone.clear());
    await _zPostepem(
      'Usuwanie',
      (onPostep) => FileService.usun(sciezki, onPostep: onPostep),
    );
  }

  Future<void> _zmienNazwe() async {
    if (_zaznaczone.length != 1) return;
    final stara = _zaznaczone.first;
    final nowa = await _dialogTekstowy(
      tytul: 'Zmień nazwę',
      wartosc: p.basename(stara),
      etykieta: 'Nowa nazwa',
    );
    if (nowa == null || nowa.isEmpty) return;

    setState(() => _zaznaczone.clear());
    try {
      await FileService.zmienNazwe(stara, nowa);
    } catch (e) {
      _pokazSnack('Błąd: ${e is FileSystemException ? e.message : e}');
    }
    await _odswiez();
  }

  Future<void> _nowyFolder() async {
    final nazwa = await _dialogTekstowy(
      tytul: 'Nowy folder',
      wartosc: '',
      etykieta: 'Nazwa folderu',
    );
    if (nazwa == null || nazwa.isEmpty) return;
    try {
      await FileService.nowyFolder(_sciezka, nazwa);
    } catch (e) {
      _pokazSnack('Błąd: ${e is FileSystemException ? e.message : e}');
    }
    await _odswiez();
  }

  Future<void> _spakuj() async {
    final zrodla = _zaznaczone.toList();
    final domyslna = zrodla.length == 1
        ? '${p.basenameWithoutExtension(zrodla.first)}.zip'
        : 'archiwum.zip';

    final nazwa = await _dialogTekstowy(
      tytul: 'Spakuj do ZIP',
      wartosc: domyslna,
      etykieta: 'Nazwa archiwum',
    );
    if (nazwa == null || nazwa.isEmpty) return;

    setState(() => _zaznaczone.clear());
    await _zPostepem(
      'Pakowanie',
      (onPostep) async {
        await FileService.spakuj(zrodla, _sciezka, nazwa, onPostep: onPostep);
      },
    );
    _pokazSnack('Spakowano do $nazwa');
  }

  Future<void> _menuZip(FileEntry w) async {
    final wybor = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                w.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.unarchive_rounded),
              title: const Text('Rozpakuj tutaj'),
              subtitle: const Text('Do nowego folderu w tym katalogu'),
              onTap: () => Navigator.pop(ctx, 'tutaj'),
            ),
            ListTile(
              leading: const Icon(Icons.list_rounded),
              title: const Text('Pokaż zawartość'),
              onTap: () => Navigator.pop(ctx, 'zawartosc'),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Otwórz inną aplikacją'),
              onTap: () => Navigator.pop(ctx, 'otworz'),
            ),
          ],
        ),
      ),
    );

    if (wybor == null || !mounted) return;

    switch (wybor) {
      case 'tutaj':
        final cel = FileService.wolnaNazwa(
          _sciezka,
          p.basenameWithoutExtension(w.name),
        );
        await _zPostepem(
          'Rozpakowywanie',
          (onPostep) => FileService.rozpakuj(w.path, cel, onPostep: onPostep),
        );
        _pokazSnack('Rozpakowano do ${p.basename(cel)}');
        break;

      case 'zawartosc':
        try {
          final lista = await FileService.pokazZawartoscZip(w.path);
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('${lista.length} elementów'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  itemCount: lista.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      lista[i],
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Zamknij'),
                ),
              ],
            ),
          );
        } catch (e) {
          _pokazSnack('Nie udało się odczytać archiwum');
        }
        break;

      case 'otworz':
        await OpenFilex.open(w.path);
        break;
    }
  }

  Future<void> _udostepnij() async {
    final pliki = _zaznaczone
        .where((s) => File(s).existsSync())
        .map((s) => XFile(s))
        .toList();
    if (pliki.isEmpty) {
      _pokazSnack('Można udostępniać tylko pliki, nie foldery');
      return;
    }
    setState(() => _zaznaczone.clear());
    await Share.shareXFiles(pliki);
  }

  Future<String?> _dialogTekstowy({
    required String tytul,
    required String wartosc,
    required String etykieta,
  }) async {
    final kontroler = TextEditingController(text: wartosc);
    // Zaznacz nazwe bez rozszerzenia - wygodniejsza edycja.
    final kropka = wartosc.lastIndexOf('.');
    kontroler.selection = TextSelection(
      baseOffset: 0,
      extentOffset: kropka > 0 ? kropka : wartosc.length,
    );

    final wynik = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tytul),
        content: TextField(
          controller: kontroler,
          autofocus: true,
          decoration: InputDecoration(
            labelText: etykieta,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, kontroler.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    kontroler.dispose();
    return wynik;
  }

  // ---------- UI ----------

  List<String> get _okruchy {
    if (_sciezka == kKorzen) return ['Pamięć'];
    final wzgledna = _sciezka.replaceFirst('$kKorzen/', '');
    return ['Pamięć', ...wzgledna.split('/')];
  }

  String _sciezkaOkrucha(int index) {
    if (index == 0) return kKorzen;
    final czesci = _okruchy.sublist(1, index + 1);
    return p.join(kKorzen, czesci.join('/'));
  }

  Widget _pasekOkruchow() {
    final okruchy = _okruchy;
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        reverse: true,
        itemCount: okruchy.length,
        itemBuilder: (_, i) {
          // reverse:true -> renderujemy od konca, wiec odwracamy indeks.
          final idx = okruchy.length - 1 - i;
          final ostatni = idx == okruchy.length - 1;
          return Row(
            children: [
              if (idx > 0)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.outline,
                ),
              InkWell(
                onTap: ostatni ? null : () => _wejdz(_sciezkaOkrucha(idx)),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(
                    okruchy[idx],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: ostatni ? FontWeight.w600 : FontWeight.w400,
                      color: ostatni
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    final ust = widget.ustawienia;

    if (_trybSelekcji) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => setState(() => _zaznaczone.clear()),
        ),
        title: Text('${_zaznaczone.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all_rounded),
            tooltip: 'Zaznacz wszystko',
            onPressed: () => setState(() {
              if (_zaznaczone.length == _wpisy.length) {
                _zaznaczone.clear();
              } else {
                _zaznaczone
                  ..clear()
                  ..addAll(_wpisy.map((w) => w.path));
              }
            }),
          ),
        ],
      );
    }

    return AppBar(
      title: Text(p.basename(_sciezka) == '0' ? 'Pamięć' : p.basename(_sciezka)),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Szukaj',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchScreen(
                katalog: _sciezka,
                ustawienia: ust,
                onOtworzKatalog: (sciezka) {
                  Navigator.pop(context);
                  _wejdz(sciezka);
                },
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            ust.czyZakladka(_sciezka)
                ? Icons.star_rounded
                : Icons.star_border_rounded,
          ),
          tooltip: 'Zakładka',
          onPressed: () => ust.przelaczZakladke(_sciezka),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'nazwa':
                ust.ustawSortowanie(
                  SortBy.nazwa,
                  ust.sortuj == SortBy.nazwa ? !ust.rosnaco : true,
                );
                break;
              case 'data':
                ust.ustawSortowanie(
                  SortBy.data,
                  ust.sortuj == SortBy.data ? !ust.rosnaco : false,
                );
                break;
              case 'rozmiar':
                ust.ustawSortowanie(
                  SortBy.rozmiar,
                  ust.sortuj == SortBy.rozmiar ? !ust.rosnaco : false,
                );
                break;
              case 'typ':
                ust.ustawSortowanie(
                  SortBy.typ,
                  ust.sortuj == SortBy.typ ? !ust.rosnaco : true,
                );
                break;
              case 'ukryte':
                ust.przelaczUkryte();
                break;
              case 'miniatury':
                ust.przelaczMiniatury();
                break;
            }
          },
          itemBuilder: (_) {
            Widget pozycja(String tekst, SortBy s) => Row(
                  children: [
                    Expanded(child: Text(tekst)),
                    if (ust.sortuj == s)
                      Icon(
                        ust.rosnaco
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 16,
                      ),
                  ],
                );

            return [
              PopupMenuItem(value: 'nazwa', child: pozycja('Nazwa', SortBy.nazwa)),
              PopupMenuItem(value: 'data', child: pozycja('Data', SortBy.data)),
              PopupMenuItem(
                value: 'rozmiar',
                child: pozycja('Rozmiar', SortBy.rozmiar),
              ),
              PopupMenuItem(value: 'typ', child: pozycja('Typ', SortBy.typ)),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(
                value: 'ukryte',
                checked: ust.pokazUkryte,
                child: const Text('Ukryte pliki'),
              ),
              CheckedPopupMenuItem(
                value: 'miniatury',
                checked: ust.miniatury,
                child: const Text('Miniatury'),
              ),
            ];
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: _pasekOkruchow(),
      ),
    );
  }

  Widget? _dolnyPasek() {
    final schowek = widget.schowek;

    if (_trybSelekcji) {
      final tylkoJeden = _zaznaczone.length == 1;
      return BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _przyciskAkcji(
              Icons.content_copy_rounded,
              'Kopiuj',
              () {
                schowek.kopiuj(_zaznaczone.toList());
                setState(() => _zaznaczone.clear());
                _pokazSnack('Skopiowano do schowka');
              },
            ),
            _przyciskAkcji(
              Icons.content_cut_rounded,
              'Wytnij',
              () {
                schowek.wytnij(_zaznaczone.toList());
                setState(() => _zaznaczone.clear());
                _pokazSnack('Wycięte — przejdź do celu i wklej');
              },
            ),
            _przyciskAkcji(
              Icons.drive_file_rename_outline_rounded,
              'Nazwa',
              tylkoJeden ? _zmienNazwe : null,
            ),
            _przyciskAkcji(Icons.folder_zip_rounded, 'ZIP', _spakuj),
            _przyciskAkcji(Icons.share_rounded, 'Udostępnij', _udostepnij),
            _przyciskAkcji(
              Icons.delete_outline_rounded,
              'Usuń',
              _usunZaznaczone,
              kolor: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
      );
    }

    if (!schowek.pusty) {
      final wytnij = schowek.tryb == TrybSchowka.wytnij;
      return BottomAppBar(
        child: Row(
          children: [
            Icon(
              wytnij ? Icons.content_cut_rounded : Icons.content_copy_rounded,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${schowek.ile} ${wytnij ? "do przeniesienia" : "do skopiowania"}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: schowek.wyczysc,
              child: const Text('Anuluj'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _wklej,
              icon: const Icon(Icons.content_paste_rounded, size: 18),
              label: const Text('Wklej'),
            ),
          ],
        ),
      );
    }

    return null;
  }

  Widget _przyciskAkcji(
    IconData ikona,
    String etykieta,
    VoidCallback? onTap, {
    Color? kolor,
  }) {
    final aktywny = onTap != null;
    final c = kolor ??
        (aktywny
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.outline);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikona, size: 22, color: aktywny ? c : c.withOpacity(0.4)),
            const SizedBox(height: 2),
            Text(
              etykieta,
              style: TextStyle(
                fontSize: 10,
                color: aktywny ? c : c.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _szuflada() {
    final ust = widget.ustawienia;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 36,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Eksplorator',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.phone_android_rounded),
            title: const Text('Pamięć wewnętrzna'),
            onTap: () {
              Navigator.pop(context);
              _wejdz(kKorzen);
            },
          ),
          for (final skrot in const [
            ('Pobrane', 'Download', Icons.download_rounded),
            ('Zdjęcia', 'DCIM', Icons.photo_camera_rounded),
            ('Obrazy', 'Pictures', Icons.image_rounded),
            ('Dokumenty', 'Documents', Icons.description_rounded),
            ('Muzyka', 'Music', Icons.music_note_rounded),
            ('Filmy', 'Movies', Icons.movie_rounded),
          ])
            if (Directory(p.join(kKorzen, skrot.$2)).existsSync())
              ListTile(
                leading: Icon(skrot.$3),
                title: Text(skrot.$1),
                onTap: () {
                  Navigator.pop(context);
                  _wejdz(p.join(kKorzen, skrot.$2));
                },
              ),
          if (ust.zakladki.isNotEmpty) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'ZAKŁADKI',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            for (final z in ust.zakladki)
              ListTile(
                leading: const Icon(Icons.star_rounded, color: Color(0xFFF6AD55)),
                title: Text(
                  p.basename(z),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  z.replaceFirst('$kKorzen/', ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => ust.usunZakladke(z),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _wejdz(z);
                },
              ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.brightness_6_rounded),
            title: const Text('Motyw'),
            subtitle: Text(switch (ust.motyw) {
              ThemeMode.light => 'Jasny',
              ThemeMode.dark => 'Ciemny',
              ThemeMode.system => 'Systemowy',
            }),
            onTap: () {
              final kolejny = switch (ust.motyw) {
                ThemeMode.system => ThemeMode.light,
                ThemeMode.light => ThemeMode.dark,
                ThemeMode.dark => ThemeMode.system,
              };
              ust.ustawMotyw(kolejny);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final wyjdz = await _naWstecz();
        if (wyjdz && mounted) Navigator.of(context).maybePop();
      },
      child: Scaffold(
        appBar: _appBar(),
        drawer: _trybSelekcji ? null : _szuflada(),
        bottomNavigationBar: _dolnyPasek(),
        floatingActionButton: _trybSelekcji || !widget.schowek.pusty
            ? null
            : FloatingActionButton(
                onPressed: _nowyFolder,
                tooltip: 'Nowy folder',
                child: const Icon(Icons.create_new_folder_rounded),
              ),
        body: _cialo(),
      ),
    );
  }

  Widget _cialo() {
    if (_laduje) return const Center(child: CircularProgressIndicator());

    if (_blad != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(_blad!),
          ],
        ),
      );
    }

    if (_wpisy.isEmpty) {
      return RefreshIndicator(
        onRefresh: _odswiez,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.folder_off_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  const Text('Pusty folder'),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final wyciete = widget.schowek.tryb == TrybSchowka.wytnij
        ? widget.schowek.sciezki.toSet()
        : const <String>{};

    return RefreshIndicator(
      onRefresh: _odswiez,
      child: ListView.builder(
        controller: _scroll,
        itemCount: _wpisy.length,
        itemBuilder: (_, i) {
          final w = _wpisy[i];
          return FileTile(
            wpis: w,
            zaznaczony: _zaznaczone.contains(w.path),
            trybSelekcji: _trybSelekcji,
            miniatury: widget.ustawienia.miniatury,
            wycinany: wyciete.contains(w.path),
            onTap: () => _trybSelekcji ? _przelaczZaznaczenie(w) : _otworz(w),
            onLongPress: () => _przelaczZaznaczenie(w),
          );
        },
      ),
    );
  }
}
