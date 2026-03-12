import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  // 1. Zablokowanie stacyjki (wymagane przy asynchronicznym starcie przed runApp)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Podanie napięcia z chmury Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. Rozruch silnika interfejsu
  runApp(const PowerliftingApp());
}

class PowerliftingApp extends StatelessWidget {
  const PowerliftingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Powerlifting MVP',
      theme: ThemeData.dark(useMaterial3: true),
      home: const MainLayout(),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  // ZWORKA SERWISOWA: Zmień na false, żeby przetestować widok zwykłego usera
  bool isModerator = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Powerlifting MVP'), centerTitle: true),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.redAccent),
              child: Text(
                'Menu Główne',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
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
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [UpcomingEventsScreen(), CalendarScreen()],
      ),
      // LOGIKA WYZWALACZA: Plusik pojawia się tylko w kalendarzu (index 1) i tylko dla moderatora
      floatingActionButton: (_currentIndex == 1 && isModerator)
          ? FloatingActionButton(
              onPressed: () {
                // Wyzwolenie sygnału - wysunięcie dolnego panelu
                showModalBottomSheet(
                  context: context,
                  isScrollControlled:
                      true, // Pozwala na przesunięcie nad klawiaturę
                  builder: (context) => Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(
                        context,
                      ).viewInsets.bottom, // Kompensacja klawiatury
                      left: 16,
                      right: 16,
                      top: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Dodaj nowe zawody',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const TextField(
                          decoration: InputDecoration(
                            labelText: 'Nazwa zawodów',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const TextField(
                          decoration: InputDecoration(
                            labelText: 'Data (np. 20.04.2026)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const TextField(
                          decoration: InputDecoration(
                            labelText: 'Lokalizacja (Miasto / Obiekt)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const TextField(
                          decoration: InputDecoration(
                            labelText: 'Godziny ważenia',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Wpisowe (PLN)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            // Tu zrobimy twardy zapis do bazy Firebase
                            Navigator.pop(
                              context,
                            ); // Zamknięcie panelu po kliknięciu
                          },
                          child: const Text(
                            'Zapisz do bazy',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}

class UpcomingEventsScreen extends StatelessWidget {
  const UpcomingEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: ListTile(
            title: Text('Mistrzostwa Polski - Warszawa'),
            subtitle: Text('20.04.2026'),
          ),
        ),
        Card(
          child: ListTile(
            title: Text('Puchar Śląska - Katowice'),
            subtitle: Text('15.06.2026'),
          ),
        ),
      ],
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final Map<DateTime, List<String>> _events = {
    DateTime.utc(2026, 4, 20): ['Mistrzostwa Polski - Warszawa'],
    DateTime.utc(2026, 6, 15): ['Puchar Śląska - Katowice'],
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TableCalendar(
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
          eventLoader: (day) => _events[day] ?? [],
          calendarStyle: const CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: Colors.yellowAccent,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const Divider(),
        Expanded(child: _buildEventList()),
      ],
    );
  }

  Widget _buildEventList() {
    final events = _events[_selectedDay ?? DateTime.now()] ?? [];
    if (events.isEmpty)
      return const Center(child: Text('Brak zawodów w tym dniu'));

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(events[index]),
            subtitle: const Text('Kliknij, aby zobaczyć szczegóły'),
            trailing: const Icon(Icons.info_outline, color: Colors.blueAccent),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(events[index]),
                  content: const Text(
                    'Szczegóły zawodów.\n\n'
                    'Tutaj docelowo zaciągniemy z Firebase twarde dane: \n'
                    '- Miejsce i godziny ważenia\n'
                    '- Wpisowe\n'
                    '- Link do regulaminu\n'
                    '- Kategoria wagowa',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Zamknij'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
