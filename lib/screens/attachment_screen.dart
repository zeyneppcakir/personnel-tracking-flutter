// lib/screens/attachment_screen.dart
// ignore: unused_import
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/file_storage_service.dart';

// Basit yerel dosya modeli (UI için)
class _LocalFile {
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime? modified;

  _LocalFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.modified,
  });
}

class AttachmentScreen extends StatefulWidget {
  final int personnelId;
  const AttachmentScreen({super.key, required this.personnelId});

  @override
  State<AttachmentScreen> createState() => _AttachmentScreenState();
}

class _AttachmentScreenState extends State<AttachmentScreen> {
  bool _loading = false;
  List<_LocalFile> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // ⬇️ Buradaki düzeltme: list -> listFiles
      final files =
          await FileStorageService.listFiles(personId: widget.personnelId);

      final mapped = <_LocalFile>[];
      for (final f in files) {
        try {
          final stat = await f.stat();
          mapped.add(
            _LocalFile(
              path: f.path,
              name: p.basename(f.path),
              sizeBytes: stat.size,
              modified: stat.modified,
            ),
          );
        } catch (_) {
          // okunamayan dosya atlanır
        }
      }

      mapped.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      if (mounted) setState(() => _items = mapped);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Listeleme hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndSave() async {
    setState(() => _loading = true);
    try {
      final newPath =
          await FileStorageService.pickAndSave(personId: widget.personnelId);
      if (!mounted) return;

      if (newPath != null) {
        await _load();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Dosya eklendi')));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('İşlem iptal edildi')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yükleme hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String path) async {
    try {
      await FileStorageService.open(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Açılamadı: $e')));
    }
  }

  Future<void> _delete(String path) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: const Text('Bu dosya kalıcı olarak silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      final success = await FileStorageService.delete(path);
      if (!mounted) return;

      if (success) {
        await _load();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Silindi')));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Silme başarısız')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Silme hatası: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dosyalar • Personel #${widget.personnelId}'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Dosya Ekle',
            onPressed: _pickAndSave,
            icon: const Icon(Icons.upload_file),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Kayıtlı dosya yok'))
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final f = _items[i];
                    final modified = f.modified != null
                        ? '${f.modified!.year}-${f.modified!.month.toString().padLeft(2, '0')}-${f.modified!.day.toString().padLeft(2, '0')} '
                            '${f.modified!.hour.toString().padLeft(2, '0')}:${f.modified!.minute.toString().padLeft(2, '0')}'
                        : '';
                    return ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(f.name),
                      subtitle: Text(
                        '${_fmtSize(f.sizeBytes)}  •  $modified',
                        maxLines: 1,
                      ),
                      onTap: () => _open(f.path),
                      trailing: IconButton(
                        tooltip: 'Sil',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(f.path),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndSave,
        icon: const Icon(Icons.add),
        label: const Text('Dosya Ekle'),
      ),
    );
  }
}
