import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  // 1. Zablokowanie stacyjki przed asynchronicznym startem
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Podanie napięcia z chmury Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. Rozruch silnika
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

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  bool isModerator = true; // ZWORKA SERWISOWA: Tymczasowy dostęp admina

  // MAGISTRALA KONTROLERÓW (Piny wejściowe formularza)
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _federationController = TextEditingController();
  final TextEditingController _weighingController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  final TextEditingController _regUrlController = TextEditingController();

  // FUNKCJA ZAPISU (Transfer danych do chmury)
  Future<void> _saveToFirebase() async {
    try {
      if (_titleController.text.isEmpty || _dateController.text.isEmpty) return;

      // Konwersja formatu daty (obsługuje RRRR-MM-DD lub RRRR.MM.DD)
      String formattedDate = _dateController.text.replaceAll('.', '-');
      DateTime parsedDate = DateTime.parse(formattedDate);

      await FirebaseFirestore.instance.collection('competitions').add({
        'title': _titleController.text,
        'date': Timestamp.fromDate(parsedDate),
        'location': _locationController.text,
        'federation': _federationController.text,
        'weighing_hours': _weighingController.text,
        'entry_fee': double.tryParse(_feeController.text) ?? 0.0,
        'registration_url': _regUrlController.text,
        'registration_open': true, // Domyślnie otwarte
      });

      // Czyszczenie styków po udanym zapisie
      _titleController.clear();
      _dateController.clear();
      _locationController.clear();
      _federationController.clear();
      _weighingController.clear();
      _feeController.clear();
      _regUrlController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zapisano pomyślnie w bazie Zero Bytes!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('BŁĄD ZAPISU: Sprawdź format daty (RRRR-MM-DD)'),
          ),
        );
      }
    }
  }

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
      floatingActionButton: (_currentIndex == 1 && isModerator)
          ? FloatingActionButton(
              backgroundColor: Colors.redAccent,
              onPressed: () => _showAddDialog(context),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Dodaj nowe zawody',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Nazwa zawodów',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Data (RRRR-MM-DD)',
                  border: OutlineInputBorder(),
                  hintText: '2026-04-20',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Lokalizacja',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _federationController,
                decoration: const InputDecoration(
                  labelText: 'Federacja (np. WRPF, IPF)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _weighingController,
                decoration: const InputDecoration(
                  labelText: 'Godziny ważenia',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _feeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Wpisowe (PLN)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _regUrlController,
                decoration: const InputDecoration(
                  labelText: 'Link do zapisów',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  _saveToFirebase();
                  Navigator.pop(context);
                },
                child: const Text(
                  'Zapisz do bazy',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// EKRAN 1: LISTA (Nadchodzące zawody)
class UpcomingEventsScreen extends StatelessWidget {
  const UpcomingEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('competitions')
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text('Błąd połączenia z bazą'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return const Center(child: Text('Brak zawodów w bazie'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final DateTime date = (data['date'] as Timestamp).toDate();
            final bool isOpen = data['registration_open'] ?? false;
            final bool isPast = date.isBefore(DateTime.now());

            Color statusColor = isPast
                ? Colors.red
                : (isOpen ? Colors.green : Colors.orange);

            return Card(
              child: ListTile(
                leading: Icon(Icons.circle, color: statusColor),
                title: Text(data['title'] ?? 'Brak nazwy'),
                subtitle: Text(
                  "${data['location'] ?? 'Brak lokalizacji'} | ${date.day}.${date.month}.${date.year}",
                ),
                trailing: const Icon(Icons.info_outline),
                onTap: () => _showDetails(context, data, date, statusColor),
              ),
            );
          },
        );
      },
    );
  }

  void _showDetails(
    BuildContext context,
    Map<String, dynamic> data,
    DateTime date,
    Color statusColor,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['title'] ?? 'Szczegóły'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Data: ${date.day}.${date.month}.${date.year}'),
              Text('Federacja: ${data['federation'] ?? 'N/A'}'),
              Text('Lokalizacja: ${data['location'] ?? 'N/A'}'),
              Text('Ważenie: ${data['weighing_hours'] ?? 'N/A'}'),
              Text('Wpisowe: ${data['entry_fee'] ?? '0'} PLN'),
              const Divider(),
              Text(
                'Status: ${statusColor == Colors.red ? "ZAKOŃCZONE" : (statusColor == Colors.green ? "ZAPISY OTWARTE" : "ZAPISY ZAMKNIĘTE")}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }
}

// EKRAN 2: KALENDARZ (TableCalendar)
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('competitions').snapshots(),
      builder: (context, snapshot) {
        Map<DateTime, List<Map<String, dynamic>>> events = {};

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final date = (data['date'] as Timestamp).toDate();
            final dateKey = DateTime.utc(date.year, date.month, date.day);
            if (events[dateKey] == null) events[dateKey] = [];
            events[dateKey]!.add(data);
          }
        }

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
              eventLoader: (day) =>
                  events[DateTime.utc(day.year, day.month, day.day)] ?? [],
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
            Expanded(
              child: _selectedDay == null
                  ? const Center(child: Text("Wybierz dzień z kalendarza"))
                  : _buildEventList(
                      events[DateTime.utc(
                            _selectedDay!.year,
                            _selectedDay!.month,
                            _selectedDay!.day,
                          )] ??
                          [],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEventList(List<Map<String, dynamic>> dayEvents) {
    if (dayEvents.isEmpty)
      return const Center(child: Text('Brak zawodów w tym dniu'));
    return ListView.builder(
      itemCount: dayEvents.length,
      itemBuilder: (context, index) {
        final ev = dayEvents[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(ev['title'] ?? 'Zawody'),
            subtitle: Text(ev['federation'] ?? 'Kliknij po szczegóły'),
          ),
        );
      },
    );
  }
}
