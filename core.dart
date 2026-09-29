import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ---------- THEME ----------
class C {
  static const bg = Color(0xFFFAF8F3);
  static const primary = Color(0xFF5FA36B);
  static const forest = Color(0xFF1F4D33);
  static const card = Color(0xFFE9F3E8);
  static const earth = Color(0xFF8A7A5C);
  static const warn = Color(0xFFC77D2E);
}

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: C.primary, primary: C.primary, surface: C.bg),
      scaffoldBackgroundColor: C.bg,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: C.forest),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: C.forest),
        bodyMedium: TextStyle(fontSize: 16, color: Color(0xFF33413A)),
      ),
      appBarTheme: const AppBarTheme(
          backgroundColor: C.bg, elevation: 0, foregroundColor: C.forest,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.forest)),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56), backgroundColor: C.forest,
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
    );

// ---------- MODELS ----------
class Classification {
  final String material;
  final double confidence;
  Classification(this.material, this.confidence);
  factory Classification.fromJson(Map<String, dynamic> j) =>
      Classification(j['material'], (j['confidence'] as num).toDouble());
}

class PriceQuote {
  final double low, high;
  final String band, location;
  PriceQuote(this.low, this.high, this.band, this.location);
  factory PriceQuote.fromJson(Map<String, dynamic> j) =>
      PriceQuote((j['low'] as num).toDouble(), (j['high'] as num).toDouble(), j['band'], j['location']);
  String get range => '₹${low.round()} – ₹${high.round()}';
}

class PriceRow {
  final String material, location, updated;
  final double rate, min, max;
  PriceRow(this.material, this.rate, this.min, this.max, this.location, this.updated);
}

enum LotStatus { available, offerReceived, handoverPending, completed }

class Lot {
  final String id, material, location;
  final double weight;
  final String? photoPath;
  final PriceQuote? quote;
  final DateTime createdAt;
  final bool synced; // false while only in local storage
  LotStatus status;
  Lot({required this.id, required this.material, required this.weight, required this.location,
      this.photoPath, this.quote, this.synced = false, this.status = LotStatus.available})
      : createdAt = DateTime.now();
}

class Earning {
  final String material, recycler, status;
  final double amount;
  final DateTime date;
  Earning(this.material, this.recycler, this.amount, this.status, this.date);
}

const materials = ['PCB', 'Cable', 'Battery', 'LCD / Display', 'CRT', 'Motor', 'Magnet Assembly', 'Mixed Plastic/Metal', 'Other'];

// ---------- SERVICE INTERFACES (what the backend must provide) ----------
abstract class ClassifierService {
  Future<Classification> classify(String imagePath); // POST /ai/classify -> PyTorch MobileNetV3-Small
}

abstract class PricingService {
  Future<PriceQuote> estimate(String material, double kg, String location); // POST /ai/price -> XGBoost
}

abstract class PriceBoardService {
  Future<List<PriceRow>> prices(); // GET /prices
}

abstract class EarningsService {
  Future<List<Earning>> earnings(); // GET /earnings
}

// ---------- REAL API (FastAPI) ----------
class ApiConfig {
  static String baseUrl = 'http://10.0.2.2:8000'; // set your FastAPI host
  static String? token; // Firebase ID token
  static Map<String, String> get headers => {if (token != null) 'Authorization': 'Bearer $token'};
}

class ApiClassifier implements ClassifierService {
  @override
  Future<Classification> classify(String path) async {
    final req = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/ai/classify'))
      ..headers.addAll(ApiConfig.headers)
      ..files.add(await http.MultipartFile.fromPath('image', path));
    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200) throw Exception('Classification failed (${res.statusCode})');
    return Classification.fromJson(jsonDecode(res.body));
  }
}

class ApiPricing implements PricingService {
  @override
  Future<PriceQuote> estimate(String m, double kg, String loc) async {
    final res = await http.post(Uri.parse('${ApiConfig.baseUrl}/ai/price'),
        headers: {...ApiConfig.headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'material': m, 'weight_kg': kg, 'location': loc}));
    if (res.statusCode != 200) throw Exception('Price estimate failed (${res.statusCode})');
    return PriceQuote.fromJson(jsonDecode(res.body));
  }
}

class ApiPriceBoard implements PriceBoardService {
  @override
  Future<List<PriceRow>> prices() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/prices'), headers: ApiConfig.headers);
    if (res.statusCode != 200) throw Exception('Could not load prices');
    return (jsonDecode(res.body) as List)
        .map((j) => PriceRow(j['material'], (j['rate'] as num).toDouble(), (j['min'] as num).toDouble(),
            (j['max'] as num).toDouble(), j['location'], j['updated']))
        .toList();
  }
}

// ---------- MOCK SERVICES (development only; not real ML or real prices) ----------
class MockClassifier implements ClassifierService {
  @override
  Future<Classification> classify(String path) async {
    await Future.delayed(const Duration(seconds: 2));
    return Classification(materials[Random().nextInt(5)], 0.7 + Random().nextDouble() * 0.25);
  }
}

class MockPricing implements PricingService {
  @override
  Future<PriceQuote> estimate(String m, double kg, String loc) async {
    await Future.delayed(const Duration(milliseconds: 900));
    final base = 150.0 + (m.length * 12); // placeholder only
    return PriceQuote(base * kg * 0.9, base * kg * 1.1, 'Mock band', loc);
  }
}

class MockPriceBoard implements PriceBoardService {
  @override
  Future<List<PriceRow>> prices() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      for (final m in ['PCB', 'Cable', 'Battery', 'LCD / Display', 'CRT', 'Motor', 'Magnet Assembly', 'Mixed Plastic/Metal'])
        PriceRow(m, 100.0 + m.length * 15, 90.0 + m.length * 13, 115.0 + m.length * 17, 'Panvel', 'Mock data')
    ];
  }
}

class MockEarnings implements EarningsService {
  @override
  Future<List<Earning>> earnings() async => [];
}

// ---------- SERVICE LOCATOR: flip useMock to false to connect FastAPI ----------
class Services {
  static const useMock = true;
  static final ClassifierService classifier = useMock ? MockClassifier() : ApiClassifier();
  static final PricingService pricing = useMock ? MockPricing() : ApiPricing();
  static final PriceBoardService priceBoard = useMock ? MockPriceBoard() : ApiPriceBoard();
  static final EarningsService earnings = MockEarnings();
}

// ---------- SIMPLE LOCAL STATE (swap for SQLite repository later) ----------
class LotStore extends ChangeNotifier {
  final List<Lot> lots = [];
  void add(Lot l) { lots.insert(0, l); notifyListeners(); }
  static String newId() => 'LOT-2026-MH04-${1000 + Random().nextInt(9000)}';
}

final lotStore = LotStore();
final langNotifier = ValueNotifier<String>('en');

const _t = {
  'en': {'add': 'Add E-Waste', 'prices': 'Check Prices', 'lots': 'My Lots', 'earn': 'My Earnings', 'hello': 'Namaste'},
  'hi': {'add': 'ई-कचरा जोड़ें', 'prices': 'भाव देखें', 'lots': 'मेरे लॉट', 'earn': 'मेरी कमाई', 'hello': 'नमस्ते'},
  'mr': {'add': 'ई-कचरा जोडा', 'prices': 'भाव पहा', 'lots': 'माझे लॉट', 'earn': 'माझी कमाई', 'hello': 'नमस्कार'},
};
String tr(String k) => _t[langNotifier.value]![k] ?? k;
