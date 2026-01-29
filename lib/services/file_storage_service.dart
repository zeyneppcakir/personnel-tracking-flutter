// lib/services/file_storage_service.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class FileStorageService {
  /// Uygulamanın dokümanlar altında personel bazlı klasörü:
  /// <app-documents>/personel/<id>/
  static Future<Directory> _personDir(int personId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'personel', '$personId'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Klasörün yolunu string olarak istersek
  static Future<String> personDirPath(int personId) async {
    final d = await _personDir(personId);
    return d.path;
  }

  /// Aynı isimli dosyayı ezmemek için güvenli (benzersiz) ad üretir.
  static Future<String> _uniqueDestPath(
      Directory destDir, String fileName) async {
    String safe = (fileName.trim().isEmpty) ? 'dosya' : fileName.trim();
    String tryPath = p.join(destDir.path, safe);

    if (!await File(tryPath).exists()) return tryPath;

    // Aynı isim varsa zaman damgası ekle
    final ts = DateTime.now().millisecondsSinceEpoch;
    final name = p.basenameWithoutExtension(safe);
    final ext = p.extension(safe);
    safe = '$name\_$ts$ext';
    return p.join(destDir.path, safe);
  }

  /// (1) Dosya seçtir ve uygulama dizinine kopyala. Yeni dosya yolunu döner.
  static Future<String?> pickAndSave({required int personId}) async {
    final result = await FilePicker.platform.pickFiles(withReadStream: true);
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    final destDir = await _personDir(personId);
    final destPath = await _uniqueDestPath(destDir, picked.name);

    // Öncelik: stream -> path -> bytes
    if (picked.readStream != null) {
      final out = File(destPath).openWrite();
      await picked.readStream!.pipe(out);
      await out.flush();
      await out.close();
      return destPath;
    }

    if (picked.path != null) {
      await File(picked.path!).copy(destPath);
      return destPath;
    }

    if (picked.bytes != null) {
      await File(destPath).writeAsBytes(picked.bytes!, flush: true);
      return destPath;
    }

    return null;
  }

  /// (2) Varolan bir dosyayı YOL üzerinden personel klasörüne kopyala.
  static Future<String> saveFromPath({
    required int personId,
    required String sourcePath,
    String? renameAs,
  }) async {
    final src = File(sourcePath);
    if (!await src.exists()) {
      throw Exception('Kaynak dosya bulunamadı: $sourcePath');
    }
    final destDir = await _personDir(personId);
    final destPath =
        await _uniqueDestPath(destDir, renameAs ?? p.basename(sourcePath));
    await src.copy(destPath);
    return destPath;
  }

  /// (3) Bytes verisini yazarak yeni dosya oluştur.
  static Future<String> saveBytes({
    required int personId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final destDir = await _personDir(personId);
    final destPath = await _uniqueDestPath(destDir, fileName);
    await File(destPath).writeAsBytes(bytes, flush: true);
    return destPath;
  }

  /// Kayıtlı dosyaları File olarak listele.
  static Future<List<File>> listFiles({required int personId}) async {
    final dir = await _personDir(personId);
    if (!await dir.exists()) return <File>[];
    final entries = await dir.list().toList();
    final files = entries.whereType<File>().toList();
    files.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return files;
  }

  /// Kayıtlı dosyaları yol (String) olarak listele.
  static Future<List<String>> listPaths({required int personId}) async {
    final files = await listFiles(personId: personId);
    return files.map((f) => f.path).toList();
  }

  /// Kayıtlı dosyaları sadece ad (basename) olarak listele.
  static Future<List<String>> listNames({required int personId}) async {
    final files = await listFiles(personId: personId);
    return files.map((f) => p.basename(f.path)).toList();
  }

  /// Dosyayı varsayılan sistem uygulamasıyla aç.
  static Future<void> open(String path) async {
    await OpenFilex.open(path);
  }

  /// Sil
  static Future<bool> delete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Test için örnek bir .txt dosyası oluşturur ve yolunu döner.
  static Future<String> createSampleTxt({
    required int personId,
    String fileName = 'ornek.txt',
    String content = 'Merhaba! Bu bir örnek dosyadır.',
  }) async {
    final destDir = await _personDir(personId);
    final destPath = await _uniqueDestPath(destDir, fileName);
    await File(destPath).writeAsString(content, flush: true);
    return destPath;
  }
}
