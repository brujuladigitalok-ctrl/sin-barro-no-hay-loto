import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final practiceStore = PracticeStore();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await practiceStore.load();
  runApp(const MyApp());
}

// =====================
// STORE (contador + guardado)
// =====================
class PracticeStore extends ChangeNotifier {
  static const _kTotal = 'total_seconds';
  static const _kRunning = 'session_running';
  static const _kStart = 'session_start_epoch_ms';
  static const _kAccum = 'session_accum_seconds';
  static const _kLastQuoteIndex = 'last_quote_index';
  static const _kLastQuoteDayKey = 'last_quote_day_key';

  bool _running = false;
  int _totalSeconds = 0;

  int _sessionAccumSeconds = 0;
  int? _sessionStartEpochMs;

  Timer? _ticker;

  // frases
  late List<String> _quotes;
  int _quoteIndex = 0;

  bool get running => _running;
  int get totalSeconds => _totalSeconds;

  int get currentSessionSeconds {
    if (!_running || _sessionStartEpochMs == null) return _sessionAccumSeconds;
    final now = DateTime.now().millisecondsSinceEpoch;
    final delta = ((now - _sessionStartEpochMs!) / 1000).floor();
    return _sessionAccumSeconds + delta;
  }

  String get todayQuote => _quotes[_quoteIndex];

  Future<void> load() async {
    _quotes = _defaultQuotes();

    final sp = await SharedPreferences.getInstance();
    _totalSeconds = sp.getInt(_kTotal) ?? 0;
    _running = sp.getBool(_kRunning) ?? false;
    _sessionStartEpochMs = sp.getInt(_kStart);
    _sessionAccumSeconds = sp.getInt(_kAccum) ?? 0;

    // frase diaria (cambia 1 vez por día, estable)
    final now = DateTime.now();
    final dayKey = '${now.year}-${now.month}-${now.day}';
    final savedDayKey = sp.getString(_kLastQuoteDayKey);
    final savedIndex = sp.getInt(_kLastQuoteIndex) ?? 0;

    if (savedDayKey == dayKey) {
      _quoteIndex = savedIndex.clamp(0, _quotes.length - 1);
    } else {
      // cambio de día -> nuevo índice
      _quoteIndex = (savedIndex + 1) % _quotes.length;
      await sp.setString(_kLastQuoteDayKey, dayKey);
      await sp.setInt(_kLastQuoteIndex, _quoteIndex);
    }

    _startTicker();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kTotal, _totalSeconds);
    await sp.setBool(_kRunning, _running);

    if (_sessionStartEpochMs != null) {
      await sp.setInt(_kStart, _sessionStartEpochMs!);
    } else {
      await sp.remove(_kStart);
    }

    await sp.setInt(_kAccum, _sessionAccumSeconds);
  }

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _sessionStartEpochMs = DateTime.now().millisecondsSinceEpoch;
    await _save();
    notifyListeners();
  }

  Future<void> pause() async {
    if (!_running) return;
    _sessionAccumSeconds = currentSessionSeconds;
    _running = false;
    _sessionStartEpochMs = null;
    await _save();
    notifyListeners();
  }

  Future<void> finishAndSaveToTotal() async {
    final session = currentSessionSeconds;
    _totalSeconds += session;

    _running = false;
    _sessionStartEpochMs = null;
    _sessionAccumSeconds = 0;

    await _save();
    notifyListeners();
  }

  Future<void> resetSession() async {
    _running = false;
    _sessionStartEpochMs = null;
    _sessionAccumSeconds = 0;
    await _save();
    notifyListeners();
  }

  String fmt(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  double get millionProgress {
    // 1.000.000 daimoku ~ 333 horas (aprox)
    // 333 horas = 333*3600 segundos
    const targetSeconds = 333 * 3600;
    final p = totalSeconds / targetSeconds;
    return p.clamp(0.0, 1.0);
  }

  List<String> _defaultQuotes() => const [
        'Tu vida tiene una misión. Caminá con dignidad.',
        'Que tu daimoku sea la brújula, no el miedo.',
        'Hoy elegí paz. El resto se ordena después.',
        'Aunque tiemble, seguí.',
        'Dignidad primero. Resultado después.',
        'Tu revolución es diaria.',
        'No negocies con la duda. Cantá.',
        'Con barro, con cansancio, con todo: igual florecés.',
        'Lo que hoy te pesa, mañana te fortalece.',
        'Un minuto hoy vale más que “algún día”.',
        'No busques perfección: buscá continuidad.',
      ];
}

// =====================
// APP + THEME
// =====================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const _bg = Color(0xFFEFE6DA);
  static const _card = Color(0xFFF6EFE6);
  static const _ink = Color(0xFF2B2B2B);
  static const _accent = Color(0xFF7A5C4A);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sin barro no hay loto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _bg,
        colorScheme: ColorScheme.fromSeed(seedColor: _accent),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
          bodyMedium: TextStyle(fontSize: 14, color: _ink),
        ),
        cardTheme: const CardThemeData(
          color: _card,
          elevation: 2,
          margin: EdgeInsets.zero,
        ),
      ),
      home: const Shell(),
    );
  }
}

// =====================
// SHELL con bottom nav
// =====================
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  final pages = const [
    HomePage(),
    PracticePage(),
    ObjectivesPage(),
    AgendaPage(),
    SupportPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.local_florist_outlined), selectedIcon: Icon(Icons.local_florist), label: 'Práctica'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Objetivos'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Apoyo'),
        ],
      ),
    );
  }
}

// =====================
// UI helpers
// =====================
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: padding, child: child),
    );
  }
}

// =====================
// PAGES
// =====================
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: practiceStore,
      builder: (_, __) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const SizedBox(height: 8),
              const Center(
                child: Text('Inicio', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 16),

              // Imagen en tarjeta (que se lea y quede prolija siempre)
              AppCard(
                padding: const EdgeInsets.all(0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.asset(
                      'lib/assets/images/sin_barro_no_hay_loto.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Aliento del día', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                            practiceStore.todayQuote,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          const Text('Cambia todos los días automáticamente.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Accesos rápidos', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: const [
                        _QuickButton(icon: Icons.local_florist, label: 'Ir a Mi práctica'),
                        _QuickButton(icon: Icons.flag, label: 'Mis objetivos'),
                        _QuickButton(icon: Icons.event_note, label: 'Mi agenda'),
                        _QuickButton(icon: Icons.menu_book, label: 'Mi apoyo'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _QuickButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// =====================
// PRACTICE (lo importante)
// =====================
class PracticePage extends StatelessWidget {
  const PracticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: practiceStore,
      builder: (_, __) {
        final session = practiceStore.fmt(practiceStore.currentSessionSeconds);
        final total = practiceStore.fmt(practiceStore.totalSeconds);
        final progress = practiceStore.millionProgress;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const SizedBox(height: 8),
              const Text('Mi práctica', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sesión actual', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Text(session, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: practiceStore.running ? null : () => practiceStore.start(),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Empezar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: practiceStore.running ? () => practiceStore.pause() : null,
                            icon: const Icon(Icons.pause),
                            label: const Text('Pausa'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        TextButton(
                          onPressed: () => practiceStore.finishAndSaveToTotal(),
                          child: const Text('Terminé'),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () => practiceStore.resetSession(),
                          child: const Text('Reset sesión'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              AppCard(
                child: Row(
                  children: [
                    const Expanded(child: Text('Total acumulado')),
                    Text(total, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Progreso 1 millón (simple, sin romperte la cabeza)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Camino al 1.000.000', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('${(progress * 100).toStringAsFixed(1)}% (aprox. 333 horas = 1 millón)', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 14),

                    // Loto (placeholder visual): base + fill “tapado” por porcentaje
                    Center(
                      child: SizedBox(
                        width: 260,
                        height: 260,
                        child: Stack(
                          children: [
                            Image.asset('lib/assets/images/loto_base.png', width: 260, height: 260, fit: BoxFit.contain),
                            ClipRect(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                heightFactor: progress, // se “pinta” desde abajo
                                child: Image.asset('lib/assets/images/lotus_fill.png', width: 260, height: 260, fit: BoxFit.contain),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              const Text('Tip: tocás “Terminé” y esa sesión se suma al total y queda guardado.', style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        );
      },
    );
  }
}

// =====================
// OTRAS PANTALLAS (placeholder)
// =====================
class ObjectivesPage extends StatelessWidget {
  const ObjectivesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: Text('Objetivos (próximo paso)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
    );
  }
}

class AgendaPage extends StatelessWidget {
  const AgendaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: Text('Agenda (próximo paso)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
    );
  }
}

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: Text('Apoyo (próximo paso)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
    );
  }
}
