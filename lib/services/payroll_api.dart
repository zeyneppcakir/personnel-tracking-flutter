// lib/services/payroll_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // debugPrint
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/payroll.dart';
import '../models/payroll_setting.dart';

class PayrollApi {
  // Ayarlardan gelmezse kullanılacak varsayılan API kökü
  static const String _fallbackBase = 'https://apiv3.bilsoft.com';

  // Secure token storage
  static const _storage = FlutterSecureStorage();

  // SharedPreferences anahtarları
  static const _kApiUrl = 'settings.apiUrl';
  static const _kLog = 'settings.logging';

  // Yerel (manuel) oran override anahtarları
  static const _kLocalUse = 'ps.local.enabled';
  static const _kLocalSgk = 'ps.local.sgk';
  static const _kLocalIssiz = 'ps.local.issiz';
  static const _kLocalDamga = 'ps.local.damga';

  // ───────────────────────────
  // SETTINGS → BASE URL & LOGGING
  // ───────────────────────────
  static Future<String> _baseUrl() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final v = sp.getString(_kApiUrl);
      if (v != null && v.trim().isNotEmpty) return v.trim();
    } catch (_) {}
    return _fallbackBase;
  }

  static Future<bool> _loggingOn() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getBool(_kLog) ?? false;
    } catch (_) {
      return false;
    }
  }

  static void _log(String message) async {
    if (await _loggingOn()) {
      debugPrint(message);
    }
  }

  // Yerel oranları oku
  static Future<bool> _useLocalRates() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kLocalUse) ?? false;
  }

  static Future<(double?, double?, double?)> _localRates() async {
    final sp = await SharedPreferences.getInstance();
    return (
      sp.getDouble(_kLocalSgk),
      sp.getDouble(_kLocalIssiz),
      sp.getDouble(_kLocalDamga),
    );
  }

  // ───────────────────────────
  // TOKEN & HEADER YARDIMCILARI
  // ───────────────────────────
  static Future<String?> _token() => _storage.read(key: 'token');

  static Future<Map<String, String>> _headers({bool json = true}) async {
    final t = await _token();
    return {
      if (json) 'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  // Esnek liste/obje parse yardımcıları
  static List _extractList(dynamic body) {
    if (body is Map && body['data'] is List) return body['data'] as List;
    if (body is Map && body['items'] is List) return body['items'] as List;
    if (body is Map && body['result'] is List) return body['result'] as List;
    if (body is List) return body;
    return const [];
  }

  static Map<String, dynamic> _extractObject(dynamic body) {
    if (body is Map && body['data'] is Map) {
      return body['data'] as Map<String, dynamic>;
    }
    if (body is Map<String, dynamic>) return body;
    if (body is Map &&
        body['data'] is List &&
        (body['data'] as List).isNotEmpty) {
      return (body['data'] as List).first as Map<String, dynamic>;
    }
    throw Exception('Beklenmeyen yanıt formatı');
  }

  static dynamic _decode(String src) {
    // Türkçe karakter vs. için güvenli
    return jsonDecode(utf8.decode(src.codeUnits));
  }

  // ───────────────────────────
  // BORDRO AYARLARI (SGK/İşsizlik/Damga vs.)
  // Swagger: POST /api/Bordroayar/getall (body genelde {})
  // ───────────────────────────
  static const String _settingsGetAll = '/api/Bordroayar/getall';

  static Future<List<PayrollSetting>> fetchSettings() async {
    final headers = await _headers();
    final base = await _baseUrl();
    final uri = Uri.parse('$base$_settingsGetAll');

    _log('[PayrollApi] POST $uri body={}');
    final res = await http
        .post(uri, headers: headers, body: jsonEncode({}))
        .timeout(const Duration(seconds: 20));

    _log('[PayrollApi] <${res.statusCode}> ${res.body}');
    if (res.statusCode != 200) {
      throw Exception(
          'Bordro ayarları alınamadı: ${res.statusCode} ${res.body}');
    }

    final decoded = _decode(res.body);

    // Önce ham map listesi üzerinde çalış, sonra modele map et
    final rawList = _extractList(decoded)
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // Yerel oran override
    if (rawList.isNotEmpty && await _useLocalRates()) {
      final (sgkL, issizL, damgaL) = await _localRates();
      final m = rawList.first; // genelde tek satır
      if (sgkL != null) m['sgkKesintiOran'] = sgkL;
      if (issizL != null) m['issizlikSigortasiKesintiOran'] = issizL;
      if (damgaL != null) m['damgaVergisiOran'] = damgaL;
      _log(
          '[PayrollApi] Yerel oranlar uygulandı: sgk=$sgkL issiz=$issizL damga=$damgaL');
    }

    return rawList.map((e) => PayrollSetting.fromJson(e)).toList();
  }

  // ───────────────────────────
  // BORDRO KAYITLARI (Bodrotablo)
  // ───────────────────────────
  // Swagger yolları:
  static const String _recordList = '/api/Bodrotablo/getall'; // POST
  static const String _recordGet = '/api/Bodrotablo/getbyid'; // GET  ?id=
  static const String _recordCreate = '/api/Bodrotablo/add'; // POST
  static const String _recordUpdate = '/api/Bodrotablo/update'; // PUT
  static const String _recordDelete = '/api/Bodrotablo/delete'; // POST {id}

  /// Listeleme (POST). Varsayılan sayfa parametreleri ekli.
  /// `filter` içine Swagger’daki alanlar: ör. {'aranacakKelime':'2025-08', 'personid': 1}
  static Future<List<Payroll>> list({Map<String, dynamic>? filter}) async {
    final headers = await _headers();
    final base = await _baseUrl();
    final uri = Uri.parse('$base$_recordList');

    final body = <String, dynamic>{
      'sayfa': 1,
      'sayfaBoyutu': 100,
      ...?filter,
    };

    _log('[PayrollApi] POST $uri body=${jsonEncode(body)}');
    final res = await http
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));

    _log('[PayrollApi] <${res.statusCode}> ${res.body}');
    if (res.statusCode != 200) {
      throw Exception(
          'Bordro listesi alınamadı: ${res.statusCode} ${res.body}');
    }

    final decoded = _decode(res.body);
    final list = _extractList(decoded);

    return list
        .map((e) => Payroll.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Id ile tek kayıt çekme
  static Future<Payroll> getById(int id) async {
    final headers = await _headers();
    final base = await _baseUrl();
    final uri =
        Uri.parse('$base$_recordGet').replace(queryParameters: {'id': '$id'});

    _log('[PayrollApi] GET $uri');
    final res = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 20));

    _log('[PayrollApi] <${res.statusCode}> ${res.body}');
    if (res.statusCode != 200) {
      throw Exception(
          'Bordro getById başarısız: ${res.statusCode} ${res.body}');
    }

    final decoded = _decode(res.body);
    final map = _extractObject(decoded);
    return Payroll.fromJson(map);
  }

  /// Yeni bordro ekleme
  static Future<int> create(Payroll payroll) async {
    final headers = await _headers();
    final base = await _baseUrl();
    final uri = Uri.parse('$base$_recordCreate');

    final bodyStr = jsonEncode(payroll.toJson());
    _log('[PayrollApi] POST $uri body=$bodyStr');

    final res = await http
        .post(uri, headers: headers, body: bodyStr)
        .timeout(const Duration(seconds: 20));

    _log('[PayrollApi] <${res.statusCode}> ${res.body}');
    if (res.statusCode == 200 || res.statusCode == 201) {
      final body = _decode(res.body);
      if (body is Map && body['id'] is int) return body['id'] as int;
      if (body is Map && body['data'] is Map && body['data']['id'] is int) {
        return body['data']['id'] as int;
      }
      // bazı API'ler id dönmeyebilir
      return 0;
    }
    throw Exception('Bordro create başarısız: ${res.statusCode} ${res.body}');
  }

  /// Güncelleme
  static Future<bool> update(Payroll payroll) async {
    final headers = await _headers();
    final base = await _baseUrl();
    final uri = Uri.parse('$base$_recordUpdate');

    final bodyStr = jsonEncode(payroll.toJson());
    _log('[PayrollApi] PUT $uri body=$bodyStr');

    final res = await http
        .put(uri, headers: headers, body: bodyStr)
        .timeout(const Duration(seconds: 20));

    _log('[PayrollApi] <${res.statusCode}> ${res.body}');
    return res.statusCode == 200;
  }

  /// Silme (POST {id})
  static Future<bool> delete(int id) async {
    final headers = await _headers();
    final base = await _baseUrl();
    final uri = Uri.parse('$base$_recordDelete');

    final bodyStr = jsonEncode({'id': id});
    _log('[PayrollApi] POST $uri body=$bodyStr');

    final res = await http
        .post(uri, headers: headers, body: bodyStr)
        .timeout(const Duration(seconds: 20));

    _log('[PayrollApi] <${res.statusCode}> ${res.body}');
    return res.statusCode == 200;
  }
}
