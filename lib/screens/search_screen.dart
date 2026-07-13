import 'dart:async';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../models/file_entry.dart';
import '../services/file_service.dart';
import '../services/settings_service.dart';
import '../widgets/file_tile.dart';

class SearchScreen extends StatefulWidget {
  final String katalog;
  final SettingsService ustawienia;
  final void Function(String sciezka) onOtworzKatalog;

  const SearchScreen({
    super.key,
    required this.katalog,
    required this.ustawienia,
    required this.onOtworzKatalog,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _kontroler = TextEditingController();
  final _wyniki = <FileEntry>[];
  StreamSubscription<FileEntry>? _sub;
  Timer? _debounce;
  bool _szuka = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    _kontroler.dispose();
    super.dispose();
  }

  void _naZmiane(String tekst) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _szukaj(tekst));
  }

  void _szukaj(String fraza) {
    _sub?.cancel();
    setState(() {
      _wyniki.clear();
      _szuka = fraza.trim().length >= 2;
    });
    if (fraza.trim().length < 2) return;

    _sub = FileService.szukaj(widget.katalog, fraza.trim()).listen(
      (w) {
        if (!mounted) return;
        setState(() => _wyniki.add(w));
      },
      onDone: () {
        if (mounted) setState(() => _szuka = false);
      },
      onError: (_) {
        if (mounted) setState(() => _szuka = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wzgledny = widget.katalog.replaceFirst('/storage/emulated/0', 'Pamiec');

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _kontroler,
          autofocus: true,
          onChanged: _naZmiane,
          decoration: const InputDecoration(
            hintText: 'Szukaj w tym folderze...',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_kontroler.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                _kontroler.clear();
                _szukaj('');
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                wzgledny,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_szuka) const LinearProgressIndicator(),
          Expanded(
            child: _wyniki.isEmpty
                ? Center(
                    child: Text(
                      _kontroler.text.trim().length < 2
                          ? 'Wpisz min. 2 znaki'
                          : (_szuka ? 'Szukam...' : 'Brak wynikow'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _wyniki.length,
                    itemBuilder: (_, i) {
                      final w = _wyniki[i];
                      final folder = p
                          .dirname(w.path)
                          .replaceFirst('/storage/emulated/0', 'Pamiec');
                      return ListTile(
                        leading: FileIcon(
                          wpis: w,
                          miniatury: widget.ustawienia.miniatury,
                        ),
                        title: Text(
                          w.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          folder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () {
                          if (w.isDir) {
                            widget.onOtworzKatalog(w.path);
                          } else {
                            // Folder pliku - zeby uzytkownik zobaczyl go w kontekscie.
                            widget.onOtworzKatalog(p.dirname(w.path));
                          }
                        },
                        trailing: w.isDir
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                                tooltip: 'Otworz',
                                onPressed: () => OpenFilex.open(w.path),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
