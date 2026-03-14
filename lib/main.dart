import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';

// ============================================================================
// GLOBALNE ZWORKI I REJESTRY PAMIĘCI
// ============================================================================
bool isModeratorGlobal = false; // Twardo wyłączony, zasila go tylko chmura
final Set<String> favoritesGlobal = {};
final Set<String> notificationsGlobal = {};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('pl_PL', null);
  runApp(const PowerliftingApp());
}

class PowerliftingApp extends StatelessWidget {
  const PowerliftingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Powerlifting MVP',
      theme: ThemeData.dark(
        useMaterial3: true,
      ).copyWith(primaryColor: Colors.redAccent),
      home: const MainLayout(),
    );
  }
}

// ============================================================================
// MODUŁ ZASILANIA: EKRAN LOGOWANIA
// ============================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  String _errorMessage = '';

  String _translateError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Nie znaleziono użytkownika z tym adresem e-mail.';
      case 'wrong-password':
        return 'Błędne hasło.';
      case 'invalid-credential':
        return 'Nieprawidłowe dane logowania.';
      case 'missing-email':
        return 'Wpisz adres e-mail.';
      case 'missing-password':
        return 'Wpisz hasło.';
      case 'invalid-email':
        return 'Niepoprawny format adresu e-mail.';
      case 'channel-error':
        return 'Wypełnij wszystkie pola.';
      default:
        return 'Wystąpił błąd logowania ($code).';
    }
  }

  Future<void> _login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _translateError(e.code));
    }
  }

  void _openRegistrationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const RegisterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Autoryzacja')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.fitness_center, size: 80, color: Colors.redAccent),
            const SizedBox(height: 32),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Adres E-mail',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Hasło',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _login,
              child: const Text(
                'ZALOGUJ',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),

            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            const Text(
              "Nie masz jeszcze konta?",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),

            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.redAccent),
              ),
              onPressed: _openRegistrationSheet,
              child: const Text(
                'ZAREJESTRUJ SIĘ',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MODUŁ REJESTRACJI (WYSUWANY) Z ANALIZATOREM HASŁA
// ============================================================================
class RegisterSheet extends StatefulWidget {
  const RegisterSheet({super.key});
  @override
  State<RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends State<RegisterSheet> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _repeatPassCtrl = TextEditingController();

  String _errorMessage = '';
  double _passwordStrength = 0.0;
  Color _strengthColor = Colors.redAccent;

  void _analyzePassword(String value) {
    double strength = 0.0;
    if (value.isNotEmpty) {
      if (value.length >= 6) strength += 0.3;
      if (value.length >= 8) strength += 0.2;
      if (RegExp(r'[A-Z]').hasMatch(value)) strength += 0.25;
      if (RegExp(r'[0-9]').hasMatch(value)) strength += 0.25;
    }
    setState(() {
      _passwordStrength = strength;
      if (strength < 0.5)
        _strengthColor = Colors.redAccent;
      else if (strength < 0.8)
        _strengthColor = Colors.orange;
      else
        _strengthColor = Colors.green;
    });
  }

  Future<void> _register() async {
    if (_passCtrl.text != _repeatPassCtrl.text) {
      setState(() => _errorMessage = 'Hasła nie są identyczne.');
      return;
    }
    if (_passwordStrength < 0.5) {
      setState(
        () => _errorMessage = 'Hasło jest zbyt słabe. Użyj min. 6 znaków.',
      );
      return;
    }

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'email-already-in-use')
          _errorMessage = 'Konto z tym e-mailem już istnieje.';
        else if (e.code == 'invalid-email')
          _errorMessage = 'Niepoprawny format adresu e-mail.';
        else
          _errorMessage = e.message ?? 'Błąd rejestracji.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Utwórz nowe konto",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Adres E-mail',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              onChanged: _analyzePassword,
              decoration: const InputDecoration(
                labelText: 'Hasło',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _passwordStrength,
              backgroundColor: Colors.grey.shade800,
              color: _strengthColor,
              minHeight: 6,
            ),
            const SizedBox(height: 4),
            const Text(
              "Zalecane: min. 8 znaków, wielka litera i cyfra.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _repeatPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Powtórz Hasło',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_clock),
              ),
            ),
            const SizedBox(height: 24),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _register,
              child: const Text(
                'ZAREJESTRUJ SIĘ',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GŁÓWNY UKŁAD I MENU (Z AUTOMATYCZNYM ADMINEM I SYNCEM ULUBIONYCH)
// ============================================================================
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        // Odcięcie przekaźnika admina przy wylogowaniu
        if (user == null) {
          isModeratorGlobal = false;
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: user != null
              ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots()
              : const Stream.empty(),
          builder: (context, userSnapshot) {
            bool isAdmin = false;
            String userName = "Zawodnik";

            if (userSnapshot.hasData &&
                userSnapshot.data != null &&
                userSnapshot.data!.exists) {
              final data = userSnapshot.data!.data() as Map<String, dynamic>?;
              isAdmin = data?['isAdmin'] == true;
              userName = data?['name'] ?? "Zawodnik";

              // Ciche zaciągnięcie Ulubionych z chmury do RAMu
              if (data?['favorites'] != null) {
                favoritesGlobal.clear();
                favoritesGlobal.addAll(List<String>.from(data!['favorites']));
              }
            }

            // Twarde połączenie pinu
            isModeratorGlobal = isAdmin;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Powerlifting MVP'),
                centerTitle: true,
              ),
              drawer: Drawer(
                child: Column(
                  children: [
                    if (user != null)
                      UserAccountsDrawerHeader(
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                        ),
                        accountName: Text(
                          userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        accountEmail: Text(user.email ?? "Brak maila"),
                        currentAccountPicture: const CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.redAccent,
                          ),
                        ),
                        onDetailsPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        color: Colors.grey.shade900,
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 16,
                          bottom: 16,
                          left: 16,
                          right: 16,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey,
                              child: Icon(
                                Icons.person_outline,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "Gość",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.login, size: 16),
                              label: const Text(
                                "Logowanie",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.fitness_center),
                            title: const Text('Nadchodzące zawody'),
                            selected: _currentIndex == 0,
                            onTap: () {
                              setState(() => _currentIndex = 0);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.calendar_month),
                            title: const Text('Kalendarz zawodów'),
                            selected: _currentIndex == 1,
                            onTap: () {
                              setState(() => _currentIndex = 1);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.star),
                            title: const Text('Ulubione'),
                            selected: _currentIndex == 2,
                            onTap: () {
                              setState(() => _currentIndex = 2);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.emoji_events),
                            title: const Text('Ranking'),
                            selected: _currentIndex == 3,
                            onTap: () {
                              setState(() => _currentIndex = 3);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(),

                    if (user != null)
                      ListTile(
                        leading: const Icon(
                          Icons.logout,
                          color: Colors.redAccent,
                        ),
                        title: const Text(
                          'Wyloguj',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                        onTap: () {
                          FirebaseAuth.instance.signOut();
                          setState(
                            () => favoritesGlobal.clear(),
                          ); // Czyszczenie cache po wylogowaniu
                        },
                      ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                  ],
                ),
              ),
              body: IndexedStack(
                index: _currentIndex,
                children: const [
                  UpcomingEventsScreen(),
                  CalendarScreen(),
                  FavoritesScreen(),
                  RankingScreen(),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// EKRAN PROFILU ZAWODNIKA
// ============================================================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _squatCtrl = TextEditingController();
  final TextEditingController _benchCtrl = TextEditingController();
  final TextEditingController _deadliftCtrl = TextEditingController();

  String _selectedFlag = '🇵🇱 Polska';
  final List<String> _flags = [
    '🇵🇱 Polska',
    '🇺🇸 USA',
    '🇬🇧 UK',
    '🇩🇪 Niemcy',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _nameCtrl.text = data['name'] ?? '';
        _ageCtrl.text = data['age'] ?? '';
        _heightCtrl.text = data['height'] ?? '';
        _weightCtrl.text = data['weight'] ?? '';
        if (data['flag'] != null && _flags.contains(data['flag']))
          _selectedFlag = data['flag'];
        if (data['records'] != null) {
          _squatCtrl.text = data['records']['squat'] ?? '';
          _benchCtrl.text = data['records']['bench'] ?? '';
          _deadliftCtrl.text = data['records']['deadlift'] ?? '';
        }
      });
    }
  }

  void _saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'name': _nameCtrl.text,
      'age': _ageCtrl.text,
      'height': _heightCtrl.text,
      'weight': _weightCtrl.text,
      'flag': _selectedFlag,
      'records': {
        'squat': _squatCtrl.text,
        'bench': _benchCtrl.text,
        'deadlift': _deadliftCtrl.text,
      },
    }, SetOptions(merge: true));

    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil zaktualizowany!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Twój Profil")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, size: 60, color: Colors.redAccent),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Imię',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Wiek',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _heightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Wzrost (cm)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _weightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Waga (kg)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedFlag,
              decoration: const InputDecoration(
                labelText: 'Reprezentacja',
                border: OutlineInputBorder(),
              ),
              items: _flags
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedFlag = val!),
            ),
            const SizedBox(height: 32),
            const Text(
              "REKORDY ŻYCIOWE (PR)",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _squatCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Przysiad (kg)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.fitness_center),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _benchCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Wyciskanie (kg)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.airline_seat_flat),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _deadliftCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Martwy Ciąg (kg)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vertical_align_top),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _saveProfile,
              child: const Text(
                'ZAPISZ PROFIL DO CHMURY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FUNKCJE POMOCNICZE
// ============================================================================
Future<void> _launchSafeUrl(String? urlString) async {
  if (urlString == null || urlString.isEmpty) return;
  final url = Uri.parse(urlString);
  if (await canLaunchUrl(url)) await launchUrl(url);
}

// ============================================================================
// WSPÓŁDZIELONY MODUŁ SZCZEGÓŁÓW
// ============================================================================
void showCompetitionDetailsDialog(
  BuildContext context,
  Map<String, dynamic> data,
  String docId,
) {
  final DateTime date = (data['date'] as Timestamp).toDate();
  final DateTime? deadline = data['registration_deadline'] != null
      ? (data['registration_deadline'] as Timestamp).toDate()
      : null;
  final List<dynamic> times = data['weighing_hours'] ?? [];
  final String fee = data['entry_fee']?.toString() ?? '0';
  final String currency = data['currency'] ?? 'PLN';
  final String dateStr =
      "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
  final String deadlineStr = deadline != null
      ? "${deadline.day.toString().padLeft(2, '0')}-${deadline.month.toString().padLeft(2, '0')}-${deadline.year}"
      : "Brak danych";

  final bool isManuallyOpen = data['registration_open'] ?? true;
  bool isRegistrationActive = isManuallyOpen;
  if (date.isBefore(DateTime.now())) isRegistrationActive = false;
  if (deadline != null &&
      DateTime.now().isAfter(deadline.add(const Duration(days: 1))))
    isRegistrationActive = false;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        data['title'] ?? 'Szczegóły zawodów',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isModeratorGlobal)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => CompetitionFormSheet(
                          docId: docId,
                          existingData: data,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.edit,
                      color: Colors.blueAccent,
                      size: 18,
                    ),
                    label: const Text(
                      "EDYTUJ",
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('competitions')
                          .doc(docId)
                          .delete();
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.delete_forever,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    label: const Text(
                      "USUŃ",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            const Divider(),
            _detailRow(Icons.calendar_today, "Data: $dateStr"),
            _detailRow(Icons.event_busy, "Zapisy do: $deadlineStr"),
            _detailRow(
              Icons.location_on,
              "Lokalizacja: ${data['location'] ?? 'Brak danych'}",
            ),
            _detailRow(
              Icons.emoji_events,
              "Federacja: ${data['federation'] ?? 'Brak danych'}",
            ),
            _detailRow(
              Icons.access_time,
              "Godziny ważenia:\n${times.isNotEmpty ? times.join('\n') : 'Brak danych'}",
            ),
            _detailRow(Icons.payments, "Wpisowe: $fee $currency"),
            const Divider(),
            if ((data['info_url'] != null &&
                    data['info_url'].toString().isNotEmpty) ||
                (data['rules_url'] != null &&
                    data['rules_url'].toString().isNotEmpty))
              Row(
                children: [
                  if (data['info_url'] != null &&
                      data['info_url'].toString().isNotEmpty)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _launchSafeUrl(data['info_url']),
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text("INFO"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                        ),
                      ),
                    ),
                  if ((data['info_url'] != null &&
                          data['info_url'].toString().isNotEmpty) &&
                      (data['rules_url'] != null &&
                          data['rules_url'].toString().isNotEmpty))
                    const SizedBox(width: 8),
                  if (data['rules_url'] != null &&
                      data['rules_url'].toString().isNotEmpty)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _launchSafeUrl(data['rules_url']),
                        icon: const Icon(Icons.gavel, size: 18),
                        label: const Text("REGULAMIN"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            if (data['registration_url'] != null &&
                data['registration_url'].toString().isNotEmpty)
              Center(
                child: ElevatedButton.icon(
                  onPressed: isRegistrationActive
                      ? () => _launchSafeUrl(data['registration_url'])
                      : null,
                  icon: const Icon(Icons.how_to_reg),
                  label: Text(
                    isRegistrationActive ? "ZAPISZ SIĘ" : "ZAPISY ZAMKNIĘTE",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.grey.shade800,
                    disabledForegroundColor: Colors.grey.shade500,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("ZAMKNIJ"),
        ),
      ],
    ),
  );
}

Widget _detailRow(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.redAccent),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    ),
  );
}

Widget buildLegend(BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12.0),
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      border: const Border(bottom: BorderSide(color: Colors.white24, width: 1)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.circle, color: Colors.green, size: 14),
        SizedBox(width: 6),
        Text(
          "Zapisy otwarte",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        SizedBox(width: 16),
        Icon(Icons.circle, color: Colors.redAccent, size: 14),
        SizedBox(width: 6),
        Text(
          "Zapisy zamknięte",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

// ============================================================================
// MULTIMODUŁ: FORMULARZ DODAWANIA I EDYCJI ZAWODÓW
// ============================================================================
class CompetitionFormSheet extends StatefulWidget {
  final DateTime? preselectedDate;
  final String? docId;
  final Map<String, dynamic>? existingData;

  const CompetitionFormSheet({
    super.key,
    this.preselectedDate,
    this.docId,
    this.existingData,
  });
  @override
  State<CompetitionFormSheet> createState() => _CompetitionFormSheetState();
}

class _CompetitionFormSheetState extends State<CompetitionFormSheet> {
  late DateTime _eventDate;
  DateTime? _deadlineDate;
  bool _isRegistrationOpen = true;

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _federationCtrl = TextEditingController();
  final TextEditingController _feeCtrl = TextEditingController();
  final TextEditingController _regUrlCtrl = TextEditingController();
  final TextEditingController _infoUrlCtrl = TextEditingController();
  final TextEditingController _rulesUrlCtrl = TextEditingController();

  List<TimeOfDay> _weighingTimes = [const TimeOfDay(hour: 8, minute: 0)];
  String _selectedCurrency = 'PLN';
  final List<String> _currencies = ['PLN', 'EUR', 'USD'];

  @override
  void initState() {
    super.initState();
    _eventDate = widget.preselectedDate ?? DateTime.now();

    if (widget.existingData != null) {
      final data = widget.existingData!;
      _eventDate = (data['date'] as Timestamp).toDate();
      _deadlineDate = data['registration_deadline'] != null
          ? (data['registration_deadline'] as Timestamp).toDate()
          : null;
      _isRegistrationOpen = data['registration_open'] ?? true;
      _titleCtrl.text = data['title'] ?? '';
      _locationCtrl.text = data['location'] ?? '';
      _federationCtrl.text = data['federation'] ?? '';
      _feeCtrl.text = data['entry_fee']?.toString() ?? '';
      _regUrlCtrl.text = data['registration_url'] ?? '';
      _infoUrlCtrl.text = data['info_url'] ?? '';
      _rulesUrlCtrl.text = data['rules_url'] ?? '';
      _selectedCurrency = data['currency'] ?? 'PLN';
      if (data['weighing_hours'] != null) {
        List<dynamic> hours = data['weighing_hours'];
        if (hours.isNotEmpty)
          _weighingTimes = hours.map((h) {
            final parts = h.toString().split(':');
            return TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }).toList();
      }
    }
  }

  Future<void> _pickDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deadlineDate ?? _eventDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: "Wybierz datę końca zapisów",
    );
    if (picked != null) setState(() => _deadlineDate = picked);
  }

  void _saveData() async {
    if (_titleCtrl.text.isEmpty) return;
    List<String> timesFormatted = _weighingTimes
        .map(
          (t) =>
              "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}",
        )
        .toList();
    Map<String, dynamic> payload = {
      'title': _titleCtrl.text,
      'location': _locationCtrl.text,
      'federation': _federationCtrl.text,
      'date': Timestamp.fromDate(_eventDate),
      'registration_deadline': _deadlineDate != null
          ? Timestamp.fromDate(_deadlineDate!)
          : null,
      'weighing_hours': timesFormatted,
      'entry_fee': double.tryParse(_feeCtrl.text) ?? 0.0,
      'currency': _selectedCurrency,
      'registration_url': _regUrlCtrl.text,
      'info_url': _infoUrlCtrl.text,
      'rules_url': _rulesUrlCtrl.text,
      'registration_open': _isRegistrationOpen,
    };
    if (widget.docId == null)
      await FirebaseFirestore.instance.collection('competitions').add(payload);
    else
      await FirebaseFirestore.instance
          .collection('competitions')
          .doc(widget.docId)
          .update(payload);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.docId == null ? 'Nowe Zawody' : 'Edytuj Zawody',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Data zawodów: ${_eventDate.day}-${_eventDate.month}-${_eventDate.year}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Nazwa zawodów',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDeadline,
              icon: const Icon(Icons.event_busy),
              label: Text(
                _deadlineDate == null
                    ? "Ustaw datę końca zapisów"
                    : "Zapisy do: ${_deadlineDate!.day}-${_deadlineDate!.month}-${_deadlineDate!.year}",
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                "Zapisy otwarte",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                "Wyłącz, jeśli wyczerpały się miejsca przed czasem",
              ),
              value: _isRegistrationOpen,
              activeColor: Colors.green,
              onChanged: (bool value) =>
                  setState(() => _isRegistrationOpen = value),
            ),
            const Divider(),
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Lokalizacja',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _federationCtrl,
              decoration: const InputDecoration(
                labelText: 'Federacja',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Godziny ważenia:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._weighingTimes.asMap().entries.map((entry) {
              int idx = entry.key;
              TimeOfDay time = entry.value;
              return Row(
                children: [
                  if (_weighingTimes.length > 1)
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () =>
                          setState(() => _weighingTimes.removeAt(idx)),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: time,
                        );
                        if (picked != null)
                          setState(() => _weighingTimes[idx] = picked);
                      },
                      child: Text(
                        "Godzina: ${time.format(context)}",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              );
            }),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Padding(
                padding: EdgeInsets.only(left: 12.0),
                child: Icon(Icons.add_circle, color: Colors.green),
              ),
              title: const Text(
                "Dodaj godzinę ważenia",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 10, minute: 0),
                  helpText: "Wybierz nową godzinę ważenia",
                );
                if (picked != null) setState(() => _weighingTimes.add(picked));
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _feeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Wpisowe',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedCurrency,
                  items: _currencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedCurrency = val!),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _regUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'Link do zapisów',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _infoUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'Link do informacji',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rulesUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'Link do regulaminu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saveData,
              child: Text(
                widget.docId == null ? 'ZAPISZ NOWE' : 'ZAPISZ ZMIANY',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EKRAN 1: KALENDARZ (Z NOWYM STEROWANIEM ULUBIONYCH)
// ============================================================================
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // FUNKCJA ZASILANIA ULUBIONYCH: Chmura dla zalogowanych, Cache dla Gościa
  void _toggleFavorite(String docId) async {
    final user = FirebaseAuth.instance.currentUser;

    // Optymistyczny UI (szybka reakcja interfejsu)
    setState(() {
      if (favoritesGlobal.contains(docId))
        favoritesGlobal.remove(docId);
      else
        favoritesGlobal.add(docId);
    });

    // Jeżeli masz profil w bazie, przekaż prąd do chmury
    if (user != null) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      if (favoritesGlobal.contains(docId)) {
        await docRef.set({
          'favorites': FieldValue.arrayUnion([docId]),
        }, SetOptions(merge: true));
      } else {
        await docRef.set({
          'favorites': FieldValue.arrayRemove([docId]),
        }, SetOptions(merge: true));
      }
    }
  }

  void _toggleNotification(String docId) {
    setState(() {
      if (notificationsGlobal.contains(docId))
        notificationsGlobal.remove(docId);
      else
        notificationsGlobal.add(docId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('competitions').snapshots(),
      builder: (context, snapshot) {
        Map<DateTime, List<QueryDocumentSnapshot>> events = {};
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final date = (doc['date'] as Timestamp).toDate();
            final key = DateTime.utc(date.year, date.month, date.day);
            if (events[key] == null) events[key] = [];
            events[key]!.add(doc);
          }
        }
        return Column(
          children: [
            buildLegend(context),
            TableCalendar(
              locale: 'pl_PL',
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              eventLoader: (day) =>
                  events[DateTime.utc(day.year, day.month, day.day)] ?? [],
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextFormatter: (date, locale) {
                  final String formatted = DateFormat.yMMMM(
                    locale,
                  ).format(date);
                  if (formatted.isEmpty) return formatted;
                  return formatted[0].toUpperCase() + formatted.substring(1);
                },
              ),
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return const SizedBox();
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: events.map((doc) {
                        final data =
                            (doc as QueryDocumentSnapshot).data()
                                as Map<String, dynamic>;
                        final bool isManuallyOpen =
                            data['registration_open'] ?? true;
                        final DateTime evDate = (data['date'] as Timestamp)
                            .toDate();
                        final DateTime? deadline =
                            data['registration_deadline'] != null
                            ? (data['registration_deadline'] as Timestamp)
                                  .toDate()
                            : null;
                        bool isRegistrationActive = isManuallyOpen;
                        if (evDate.isBefore(DateTime.now()))
                          isRegistrationActive = false;
                        if (deadline != null &&
                            DateTime.now().isAfter(
                              deadline.add(const Duration(days: 1)),
                            ))
                          isRegistrationActive = false;
                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 1.5,
                            vertical: 6,
                          ),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isRegistrationActive
                                ? Colors.green
                                : Colors.redAccent,
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            if (_selectedDay != null) ...[
              if (isModeratorGlobal)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) =>
                            CompetitionFormSheet(preselectedDate: _selectedDay),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Dodaj zawody w tym dniu"),
                  ),
                ),
              Expanded(
                child: _buildDayEventList(
                  events[DateTime.utc(
                        _selectedDay!.year,
                        _selectedDay!.month,
                        _selectedDay!.day,
                      )] ??
                      [],
                ),
              ),
            ] else
              const Expanded(
                child: Center(child: Text("Wybierz dzień z kalendarza")),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDayEventList(List<QueryDocumentSnapshot> dayEvents) {
    if (dayEvents.isEmpty)
      return const Center(child: Text('Brak zawodów w tym dniu'));
    return ListView.builder(
      itemCount: dayEvents.length,
      itemBuilder: (context, index) {
        final doc = dayEvents[index];
        final data = doc.data() as Map<String, dynamic>;
        final bool isManuallyOpen = data['registration_open'] ?? true;
        final DateTime evDate = (data['date'] as Timestamp).toDate();
        final DateTime? deadline = data['registration_deadline'] != null
            ? (data['registration_deadline'] as Timestamp).toDate()
            : null;
        bool isRegistrationActive = isManuallyOpen;
        if (evDate.isBefore(DateTime.now())) isRegistrationActive = false;
        if (deadline != null &&
            DateTime.now().isAfter(deadline.add(const Duration(days: 1))))
          isRegistrationActive = false;

        final Color titleColor = isRegistrationActive
            ? Colors.green
            : Colors.redAccent;
        final bool isFav = favoritesGlobal.contains(doc.id);
        final bool isNotif = notificationsGlobal.contains(doc.id);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            contentPadding: const EdgeInsets.only(
              left: 16,
              right: 4,
              top: 4,
              bottom: 4,
            ),
            title: Text(
              data['title'] ?? 'Zawody',
              style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
            ),
            subtitle: Text(
              "Federacja: ${data['federation'] ?? 'Brak'} | Miejsce: ${data['location'] ?? 'Brak'}",
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isFav ? Icons.star : Icons.star_border,
                    color: isFav ? Colors.amber : Colors.grey,
                  ),
                  onPressed: () => _toggleFavorite(doc.id),
                ),
                IconButton(
                  icon: Icon(
                    isNotif
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                    color: isNotif ? Colors.blueAccent : Colors.grey,
                  ),
                  onPressed: () => _toggleNotification(doc.id),
                ),
              ],
            ),
            onTap: () => showCompetitionDetailsDialog(context, data, doc.id),
          ),
        );
      },
    );
  }
}

// ============================================================================
// EKRAN 2: LISTA NADCHODZĄCYCH (Z NOWYM STEROWANIEM ULUBIONYCH)
// ============================================================================
class UpcomingEventsScreen extends StatefulWidget {
  const UpcomingEventsScreen({super.key});
  @override
  State<UpcomingEventsScreen> createState() => _UpcomingEventsScreenState();
}

class _UpcomingEventsScreenState extends State<UpcomingEventsScreen> {
  // FUNKCJA ZASILANIA ULUBIONYCH: Chmura dla zalogowanych, Cache dla Gościa
  void _toggleFavorite(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      if (favoritesGlobal.contains(docId))
        favoritesGlobal.remove(docId);
      else
        favoritesGlobal.add(docId);
    });
    if (user != null) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      if (favoritesGlobal.contains(docId)) {
        await docRef.set({
          'favorites': FieldValue.arrayUnion([docId]),
        }, SetOptions(merge: true));
      } else {
        await docRef.set({
          'favorites': FieldValue.arrayRemove([docId]),
        }, SetOptions(merge: true));
      }
    }
  }

  void _toggleNotification(String docId) {
    setState(() {
      if (notificationsGlobal.contains(docId))
        notificationsGlobal.remove(docId);
      else
        notificationsGlobal.add(docId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildLegend(context),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('competitions')
                .orderBy('date')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty)
                return const Center(child: Text('Brak zaplanowanych zawodów'));

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final date = (data['date'] as Timestamp).toDate();
                  final dateStr =
                      "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";

                  final bool isManuallyOpen = data['registration_open'] ?? true;
                  final DateTime? deadline =
                      data['registration_deadline'] != null
                      ? (data['registration_deadline'] as Timestamp).toDate()
                      : null;

                  bool isRegistrationActive = isManuallyOpen;
                  if (date.isBefore(DateTime.now()))
                    isRegistrationActive = false;
                  if (deadline != null &&
                      DateTime.now().isAfter(
                        deadline.add(const Duration(days: 1)),
                      ))
                    isRegistrationActive = false;

                  final Color statusColor = isRegistrationActive
                      ? Colors.green
                      : Colors.redAccent;
                  final bool isFav = favoritesGlobal.contains(doc.id);
                  final bool isNotif = notificationsGlobal.contains(doc.id);

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 12,
                        right: 4,
                        top: 4,
                        bottom: 4,
                      ),
                      leading: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.circle, color: statusColor, size: 20),
                        ],
                      ),
                      title: Text(
                        data['title'] ?? 'Brak nazwy',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "${data['federation'] ?? 'Brak'} | ${data['location'] ?? 'Brak'} | $dateStr",
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isFav ? Icons.star : Icons.star_border,
                              color: isFav ? Colors.amber : Colors.grey,
                            ),
                            onPressed: () => _toggleFavorite(doc.id),
                          ),
                          IconButton(
                            icon: Icon(
                              isNotif
                                  ? Icons.notifications_active
                                  : Icons.notifications_none,
                              color: isNotif ? Colors.blueAccent : Colors.grey,
                            ),
                            onPressed: () => _toggleNotification(doc.id),
                          ),
                        ],
                      ),
                      onTap: () =>
                          showCompetitionDetailsDialog(context, data, doc.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ZAŚLEPKI DLA ULUBIONYCH I RANKINGU
// ============================================================================
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Tu wylądują Ulubione Zawody",
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text("Tu będzie moduł Rankingu", style: TextStyle(fontSize: 18)),
    );
  }
}
