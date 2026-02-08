import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

final practiceStore = PracticeStore();
final tabController = TabControllerStore();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await practiceStore.load();
  runApp(const MyApp());
}

// =====================
// TAB CONTROLLER (para accesos rápidos)
// =====================
class TabControllerStore extends ChangeNotifier {
  int _index = 0;
  int get index => _index;

  void goTo(int i) {
    _index = i;
    notifyListeners();
  }
}

// =====================
// STORE (contador + guardado) + Objetivos + Agenda
// =====================
class PracticeStore extends ChangeNotifier {
  static const _kTotal = 'total_seconds';
  static const _kRunning = 'session_running';
  static const _kStart = 'session_start_epoch_ms';
  static const _kAccum = 'session_accum_seconds';
  static const _kLastQuoteIndex = 'last_quote_index';
  static const _kLastQuoteDayKey = 'last_quote_day_key';

  static const _kObjectives = 'objectives_json';
  static const _kAgenda = 'agenda_json';

  bool _running = false;
  int _totalSeconds = 0;

  int _sessionAccumSeconds = 0;
  int? _sessionStartEpochMs;

  Timer? _ticker;

  // frases
  late List<String> _quotes;
  int _quoteIndex = 0;

  // objetivos y agenda
  List<ObjectiveItem> _objectives = [];
  List<AgendaItem> _agenda = [];

  bool get running => _running;
  int get totalSeconds => _totalSeconds;

  List<ObjectiveItem> get objectives => List.unmodifiable(_objectives);
  List<AgendaItem> get agenda => List.unmodifiable(_agenda);

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

    // frase diaria (cambia 1 vez por día)
    final now = DateTime.now();
    final dayKey = '${now.year}-${now.month}-${now.day}';
    final savedDayKey = sp.getString(_kLastQuoteDayKey);
    final savedIndex = sp.getInt(_kLastQuoteIndex) ?? 0;

    if (savedDayKey == dayKey) {
      _quoteIndex = savedIndex.clamp(0, _quotes.length - 1);
    } else {
      _quoteIndex = (savedIndex + 1) % _quotes.length;
      await sp.setString(_kLastQuoteDayKey, dayKey);
      await sp.setInt(_kLastQuoteIndex, _quoteIndex);
    }

    // objetivos
    final objRaw = sp.getString(_kObjectives);
    if (objRaw != null && objRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(objRaw) as List<dynamic>;
        _objectives = decoded.map((e) => ObjectiveItem.fromJson(e)).toList();
      } catch (_) {
        _objectives = _seedObjectives();
      }
    } else {
      _objectives = _seedObjectives();
    }

    // agenda
    final agRaw = sp.getString(_kAgenda);
    if (agRaw != null && agRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(agRaw) as List<dynamic>;
        _agenda = decoded.map((e) => AgendaItem.fromJson(e)).toList();
      } catch (_) {
        _agenda = _seedAgenda();
      }
    } else {
      _agenda = _seedAgenda();
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

  Future<void> _saveCore() async {
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

  Future<void> _saveObjectivesAgenda() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kObjectives, jsonEncode(_objectives.map((e) => e.toJson()).toList()));
    await sp.setString(_kAgenda, jsonEncode(_agenda.map((e) => e.toJson()).toList()));
  }

  // ---------- CONTADOR ----------
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _sessionStartEpochMs = DateTime.now().millisecondsSinceEpoch;
    await _saveCore();
    notifyListeners();
  }

  Future<void> pause() async {
    if (!_running) return;
    _sessionAccumSeconds = currentSessionSeconds;
    _running = false;
    _sessionStartEpochMs = null;
    await _saveCore();
    notifyListeners();
  }

  Future<void> finishAndSaveToTotal() async {
    final session = currentSessionSeconds;
    _totalSeconds += session;

    _running = false;
    _sessionStartEpochMs = null;
    _sessionAccumSeconds = 0;

    await _saveCore();
    notifyListeners();
  }

  Future<void> resetSession() async {
    _running = false;
    _sessionStartEpochMs = null;
    _sessionAccumSeconds = 0;
    await _saveCore();
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
    // 1.000.000 daimoku ~ 333 horas
    const targetSeconds = 333 * 3600;
    final p = totalSeconds / targetSeconds;
    return p.clamp(0.0, 1.0);
  }

  // ---------- OBJETIVOS ----------
  Future<void> addObjective(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    _objectives.insert(0, ObjectiveItem(id: DateTime.now().millisecondsSinceEpoch.toString(), text: t, done: false));
    await _saveObjectivesAgenda();
    notifyListeners();
  }

  Future<void> toggleObjective(String id) async {
    final idx = _objectives.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _objectives[idx] = _objectives[idx].copyWith(done: !_objectives[idx].done);
    await _saveObjectivesAgenda();
    notifyListeners();
  }

  Future<void> deleteObjective(String id) async {
    _objectives.removeWhere((e) => e.id == id);
    await _saveObjectivesAgenda();
    notifyListeners();
  }

  // ---------- AGENDA ----------
  Future<void> addAgenda(String title, String note) async {
    final t = title.trim();
    if (t.isEmpty) return;
    _agenda.insert(
      0,
      AgendaItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: t,
        note: note.trim(),
        createdAtIso: DateTime.now().toIso8601String(),
      ),
    );
    await _saveObjectivesAgenda();
    notifyListeners();
  }

  Future<void> deleteAgenda(String id) async {
    _agenda.removeWhere((e) => e.id == id);
    await _saveObjectivesAgenda();
    notifyListeners();
  }

  // seeds
  List<ObjectiveItem> _seedObjectives() => [
        ObjectiveItem(id: '1', text: 'Cantar daimoku todos los días (aunque sea 5 min)', done: false),
        ObjectiveItem(id: '2', text: 'Practicar con continuidad, no con perfección', done: false),
      ];

  List<AgendaItem> _seedAgenda() => [
        AgendaItem(id: '1', title: 'Reunión del han', note: 'Último martes del mes', createdAtIso: DateTime.now().toIso8601String()),
        AgendaItem(id: '2', title: 'Daimoku + Gongyo', note: 'Mañana y noche', createdAtIso: DateTime.now().toIso8601String()),
      ];

  List<String> _defaultQuotes() => const [
        'Sean como el sol. Si lo hacen, disiparán la penumbra a su alrededor. Pase lo que pase, vivan con la convicción y la seguridad de que ustedes son un sol en sí mismos Por supuesto, en la vida hay días de sol y días nublados. Pero el sol sigue brillando siempre, incluso detrás de las nubes. Aunque estén sufriendo, es vital que siempre mantengan despejado el sol de su corazón.',
        'La realidad es rigurosa… Por favor, sigan luchando contra las dificultades que se les presenten y, en cada caso, triunfen, y vuelvan a triunfar, una y otra vez: en la vida diaria, en el trabajo, en los estudios y en las relaciones familiares. Las enseñanzas del budismo y nuestra práctica de la fe son la fuerza motriz de un desarrollo ilimitado.',
        'Los que creen en el Sutra del loto parecen vivir en invierno, pero el invierno siempre se convierte en primavera. Ni una sola vez, desde la Antigüedad, alguien ha visto u oído que el invierno se convierta en otoño. Tampoco hemos sabido de ningún creyente en el Sutra del loto que continúe siendo una persona común.',
        'Nichiren Daishonin escribe: «Si uno enciende un farol para dar luz a otros, también alumbra su propio camino». En una sociedad en proceso de envejecimiento, la postura de contribuir al bienestar de los demás es muy importante. En definitiva, significa también iluminar la propia vida. La persona capaz de decir «gracias» de manera sincera tiene un espíritu sano y vital; cada vez que lo decimos, nuestro corazón resplandece y nuestra vitalidad se eleva poderosamente.',
        'Los problemas, son problemas precisamente porque dudamos de nuestra capacidad para superarlos. Pero cuando enfrentamos desafíos con convicción en la fe, en el potencial ilimitado de nuestra naturaleza de Buda innata, cambiamos nuestro estado de vida y transformamos nuestra forma de responder ante ellos. De esta confianza surge la sabiduría para percibir claramente nuestras circunstancias. De esta manera, es posible transformar los problemas y reorientarlos hacia la felicidad; convertir la desdicha en alegría; la angustia en esperanza, y las preocupaciones en serenidad interior.',
        '«Gracias» es una expresión milagrosa. Nos sentimos revitalizados al decirla, y alentados al escucharla. Cuando decimos o escuchamos esa palabra, nos despojamos de la coraza que cubre nuestro corazón y podemos comunicarnos en el nivel más profundo. «Gracias» es la raíz de la no violencia. Contiene respeto hacia el otro, humildad y una profunda afirmación de la vida',
        'Cuando el sol se eleva, ilumina todo lo que existe sobre la tierra. Cuando, de noche, se enciende un faro, puede guiar a puerto seguro a numerosos barcos. Y cuando en una familia alguien es un firme pilar, todos los integrantes pueden estar a buen resguardo y tranquilos.Les pido que vivan siempre con actitud positiva y alegre, acogiendo a quienes los rodean con corazón abierto, amplio y humano.',
        'No hay una sola oración al Gohonzon que quede sin respuesta. La Ley Mística es una gran enseñanza, que nos permite convertir el veneno en remedio. Mediante la fe, podemos transformar todos los sufrimientos en algo positivo y benéfico, y cultivar un estado de vida más elevado.',
        'Los que posean el corazón de un león rey sin falta manifestarán la budeidad. Así que ¡pongámonos de pie y clamemos con la bravura del león! Así es la enseñanza del Daishonin. Sigamos esforzándonos por superar todos los obstáculos y triunfar con el corazón invencible de un rey león.',
      ];
}

class ObjectiveItem {
  final String id;
  final String text;
  final bool done;

  ObjectiveItem({required this.id, required this.text, required this.done});

  ObjectiveItem copyWith({String? id, String? text, bool? done}) => ObjectiveItem(
        id: id ?? this.id,
        text: text ?? this.text,
        done: done ?? this.done,
      );

  factory ObjectiveItem.fromJson(dynamic json) {
    final m = json as Map<String, dynamic>;
    return ObjectiveItem(id: m['id'] as String, text: m['text'] as String, done: m['done'] as bool);
  }

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'done': done};
}

class AgendaItem {
  final String id;
  final String title;
  final String note;
  final String createdAtIso;

  AgendaItem({required this.id, required this.title, required this.note, required this.createdAtIso});

  factory AgendaItem.fromJson(dynamic json) {
    final m = json as Map<String, dynamic>;
    return AgendaItem(
      id: m['id'] as String,
      title: m['title'] as String,
      note: (m['note'] ?? '') as String,
      createdAtIso: (m['createdAtIso'] ?? DateTime.now().toIso8601String()) as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'note': note, 'createdAtIso': createdAtIso};
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
      home: const SplashScreen(),
    );
  }
}

// =====================
// SPLASH (full screen y sin “flash” feo)
// =====================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // precache para que no aparezca “chiquita” mientras carga
    precacheImage(const AssetImage('lib/assets/images/sin_barro_no_hay_loto.png'), context);
  }

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Shell()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Image.asset(
          'lib/assets/images/sin_barro_no_hay_loto.png',
          fit: BoxFit.cover,
        ),
      ),
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
  @override
  void initState() {
    super.initState();
    tabController.addListener(_onTabChange);
  }

  @override
  void dispose() {
    tabController.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() {
    if (!mounted) return;
    setState(() {});
  }

  final pages = const [
    HomePage(),
    PracticePage(),
    ObjectivesPage(),
    AgendaPage(),
    SupportPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final index = tabController.index;

    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => tabController.goTo(i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.local_florist_outlined), selectedIcon: Icon(Icons.local_florist), label: 'Daimoku'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Objetivos'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Materiales'),
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

              // Imagen en tarjeta (para el “inicio”)
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
                        _QuickButton(icon: Icons.local_florist, label: 'Ir a Mi Daimoku', goTo: 1),
                        _QuickButton(icon: Icons.flag, label: 'Mis objetivos', goTo: 2),
                        _QuickButton(icon: Icons.event_note, label: 'Mi agenda', goTo: 3),
                        _QuickButton(icon: Icons.menu_book, label: 'Materiales', goTo: 4),
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
  final int goTo;
  const _QuickButton({required this.icon, required this.label, required this.goTo});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => tabController.goTo(goTo),
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
// PRACTICE (contador + loto)
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
              const Text('Mi Daimoku', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
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
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}% (aprox. 333 horas = 1 millón)',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 14),

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
// OBJETIVOS
// =====================
class ObjectivesPage extends StatefulWidget {
  const ObjectivesPage({super.key});

  @override
  State<ObjectivesPage> createState() => _ObjectivesPageState();
}

class _ObjectivesPageState extends State<ObjectivesPage> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: practiceStore,
      builder: (_, __) {
        final items = practiceStore.objectives;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const SizedBox(height: 8),
              const Text('Objetivos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Agregar objetivo', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Ej: 10 min de daimoku antes de dormir',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await practiceStore.addObjective(_ctrl.text);
                          _ctrl.clear();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mis objetivos', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      const Text('Todavía no agregaste objetivos.')
                    else
                      ...items.map(
                        (o) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Checkbox(
                            value: o.done,
                            onChanged: (_) => practiceStore.toggleObjective(o.id),
                          ),
                          title: Text(
                            o.text,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              decoration: o.done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => practiceStore.deleteObjective(o.id),
                          ),
                        ),
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

// =====================
// AGENDA
// =====================
class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  final _title = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: practiceStore,
      builder: (_, __) {
        final items = practiceStore.agenda;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const SizedBox(height: 8),
              const Text('Agenda', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Agregar actividad', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _title,
                      decoration: const InputDecoration(
                        hintText: 'Título (ej: Gongyo mañana)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _note,
                      decoration: const InputDecoration(
                        hintText: 'Nota (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await practiceStore.addAgenda(_title.text, _note.text);
                          _title.clear();
                          _note.clear();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mis actividades', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      const Text('Todavía no agregaste actividades.')
                    else
                      ...items.map(
                        (a) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: a.note.trim().isEmpty ? null : Text(a.note),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => practiceStore.deleteAgenda(a.id),
                          ),
                        ),
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

// =====================
// MATERIALES (SupportPage) - LINKS FIJOS
// =====================
class _MaterialLink {
  final String title;
  final String subtitle;
  final String url;
  final IconData icon;

  const _MaterialLink({
    required this.title,
    required this.subtitle,
    required this.url,
    required this.icon,
  });
}

Future<void> _openExternal(String url) async {
  final uri = Uri.parse(url);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    // Si algo falla, no rompemos nada: solo no abre.
    // (si querés, después le metemos un SnackBar)
  }
}

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  // Links oficiales que me pasaste (fijos)
  static const _conceptos = _MaterialLink(
    title: 'Conceptos budistas',
    subtitle: 'Playlist oficial',
    url: 'https://www.youtube.com/playlist?list=PLRaQX2789a3AU9Wbi9m-aiUIJ74GJb7Tk',
    icon: Icons.lightbulb_outline,
  );

  static const _seminarioSutra = _MaterialLink(
    title: 'Seminario: Sabiduría del Sutra del Loto',
    subtitle: 'Playlist oficial',
    url: 'https://www.youtube.com/playlist?list=PLRaQX2789a3DgrDc0yWrKNh-jtozuKSDL',
    icon: Icons.school_outlined,
  );

  static const _nuestraPractica = _MaterialLink(
    title: 'Nuestra práctica',
    subtitle: 'Playlist oficial',
    url: 'https://www.youtube.com/playlist?list=PLV63PB117m0kY1A2PURNEqv4MGzY9UJ30',
    icon: Icons.local_florist_outlined,
  );

  static const _experiencias = _MaterialLink(
    title: 'Experiencias',
    subtitle: 'Playlist oficial',
    url: 'https://www.youtube.com/playlist?list=PLRaQX2789a3CJ5CVx6sSnb4ghCMEnZsFR',
    icon: Icons.favorite_border,
  );

  static const _revolucionHumana = _MaterialLink(
    title: 'Historias de Revolución Humana',
    subtitle: 'Playlist oficial',
    url: 'https://www.youtube.com/playlist?list=PLRaQX2789a3CgxoQHJ499ie3CzAqHlWCw',
    icon: Icons.auto_stories_outlined,
  );

  static const _podcast = _MaterialLink(
    title: 'Podcast de Humanismo Soka',
    subtitle: 'Playlist oficial',
    url: 'https://www.youtube.com/playlist?list=PLRaQX2789a3APT-D8DFTG3LChHmfv1H5u',
    icon: Icons.podcasts_outlined,
  );

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
              const Text('Materiales', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),

              // Mantengo TU aliento del día tal cual
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Aliento del día', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(practiceStore.todayQuote, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Text('Se actualiza solo cada día.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Para aprender conceptos', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    _LinkTile(link: _conceptos),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Para estudiar', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    _LinkTile(link: _seminarioSutra),
                    const Divider(height: 18),
                    _LinkTile(link: _revolucionHumana),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Para la práctica', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    _LinkTile(link: _nuestraPractica),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Para inspirarte', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    _LinkTile(link: _experiencias),
                    const Divider(height: 18),
                    _LinkTile(link: _podcast),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              const Text(
                'Tip: se abren en YouTube (app o navegador).',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LinkTile extends StatelessWidget {
  final _MaterialLink link;
  const _LinkTile({required this.link});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(link.icon),
      title: Text(link.title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(link.subtitle),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => _openExternal(link.url),
    );
  }
}
