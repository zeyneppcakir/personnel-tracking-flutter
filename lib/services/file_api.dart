import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/attachment.dart';

class FileApi {
  // TODO: Swagger’a göre güncelle
  static const String _base = 'https://apiv3.bilsoft.com';
  static const String _upload = '/api/File/upload';
  static const String _list = '/api/File/list';
  static const String _delete = '/api/File/delete';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<String?> _token() => _storage.read(key: 'token');

  static Future<Map<String, String>> _authHeaders() async {
    final t = await _token();
    return {
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  static Future<List<Attachment>> list(int personnelId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_base$_list').replace(
      queryParameters: {'personnelId': '$personnelId'},
    );
    final res = await http.get(uri, headers: headers);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data
          .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('File list failed: ${res.statusCode} ${res.body}');
  }

  static Future<bool> deleteFile(int id) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_base$_delete');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
      body: jsonEncode({'id': id}),
    );
    return res.statusCode == 200;
  }

  static Future<bool> upload({
    required int personnelId,
    required File file,
  }) async {
    final t = await _token();
    final uri = Uri.parse('$_base$_upload');
    final req = http.MultipartRequest('POST', uri);
    if (t != null) req.headers['Authorization'] = 'Bearer $t';

    req.fields['personnelId'] = '$personnelId';
    req.files.add(await http.MultipartFile.fromPath('file', file.path));

    final res = await req.send();
    return res.statusCode == 200;
  }
}
