import 'package:cloud_firestore/cloud_firestore.dart';

class Competition {
  final String id;
  final String nazwa;
  final DateTime data;
  final String lokalizacja;
  final String godzinyWazenia;
  final double wpisowe;
  final String rejestracjaUrl;
  final String regulaminUrl;
  final String formuly;
  final bool zapisyOtwarte;

  Competition({
    required this.id,
    required this.nazwa,
    required this.data,
    required this.lokalizacja,
    required this.godzinyWazenia,
    required this.wpisowe,
    required this.rejestracjaUrl,
    required this.regulaminUrl,
    required this.formuly,
    required this.zapisyOtwarte,
  });

  // Metoda sterująca diodami statusu
  String get status {
    final now = DateTime.now();
    if (data.isBefore(now)) return 'ODBYTE'; // Czerwona dioda
    if (zapisyOtwarte) return 'OTWARTE'; // Zielona dioda
    return 'ZAMKNIĘTE'; // Pomarańczowa dioda
  }
}
