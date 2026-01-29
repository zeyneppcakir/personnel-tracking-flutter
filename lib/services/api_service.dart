// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/personel.dart';

class ApiService {
  // ---- Sabitler ----
  static const String baseUrl = 'https://apiv3.bilsoft.com';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Gerçek endpoint yolları (Swagger)
  static const String personelGetAllPath = '/api/Personel/getall';
  static const String personelAddPath = '/api/Personel/add';
  static const String personelGetByIdPath = '/api/Personel/getbyid';
  static const String personelDeletePath =
      '/api/Personel/delete'; // POST + {id}
  static const String personelUpdatePath = '/api/Personel/update'; // POST/PUT

  // JSON header yardımcı
  static Map<String, String> _jsonHeaders({String? token}) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // ---- Auth ----
  static Future<bool> login(String kullaniciAdi, String kullaniciSifre) async {
    final url = Uri.parse('$baseUrl/api/Auth/GirisYap');

    final body = {
      'vergiNumarasi': '49864531453',
      'kullaniciAdi': kullaniciAdi,
      'kullaniciSifre': kullaniciSifre,
      'veritabaniAd': '49864531453',
      'donemYil': '2025',
      'subeAd': 'Merkez',
      'apiKullaniciAdi': 'BLS-ab4215d9ad0a',
      'apiKullaniciSifre': '0cc38a28-f44d-4d66-a22b-0bda19fa2fa4',
    };

    final res =
        await http.post(url, headers: _jsonHeaders(), body: jsonEncode(body));

    if (res.statusCode == 200) {
      final obj = jsonDecode(res.body);
      final token = obj['data']?['token'] as String?;
      if (token != null && token.isNotEmpty) {
        await _storage.write(key: 'token', value: token);
        return true;
      }
      throw Exception('Sunucudan geçerli token gelmedi.');
    } else {
      // Sunucu mesajını göster
      try {
        final j = jsonDecode(res.body);
        final msg = (j is Map)
            ? (j['message'] ?? j['code'] ?? 'Giriş başarısız')
            : 'Giriş başarısız';
        throw Exception(msg.toString());
      } catch (_) {
        throw Exception('Giriş başarısız (${res.statusCode}).');
      }
    }
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'token');
  }

  // ---- Personel: Liste (POST /api/Personel/getall) ----
  static Future<List<Personel>> getPersoneller() async {
    final token = await _storage.read(key: 'token');
    final url = Uri.parse('$baseUrl$personelGetAllPath');

    final res = await http.post(
      url,
      headers: _jsonHeaders(token: token),
      body: jsonEncode({}), // gerekiyorsa {"subeAdi":"Merkez"}
    );

    if (res.statusCode == 200) {
      final obj = jsonDecode(res.body);

      dynamic data = obj;
      if (obj is Map<String, dynamic>) {
        data = obj['data'] ?? obj;
        if (data is Map<String, dynamic>) {
          data = data['items'] ?? data['list'] ?? [];
        }
      }
      if (data is! List) data = [];

      return (data as List)
          .map((e) => Personel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(
        'Personel listesi getirilemedi: ${res.statusCode}\n${res.body}');
  }

  // ---- Personel: Detay (GET /api/Personel/getbyid?id=) ----
  static Future<Personel> getPersonelById(int id) async {
    final token = await _storage.read(key: 'token');
    final url = Uri.parse('$baseUrl$personelGetByIdPath?id=$id');
    final res = await http.get(url, headers: _jsonHeaders(token: token));

    if (res.statusCode == 200) {
      final obj = jsonDecode(res.body);
      final data = (obj is Map<String, dynamic>) ? (obj['data'] ?? obj) : obj;
      return Personel.fromJson(data as Map<String, dynamic>);
    }
    throw Exception('Detay getirilemedi: ${res.statusCode}\n${res.body}');
  }

  // ---- Personel: Ekle (POST /api/Personel/add) ----
  static Future<int?> addPersonel({
    required String ad,
    required String soyad,
    String gorev = 'Stajyer',
    String email = '',
    String subeAdi = 'Merkez',
    String? tc,
    DateTime? isGirisTarihi,
  }) async {
    final token = await _storage.read(key: 'token');
    final url = Uri.parse('$baseUrl$personelAddPath');

    final body = <String, dynamic>{
      "pAd": ad,
      "pSoyad": soyad,
      "pGorev": gorev,
      if (email.isNotEmpty) "pIletisimEposta": email,
      if (tc != null && tc.isNotEmpty) "pTc": tc,
      if (isGirisTarihi != null)
        "pIsGiristarih": isGirisTarihi.toUtc().toIso8601String(),
      "subeAdi": subeAdi,
    };

    final res = await http.post(
      url,
      headers: _jsonHeaders(token: token),
      body: jsonEncode(body),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final j = jsonDecode(res.body);
      return (j is Map && j['data'] is Map) ? j['data']['id'] as int? : null;
    }
    throw Exception('Ekleme başarısız: ${res.statusCode}\n${res.body}');
  }

  // ---- Personel: Güncelle (POST/PUT /api/Personel/update) ----
  // Tam gövde gönderir: Önce mevcut kaydı çeker, sonra eksiksiz body ile update eder.
  // Önce POST dener, 405 gelirse PUT ile tekrar dener.
  static Future<void> updatePersonel({
    required int id,
    String? ad,
    String? soyad,
    String? gorev,
    String? email,
    String? subeAdi,
    String? tc,
  }) async {
    final token = await _storage.read(key: 'token');
    final url = Uri.parse('$baseUrl$personelUpdatePath');

    // 1) Mevcut kaydı çek (tam gövde için)
    final current = await getPersonelById(id);

    // 2) Tam ve eksiksiz body
    final body = <String, dynamic>{
      "id": id,
      "pAd": (ad ?? current.ad).trim(),
      "pSoyad": (soyad ?? current.soyad).trim(),
      "pGorev":
          (gorev ?? (current.gorev.isEmpty ? 'Stajyer' : current.gorev)).trim(),
      "pIletisimEposta": (email ?? current.eposta).trim(),
      "pTc": (tc ?? current.tc).trim(),
      "subeAdi": (subeAdi ?? 'Merkez').trim(),
    };

    // 3) Önce POST dene; 405 ise PUT dene
    http.Response res = await http.post(
      url,
      headers: _jsonHeaders(token: token),
      body: jsonEncode(body),
    );
    if (res.statusCode == 405) {
      res = await http.put(
        url,
        headers: _jsonHeaders(token: token),
        body: jsonEncode(body),
      );
    }

    if (res.statusCode != 200 &&
        res.statusCode != 201 &&
        res.statusCode != 204) {
      throw Exception('Güncelleme başarısız: ${res.statusCode}\n${res.body}');
    }

    // success:false kontrolü (varsa)
    try {
      // 204 No Content olabilir; parse etmeye çalışmadan önce kontrol et
      if (res.body.isNotEmpty) {
        final j = jsonDecode(res.body);
        if (j is Map && j['success'] == false) {
          throw Exception(
              'Güncelleme başarısız: ${j['message'] ?? j['code'] ?? 'bilinmiyor'}');
        }
      }
    } catch (_) {/* bazı cevaplar boş olabilir */}
  }

  // Esnek patch: key eşlemesi yapıp updatePersonel'e yönlendirir
  static Future<void> updatePersonelRaw(
      int id, Map<String, dynamic> patch) async {
    final mapped = <String, dynamic>{"id": id};

    void put(String key, dynamic val) {
      if (val == null) return;
      if (val is String && val.trim().isEmpty) return;
      mapped[key] = val is String ? val.trim() : val;
    }

    put('pAd', patch['pAd'] ?? patch['ad']);
    put('pSoyad', patch['pSoyad'] ?? patch['soyad']);
    put('pGorev', patch['pGorev'] ?? patch['gorev']);
    put('pIletisimEposta', patch['pIletisimEposta'] ?? patch['email']);
    put('pTc', patch['pTc'] ?? patch['tc']);
    put('subeAdi', patch['subeAdi'] ?? patch['sube'] ?? patch['subeAdi']);

    await updatePersonel(
      id: id,
      ad: mapped['pAd'],
      soyad: mapped['pSoyad'],
      gorev: mapped['pGorev'],
      email: mapped['pIletisimEposta'],
      tc: mapped['pTc'],
      subeAdi: mapped['subeAdi'],
    );
  }

  // ---- Personel: Sil (POST /api/Personel/delete, Body: {"id": <id>}) ----
  static Future<void> deletePersonel(int id) async {
    final token = await _storage.read(key: 'token');
    final url = Uri.parse('$baseUrl$personelDeletePath');

    final res = await http.post(
      url,
      headers: _jsonHeaders(token: token),
      body: jsonEncode({"id": id}),
    );

    if (res.statusCode != 200 &&
        res.statusCode != 201 &&
        res.statusCode != 204) {
      throw Exception('Silme başarısız: ${res.statusCode}\n${res.body}');
    }

    try {
      if (res.body.isNotEmpty) {
        final j = jsonDecode(res.body);
        if (j is Map && j['success'] == false) {
          throw Exception(
              'Silme başarısız: ${j['message'] ?? j['code'] ?? 'bilinmiyor'}');
        }
      }
    } catch (_) {/* bazı durumlarda cevap boş olabilir */}
  }

  // ---- Dosya yükleme (CV) ----
  static Future<void> uploadPersonelFile({
    required int personelId,
    required File file,
  }) async {
    final token = await _storage.read(key: 'token');
    final url = Uri.parse(
        '$baseUrl/api/Personel/$personelId/Dosya'); // Swagger'da doğrula

    final req = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final res = await req.send();
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Dosya yükleme başarısız: ${res.statusCode}');
    }
  }
}
