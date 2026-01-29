// lib/screens/personel_list_screen.dart
import 'package:flutter/material.dart';
import '../models/personel.dart';
import '../services/api_service.dart';

class PersonelListScreen extends StatefulWidget {
  const PersonelListScreen({super.key, this.showFab = true});

  /// Bu ekranda kendi "Ekle" FAB'ının görünüp görünmeyeceğini kontrol eder.
  /// - Home'daki Personel sekmesinde: showFab:false
  /// - Ana sayfadan ayrı sayfa olarak açıldığında: showFab:true
  final bool showFab;

  @override
  State<PersonelListScreen> createState() => _PersonelListScreenState();
}

class _PersonelListScreenState extends State<PersonelListScreen> {
  late Future<List<Personel>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getPersoneller();
  }

  /// Listeyi güvenli biçimde yeniler
  Future<void> _refresh() async {
    final f = ApiService.getPersoneller();
    setState(() {
      _future = f;
    });
    await f;
  }

  Future<void> _showAddDialog() async {
    final cs = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    final adCtrl = TextEditingController();
    final soyadCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final gorevCtrl = TextEditingController(text: 'Stajyer');

    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Personel Ekle'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: adCtrl,
                  decoration: const InputDecoration(labelText: 'Ad'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                ),
                TextFormField(
                  controller: soyadCtrl,
                  decoration: const InputDecoration(labelText: 'Soyad'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                ),
                TextFormField(
                  controller: emailCtrl,
                  decoration:
                      const InputDecoration(labelText: 'E-posta (opsiyonel)'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextFormField(
                  controller: gorevCtrl,
                  decoration: const InputDecoration(labelText: 'Görev/Ünvan'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ApiService.addPersonel(
                  ad: adCtrl.text.trim(),
                  soyad: soyadCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  gorev: (gorevCtrl.text.trim().isEmpty)
                      ? 'Stajyer'
                      : gorevCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('Ekleme hatası: $e')),
                );
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      await _refresh();
      messenger.showSnackBar(const SnackBar(content: Text('Personel eklendi')));
    }
  }

  /// DÜZENLE diyalogu
  Future<void> _showEditDialog(Personel p) async {
    final cs = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    final adCtrl = TextEditingController(text: p.ad);
    final soyadCtrl = TextEditingController(text: p.soyad);
    final emailCtrl = TextEditingController(text: p.eposta);
    final gorevCtrl =
        TextEditingController(text: (p.gorev.isEmpty ? 'Stajyer' : p.gorev));
    bool aktif = p.aktif; // Şimdilik sadece UI, API'ye gönderilmiyor.

    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Personel Düzenle'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: adCtrl,
                  decoration: const InputDecoration(labelText: 'Ad'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                ),
                TextFormField(
                  controller: soyadCtrl,
                  decoration: const InputDecoration(labelText: 'Soyad'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                ),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(labelText: 'E-posta (opsiyonel)'),
                ),
                TextFormField(
                  controller: gorevCtrl,
                  decoration: const InputDecoration(labelText: 'Görev/Ünvan'),
                ),
                const SizedBox(height: 8),
                StatefulBuilder(
                  builder: (c, setSB) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktif'),
                    value: aktif,
                    onChanged: (v) => setSB(() => aktif = v),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ApiService.updatePersonel(
                  id: p.id,
                  ad: adCtrl.text.trim(),
                  soyad: soyadCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  gorev: (gorevCtrl.text.trim().isEmpty)
                      ? 'Stajyer'
                      : gorevCtrl.text.trim(),
                  subeAdi: 'Merkez', // API bunu bekliyor ise
                  // aktif: aktif, // ApiService imzan yoksa ekleme
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('Güncelleme hatası: $e')),
                );
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      await _refresh();
      messenger.showSnackBar(
        const SnackBar(content: Text('Personel güncellendi')),
      );
    }
  }

  Future<void> _confirmAndDelete(Personel p) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: Text('${p.adSoyad} kaydı silinecek. Onaylıyor musun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ApiService.deletePersonel(p.id);
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('${p.adSoyad} silindi')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Silme hatası: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Personel Listesi')),
      body: FutureBuilder<List<Personel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 40),
                    const SizedBox(height: 8),
                    Text('Hata: ${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            );
          }

          final items = snap.data ?? <Personel>[];
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Kayıt bulunamadı')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                widget.showFab ? 96 : 12, // FAB varsa altta boşluk bırak
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = items[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.primary.withOpacity(.1),
                    foregroundColor: cs.primary,
                    child: Text(
                      (p.adSoyad.isNotEmpty ? p.adSoyad[0] : '?').toUpperCase(),
                    ),
                  ),
                  title: Text(
                    p.adSoyad,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [p.gorev, p.eposta]
                        .where((s) => s.trim().isNotEmpty)
                        .join(' • '),
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'İşlemler',
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _showEditDialog(p);
                      } else if (value == 'delete') {
                        await _confirmAndDelete(p);
                      }
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Düzenle'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Sil'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert),
                  ),
                  onTap: () {
                    // TODO: Detay sayfasına git (getById ile)
                    messenger.showSnackBar(
                      SnackBar(content: Text('${p.adSoyad} seçildi')),
                    );
                  },
                  // Uzun basma ile de menüyü açmak istersen:
                  onLongPress: () {
                    final popup = PopupMenuButton<String>(
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Düzenle'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Sil'),
                        ),
                      ],
                      onSelected: (v) async {
                        if (v == 'edit') {
                          await _showEditDialog(p);
                        } else if (v == 'delete') {
                          await _confirmAndDelete(p);
                        }
                      },
                    );
                    final overlay = Overlay.of(context)
                        .context
                        .findRenderObject() as RenderBox?;
                    final box = context.findRenderObject() as RenderBox?;
                    final position = RelativeRect.fromSize(
                      Rect.fromLTWH(
                        box?.localToGlobal(Offset.zero).dx ?? 0,
                        box?.localToGlobal(Offset.zero).dy ?? 0,
                        box?.size.width ?? 0,
                        box?.size.height ?? 0,
                      ),
                      overlay?.size ?? const Size(0, 0),
                    );
                    popup.onSelected?.call; // no-op (lint susturmak için)
                    showMenu<String>(
                      context: context,
                      position: position,
                      items: const [
                        PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                        PopupMenuItem(value: 'delete', child: Text('Sil')),
                      ],
                    ).then((v) async {
                      if (v == 'edit') {
                        await _showEditDialog(p);
                      } else if (v == 'delete') {
                        await _confirmAndDelete(p);
                      }
                    });
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: widget.showFab
          ? FloatingActionButton.extended(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Ekle'),
            )
          : null,
    );
  }
}
