import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const SinBarroApp());
}

/// ===============================
///  APP
/// ===============================
class SinBarroApp extends StatelessWidget {
  const SinBarroApp({super.key});

  // Paleta inspirada “barro/loto”
  static const Color mud = Color(0xFF5A4636);
  static const Color sand = Color(0xFFF2E9DD);
  static const Color lotus = Color(0xFFB85C79);
  static const Color deep = Color(0xFF2E2420);
  static const Color card = Color(0xFFFFF8EF);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: mud,
        brightness: Brightness.light,
      ).copyWith(
        primary: mud,
        secondary: lotus,
        surface: card,
        background: sand,
      ),
      scaffoldBackgroundColor: sand,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: sand,
        foregroundColor: deep,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFF7EEDF),
        selectedItemColor: mud,
        unselectedItemColor: Color(0xFF8F7C6B),
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.75),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sin barro no hay loto',
      theme: theme,
      home: const SplashScreen(),
    );
  }
}

/// ===============================
///  SPLASH
/// ===============================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeTabs()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox.expand(
        child: _AssetCoverImage(
          path: 'lib/assets/images/sin_barro_no_hay_loto.png',
        ),
      ),
    );
  }
}

/// Imagen full-bleed segura
class _AssetCoverImage extends StatelessWidget {
  final String path;
  const _AssetCoverImage({required this.path});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Center(
        child: Text(
          'No encuentro la imagen.\nRevisá el path del asset.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// ===============================
///  HOME TABS
/// ===============================
class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});
  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int _index = 0;

  final _pages = const [
    InicioPage(),
    MiPracticaPage(),
    ObjetivosPage(),
    ActividadesPage(),
    MiApoyoPage(),
  ];

  @override
  Widget build(BuildContext context) {
    const titles = ['Inicio', 'Mi práctica', 'Objetivos', 'Actividades', 'Mi apoyo'];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[_index],
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(child: _pages[_index]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.spa_rounded), label: 'Práctica'),
          BottomNavigationBarItem(icon: Icon(Icons.flag_rounded), label: 'Objetivos'),
          BottomNavigationBarItem(icon: Icon(Icons.event_note_rounded), label: 'Agenda'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_rounded), label: 'Apoyo'),
        ],
      ),
    );
  }
}

/// ===============================
///  INICIO (imagen fija + aliento diario)
/// ===============================
class InicioPage extends StatelessWidget {
  const InicioPage({super.key});

  static const _alientos = [
    'Sin barro no hay loto.',
    'El invierno siempre se convierte en primavera.',
    'No avanzar es retrodecer.',
    'Un sueño sin acción es una ilusión.',
    'Lo difícil es la señal de que estás creciendo.',
    'No busques perfección: buscá continuidad.',
    'Este día ya trae su propia victoria.',
    'Tu vida tiene una misión. Caminá con dignidad.',
    'Que tu daimoku sea la brújula, no el miedo.',
    'Lo que hoy te pesa, mañana te fortalece.',
    'Si no podés con todo, con una cosa alcanza: sentarte a cantar.',
    'Hoy elegí paz. El resto se ordena después.',
    'La esperanza también se entrena.',
    'No estás tarde: estás empezando bien.',
    'Tu revolución es diaria.',
    'No negocies con la duda. Cantá.',
    'Tu mejor versión se construye en silencio.',
    'Hoy plantás causas. Mañana cosechás.',
    'Dignidad primero. Resultado después.',
    'Tu vida es más grande que este problema.',
    'Aunque tiemble, seguí.',
    'Tu daimoku abre caminos donde no había.',
    'Un minuto hoy vale más que “algún día”.',
    'Hoy es el día perfecto para volver.',
    'Con barro, con cansancio, con todo: igual florecés.',
    'La fe no es magia: es dirección.',
    'No estás sola. Estás en camino.',
    'Lo que parece estancamiento, a veces es raíz creciendo.',
    'La alegría también es una decisión.',
    'Hoy ganás por presentarte.',
  ];

  String _alientoDeHoy() {
    final now = DateTime.now();
    // Cambia una vez por día: día del año como índice
    final start = DateTime(now.year, 1, 1);
    final dayOfYear = now.difference(start).inDays; // 0..365
    return _alientos[dayOfYear % _alientos.length];
  }

  @override
  Widget build(BuildContext context) {
    final aliento = _alientoDeHoy();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: const AspectRatio(
            aspectRatio: 16 / 10,
            child: _AssetCoverImage(path: 'lib/assets/images/sin_barro_no_hay_loto.png'),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_rounded, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Aliento del día',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        aliento,
                        style: const TextStyle(fontSize: 18, height: 1.25, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cambia todos los días automáticamente.',
                        style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _QuickActions(),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Accesos rápidos', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _chip(context, Icons.spa_rounded, 'Ir a Mi práctica', 1),
                _chip(context, Icons.flag_rounded, 'Mis objetivos', 2),
                _chip(context, Icons.event_note_rounded, 'Mi agenda', 3),
                _chip(context, Icons.menu_book_rounded, 'Mi apoyo', 4),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label, int tabIndex) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () {
        // Truquito: subir hasta HomeTabs y cambiar index (simple: back stack)
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _JumpToTab(tabIndex: tabIndex)),
        );
      },
    );
  }
}

/// Pantalla puente para saltar a una pestaña (sin complicarte estado global)
class _JumpToTab extends StatelessWidget {
  final int tabIndex;
  const _JumpToTab({required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    return HomeTabsJump(tabIndex: tabIndex);
  }
}

class HomeTabsJump extends StatefulWidget {
  final int tabIndex;
  const HomeTabsJump({super.key, required this.tabIndex});
  @override
  State<HomeTabsJump> createState() => _HomeTabsJumpState();
}

class _HomeTabsJumpState extends State<HomeTabsJump> {
  int _index = 0;

  final _pages = const [
    InicioPage(),
    MiPracticaPage(),
    ObjetivosPage(),
    ActividadesPage(),
    MiApoyoPage(),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.tabIndex;
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Inicio', 'Mi práctica', 'Objetivos', 'Actividades', 'Mi apoyo'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index], style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(child: _pages[_index]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.spa_rounded), label: 'Práctica'),
          BottomNavigationBarItem(icon: Icon(Icons.flag_rounded), label: 'Objetivos'),
          BottomNavigationBarItem(icon: Icon(Icons.event_note_rounded), label: 'Agenda'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_rounded), label: 'Apoyo'),
        ],
      ),
    );
  }
}

/// ===============================
///  MI PRÁCTICA (timer + acumulado + loto)
/// ===============================
class MiPracticaPage extends StatefulWidget {
  const MiPracticaPage({super.key});
  @override
  State<MiPracticaPage> createState() => _MiPracticaPageState();
}

class _MiPracticaPageState extends State<MiPracticaPage> {
  static const _prefsTotalSecondsKey = 'total_seconds';

  int _totalSeconds = 0;     // acumulado guardado
  int _sessionSeconds = 0;   // sesión actual
  Timer? _timer;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _loadTotal();
  }

  Future<void> _loadTotal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalSeconds = prefs.getInt(_prefsTotalSecondsKey) ?? 0;
    });
  }

  Future<void> _saveTotal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsTotalSecondsKey, _totalSeconds);
  }

  void _start() {
    if (_running) return;
    setState(() => _running = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _sessionSeconds += 1;
      });
    });
  }

  void _pauseAndAddToTotal() {
    _timer?.cancel();
    _timer = null;

    setState(() {
      _running = false;
      _totalSeconds += _sessionSeconds;
      _sessionSeconds = 0;
    });

    _saveTotal();
  }

  void _resetSession() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _running = false;
      _sessionSeconds = 0;
    });
  }

  void _resetAll() async {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _running = false;
      _sessionSeconds = 0;
      _totalSeconds = 0;
    });
    await _saveTotal();
  }

  String _formatHMS(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  String _formatHours(int seconds) {
    final hours = seconds / 3600.0;
    return hours.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalH = _formatHours(_totalSeconds);
    final session = _formatHMS(_sessionSeconds);
    final total = _formatHMS(_totalSeconds);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_rounded, color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(width: 8),
                    const Text('Sesión actual', style: TextStyle(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text(
                      _running ? 'Cantando…' : 'En pausa',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _running ? const Color(0xFF2B7A3D) : Colors.black.withOpacity(0.55),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  session,
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _running ? null : _start,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Iniciar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: (_sessionSeconds == 0 && !_running) ? null : _pauseAndAddToTotal,
                        icon: const Icon(Icons.pause_rounded),
                        label: const Text('Pausar / Guardar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sessionSeconds == 0 ? null : _resetSession,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Reset sesión'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_totalSeconds == 0 && _sessionSeconds == 0) ? null : _resetAll,
                        icon: const Icon(Icons.delete_forever_rounded),
                        label: const Text('Reset todo'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.insights_rounded, color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(width: 8),
                    const Text('Mi acumulado', style: TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  total,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  '$totalH horas totales',
                  style: TextStyle(color: Colors.black.withOpacity(0.6), fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 18),

                Center(
                  child: _LotusProgress(totalSeconds: _totalSeconds),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Meta simbólica: 333 horas ≈ 1.000.000 daimoku',
                    style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Flor “se pinta” desde abajo hacia arriba
class _LotusProgress extends StatelessWidget {
  final int totalSeconds;
  const _LotusProgress({required this.totalSeconds});

  // 333 horas = meta
  static const int _targetSeconds = 333 * 3600;

  @override
  Widget build(BuildContext context) {
    final progress = (totalSeconds / _targetSeconds).clamp(0.0, 1.0);

    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'lib/assets/images/loto_base.png',
            fit: BoxFit.contain,
            width: 260,
            height: 260,
          ),
          ClipRect(
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: progress, // pinta hacia arriba
              child: Image.asset(
                'lib/assets/images/loto_fill.png',
                fit: BoxFit.contain,
                width: 260,
                height: 260,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================
///  OBJETIVOS (guardar lista)
/// ===============================
class ObjetivosPage extends StatefulWidget {
  const ObjetivosPage({super.key});
  @override
  State<ObjetivosPage> createState() => _ObjetivosPageState();
}

class _ObjetivosPageState extends State<ObjetivosPage> {
  static const _prefsKey = 'objetivos_list';
  final _controller = TextEditingController();
  List<String> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    setState(() {
      _items = raw == null ? [] : List<String>.from(jsonDecode(raw));
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_items));
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items.insert(0, text);
      _controller.clear();
    });
    _save();
  }

  void _remove(int i) {
    setState(() {
      _items.removeAt(i);
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Escribí un objetivo', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Ej: 30 min de daimoku diario por 30 días',
                  ),
                  onSubmitted: (_) => _add(),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Agregar'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Text(
              'Todavía no hay objetivos.\nSumá el primero y lo empezamos a cumplir.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w600),
            ),
          )
        else
          ...List.generate(_items.length, (i) {
            return Card(
              child: ListTile(
                leading: Icon(Icons.flag_rounded, color: Theme.of(context).colorScheme.secondary),
                title: Text(_items[i], style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _remove(i),
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// ===============================
///  ACTIVIDADES (agenda simple)
/// ===============================
class ActividadesPage extends StatefulWidget {
  const ActividadesPage({super.key});
  @override
  State<ActividadesPage> createState() => _ActividadesPageState();
}

class _ActividadesPageState extends State<ActividadesPage> {
  static const _prefsKey = 'actividades_list';
  final _controller = TextEditingController();
  List<String> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    setState(() {
      _items = raw == null ? [] : List<String>.from(jsonDecode(raw));
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_items));
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items.insert(0, text);
      _controller.clear();
    });
    _save();
  }

  void _remove(int i) {
    setState(() => _items.removeAt(i));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Agregar actividad', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Ej: Martes 19:00 - Shakubuku / Reunión / Visita',
                  ),
                  onSubmitted: (_) => _add(),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Agregar'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Text(
              'Tu agenda está vacía.\nSumá tus actividades de práctica acá.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w600),
            ),
          )
        else
          ...List.generate(_items.length, (i) {
            return Card(
              child: ListTile(
                leading: Icon(Icons.event_note_rounded, color: Theme.of(context).colorScheme.secondary),
                title: Text(_items[i], style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _remove(i),
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// ===============================
///  MI APOYO
/// ===============================
class MiApoyoPage extends StatelessWidget {
  const MiApoyoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Acá después metemos: videos, guías cortas, qué es Gohonzon, qué es Gongyo, cómo es la práctica diaria, etc.',
                    style: TextStyle(fontWeight: FontWeight.w700, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _supportTile(context, '¿Qué es el Gohonzon?', Icons.emoji_objects_rounded),
        _supportTile(context, '¿Qué es Gongyo?', Icons.self_improvement_rounded),
        _supportTile(context, 'Cómo hacer la práctica diaria', Icons.check_circle_rounded),
        _supportTile(context, 'Videos de aliento', Icons.play_circle_rounded),
      ],
    );
  }

  Widget _supportTile(BuildContext context, String title, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          'Placeholder (lo armamos después).',
          style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}



