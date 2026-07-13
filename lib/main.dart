import 'package:flutter/material.dart';

import 'screens/browser_screen.dart';
import 'services/clipboard_service.dart';
import 'services/permission_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ustawienia = SettingsService();
  await ustawienia.wczytaj();
  runApp(EksploratorApp(ustawienia: ustawienia));
}

class EksploratorApp extends StatelessWidget {
  final SettingsService ustawienia;
  const EksploratorApp({super.key, required this.ustawienia});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ustawienia,
      builder: (_, __) => MaterialApp(
        title: 'Eksplorator',
        debugShowCheckedModeBanner: false,
        themeMode: ustawienia.motyw,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3182CE),
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3182CE),
            brightness: Brightness.dark,
          ),
        ),
        home: BramkaUprawnien(ustawienia: ustawienia),
      ),
    );
  }
}

/// Ekran startowy - sprawdza uprawnienia zanim wpusci do eksploratora.
class BramkaUprawnien extends StatefulWidget {
  final SettingsService ustawienia;
  const BramkaUprawnien({super.key, required this.ustawienia});

  @override
  State<BramkaUprawnien> createState() => _BramkaUprawnienState();
}

class _BramkaUprawnienState extends State<BramkaUprawnien>
    with WidgetsBindingObserver {
  bool? _maDostep;
  final _schowek = ClipboardService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sprawdz();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _schowek.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Po powrocie z ustawien systemowych sprawdzamy ponownie.
    if (state == AppLifecycleState.resumed && _maDostep != true) {
      _sprawdz();
    }
  }

  Future<void> _sprawdz() async {
    final ok = await PermissionService.maDostep();
    if (mounted) setState(() => _maDostep = ok);
  }

  Future<void> _popros() async {
    final ok = await PermissionService.popros();
    if (mounted) setState(() => _maDostep = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (_maDostep == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_maDostep == true) {
      return BrowserScreen(ustawienia: widget.ustawienia, schowek: _schowek);
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_open_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Potrzebny dostęp do plików',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Aplikacja musi mieć dostęp do całej pamięci, '
                'żeby przeglądać, kopiować i pakować pliki.\n\n'
                'W ustawieniach systemu włącz "Zezwól na dostęp do '
                'wszystkich plików".',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _popros,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Przyznaj dostęp'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: PermissionService.otworzUstawienia,
                child: const Text('Otwórz ustawienia aplikacji'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
