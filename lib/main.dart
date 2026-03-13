import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/date_symbol_data_local.dart'; // Dodany moduł językowy
import 'firebase_options.dart';

// ============================================================================
// GLOBALNE ZWORKI I REJESTRY PAMIĘCI (Współdzielone dla całej apki)
// ============================================================================
bool isModeratorGlobal = true;
final Set<String> favoritesGlobal = {};
final Set<String> notificationsGlobal = {};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting(
    'pl_PL',
    null,
  ); // Inicjalizacja polskiego kalendarza
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Powerlifting MVP'), centerTitle: true),
      drawer: Drawer(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    color: Colors.redAccent,
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 16,
                      bottom: 16,
                      left: 16,
                      right: 16,
                    ),
                    child: const Text(
                      'Menu Główne',
                      style: TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  ),
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
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Tryb Admin",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Switch(
                    value: isModeratorGlobal,
                    activeColor: Colors.redAccent,
                    onChanged: (bool value) =>
                        setState(() => isModeratorGlobal = value),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const UpcomingEventsScreen(),
          const CalendarScreen(),
          const FavoritesScreen(),
          const RankingScreen(),
        ],
      ),
    );
  }
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
  final List<dynamic> times = data['weighing_hours'] ?? [];
  final String fee = data['entry_fee']?.toString() ?? '0';
  final String currency = data['currency'] ?? 'PLN';
  final String dateStr =
      "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(data['title'] ?? 'Szczegóły zawodów'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isModeratorGlobal)
              Align(
                alignment: Alignment.topRight,
                child: TextButton.icon(
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('competitions')
                        .doc(docId)
                        .delete();
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text(
                    "USUŃ Z KALENDARZA",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            const Divider(),
            _detailRow(Icons.calendar_today, "Data: $dateStr"),
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
            if (data['registration_url'] != null &&
                data['registration_url'].toString().isNotEmpty)
              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final url = Uri.parse(data['registration_url']);
                    if (await canLaunchUrl(url)) await launchUrl(url);
                  },
                  icon: const Icon(Icons.link),
                  label: const Text("ZAPISZ SIĘ"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
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

// Współdzielona legenda dla obu ekranów
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
// EKRAN 1: KALENDARZ
// ============================================================================
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  final TextEditingController _regUrlController = TextEditingController();
  final TextEditingController _federationController = TextEditingController();

  List<TimeOfDay> _weighingTimes = [const TimeOfDay(hour: 8, minute: 0)];
  String _selectedCurrency = 'PLN';
  final List<String> _currencies = ['PLN', 'EUR', 'USD'];

  void _toggleFavorite(String docId) {
    setState(() {
      if (favoritesGlobal.contains(docId)) {
        favoritesGlobal.remove(docId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usunięto z ulubionych'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        favoritesGlobal.add(docId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dodano do ulubionych'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _toggleNotification(String docId) {
    setState(() {
      if (notificationsGlobal.contains(docId)) {
        notificationsGlobal.remove(docId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wyłączono powiadomienia'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        notificationsGlobal.add(docId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Włączono powiadomienia'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _addCompetition() async {
    if (_selectedDay == null || _titleController.text.isEmpty) return;
    List<String> timesFormatted = _weighingTimes
        .map(
          (t) =>
              "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}",
        )
        .toList();

    await FirebaseFirestore.instance.collection('competitions').add({
      'title': _titleController.text,
      'location': _locationController.text,
      'federation': _federationController.text,
      'date': Timestamp.fromDate(_selectedDay!),
      'weighing_hours': timesFormatted,
      'entry_fee': double.tryParse(_feeController.text) ?? 0.0,
      'currency': _selectedCurrency,
      'registration_url': _regUrlController.text,
      'registration_open': true,
    });

    _titleController.clear();
    _locationController.clear();
    _feeController.clear();
    _regUrlController.clear();
    _federationController.clear();
    setState(() => _weighingTimes = [const TimeOfDay(hour: 8, minute: 0)]);
    if (mounted) Navigator.pop(context);
  }

  void _showAddModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                Text(
                  'Zawody na dzień: ${_selectedDay!.day.toString().padLeft(2, '0')}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.year}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
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
                    labelText: 'Federacja',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Godziny ważenia:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ..._weighingTimes.asMap().entries.map((entry) {
                  int idx = entry.key;
                  TimeOfDay time = entry.value;
                  return Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: time,
                            );
                            if (picked != null)
                              setModalState(() => _weighingTimes[idx] = picked);
                          },
                          child: Text(
                            "Godzina: ${time.format(context)}",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      if (idx == _weighingTimes.length - 1)
                        IconButton(
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          onPressed: () => setModalState(
                            () => _weighingTimes.add(
                              const TimeOfDay(hour: 10, minute: 0),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _feeController,
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
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => _selectedCurrency = val!),
                    ),
                  ],
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
                  onPressed: _addCompetition,
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
      ),
    );
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
            buildLegend(context), // Legenda wstrzyknięta nad kalendarz
            TableCalendar(
              locale: 'pl_PL', // Polska paczka językowa
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
              headerStyle: const HeaderStyle(
                formatButtonVisible: false, // Odcięty przycisk 2 weeks
                titleCentered: true,
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
              // CUSTOMOWE LUTOWANIE KROPEK W KALENDARZU
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
                        final evDate = (data['date'] as Timestamp).toDate();
                        final isOpen = data['registration_open'] ?? false;
                        final isPast = evDate.isBefore(DateTime.now());
                        final color = (isOpen && !isPast)
                            ? Colors.green
                            : Colors.redAccent;
                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 1.5,
                            vertical: 6,
                          ),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
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
                    onPressed: _showAddModal,
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("Federacja: ${data['federation'] ?? 'Brak'}"),
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
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.redAccent),
                  onPressed: () =>
                      showCompetitionDetailsDialog(context, data, doc.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// EKRAN 2: LISTA NADCHODZĄCYCH
// ============================================================================
class UpcomingEventsScreen extends StatefulWidget {
  const UpcomingEventsScreen({super.key});
  @override
  State<UpcomingEventsScreen> createState() => _UpcomingEventsScreenState();
}

class _UpcomingEventsScreenState extends State<UpcomingEventsScreen> {
  void _toggleFavorite(String docId) {
    setState(() {
      if (favoritesGlobal.contains(docId)) {
        favoritesGlobal.remove(docId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usunięto z ulubionych'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        favoritesGlobal.add(docId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dodano do ulubionych'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _toggleNotification(String docId) {
    setState(() {
      if (notificationsGlobal.contains(docId)) {
        notificationsGlobal.remove(docId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wyłączono powiadomienia'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        notificationsGlobal.add(docId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Włączono powiadomienia'),
            duration: Duration(seconds: 2),
          ),
        );
      }
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
                  final bool isOpen = data['registration_open'] ?? false;
                  final bool isPast = date.isBefore(DateTime.now());
                  final Color statusColor = (isOpen && !isPast)
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
