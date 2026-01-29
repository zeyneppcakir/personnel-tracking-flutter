// lib/screens/home_screen.dart
import 'package:flutter/material.dart';

import 'personel_list_screen.dart';
import 'payroll_form_screen.dart';
import 'attachment_screen.dart';
import 'settings_screen.dart';

import '../services/api_service.dart';
import '../services/payroll_api.dart';
import '../models/personel.dart';
import '../models/payroll.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // Ana sayfayı dışarıdan yenilemek için
  final _dashKey = GlobalKey<_DashboardPageState>();
  // Bordro listesini dışarıdan kontrol için
  final _payrollKey = GlobalKey<_PayrollListPageState>();

  String _currentPeriod() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    return '${now.year}-$m';
  }

  @override
  Widget build(BuildContext context) {
    // Sekme başlıkları (sabit metinler)
    final titles = [
      'Ana Sayfa',
      'Personel',
      'Bordro',
      'Dosyalar',
      'Ayarlar',
    ];

    final pages = [
      _DashboardPage(
        key: _dashKey,
        openPayrollForm: _openPayrollForm,
        openFilesTab: () => setState(() => _index = 3),
      ),
      const PersonelListScreen(showFab: false),
      _PayrollListPage(key: _payrollKey, openPayrollForm: _openPayrollForm),
      const _FilesPage(),
      const SettingsScreen(),
    ];

    final body = _index == 4 ? const SettingsScreen() : pages[_index];

    return Scaffold(
      appBar: _index == 4
          ? null
          : AppBar(
              title: Text(titles[_index]),
              actions: [
                if (_index == 1)
                  IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
                if (_index == 2)
                  IconButton(
                    tooltip: 'Yenile',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _payrollKey.currentState?.reload(),
                  ),
                IconButton(
                  tooltip: 'Çıkış',
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (_) => false,
                  ),
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 0) _dashKey.currentState?.refresh();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Personel',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Bordro',
          ),
          NavigationDestination(
            icon: Icon(Icons.attach_file_outlined),
            selectedIcon: Icon(Icons.attach_file),
            label: 'Dosyalar',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
      floatingActionButton: _index == 2
          ? FloatingActionButton.extended(
              onPressed: () => _payrollKey.currentState?.createNew(),
              icon: const Icon(Icons.add),
              label: const Text('Yeni'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Future<void> _openPayrollForm() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PayrollFormScreen(
          personnelId: 1, // TODO: seçili personel ID
          initialPeriod: _currentPeriod(),
        ),
      ),
    );
    if (ok == true) _payrollKey.currentState?.reload();
  }
}

/// ---------------- Dashboard (Ana Sayfa) ----------------

class _Counts {
  final int total;
  final int active;
  const _Counts(this.total, this.active);
}

class _DashboardPage extends StatefulWidget {
  const _DashboardPage({
    super.key,
    required this.openPayrollForm,
    required this.openFilesTab,
  });

  final VoidCallback openPayrollForm;
  final VoidCallback openFilesTab;

  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  late Future<_Counts> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Counts> _load() async {
    final List<Personel> list = await ApiService.getPersoneller();
    final active = list.where((p) => p.aktif == true).length;
    return _Counts(list.length, active);
  }

  Future<void> refresh() async {
    final f = _load();
    setState(() {
      _future = f;
    });
    await f;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ana Sayfa',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _QuickAction(
                icon: Icons.people,
                title: 'Personel Listesi',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PersonelListScreen(showFab: true),
                    ),
                  );
                  if (mounted) await refresh();
                },
              ),
              _QuickAction(
                icon: Icons.person_add,
                title: 'Personel Ekle',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PersonelListScreen(showFab: true),
                    ),
                  );
                  if (mounted) await refresh();
                },
              ),
              _QuickAction(
                icon: Icons.receipt_long,
                title: 'Bordro',
                onTap: widget.openPayrollForm,
              ),
              _QuickAction(
                icon: Icons.attach_file,
                title: 'Dosya Yükle',
                onTap: widget.openFilesTab,
              ),
            ],
          ),
          const SizedBox(height: 24),
          FutureBuilder<_Counts>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator(minHeight: 2);
              }
              if (snap.hasError) {
                return Text(
                  'Sayılar yüklenemedi: ${snap.error}',
                  style: const TextStyle(color: Colors.red),
                );
              }
              final counts = snap.data ?? const _Counts(0, 0);
              return Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Toplam Personel',
                      value: counts.total.toString(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Aktif',
                      value: counts.active.toString(),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: cs.primary),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------- Bordro Listesi (yalnız içerik) ----------------

class _PayrollListPage extends StatefulWidget {
  const _PayrollListPage({super.key, required this.openPayrollForm});
  final VoidCallback openPayrollForm;

  @override
  State<_PayrollListPage> createState() => _PayrollListPageState();
}

class _PayrollListPageState extends State<_PayrollListPage> {
  late Future<List<Payroll>> _future;
  Map<String, dynamic>? _lastFilter;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload([Map<String, dynamic>? filter]) {
    setState(() {
      _lastFilter = filter ?? _lastFilter;
      _future = PayrollApi.list(filter: _lastFilter);
    });
  }

  void createNew() => _create();

  Future<void> _create() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PayrollFormScreen(
          personnelId: 1, // TODO: seçili personel ID
          initialPeriod: _currentPeriod(),
        ),
      ),
    );
    if (ok == true) reload();
  }

  Future<void> _delete(int id) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: const Text('Bu bordro kaydı kalıcı olarak silinecek.'),
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
    if (sure != true) return;

    final ok = await PayrollApi.delete(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Silindi' : 'Silme başarısız')),
    );
    if (ok) reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Payroll>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Liste alınamadı:\n${snap.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final items = snap.data ?? const <Payroll>[];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: const Text('Yeni Bordro Oluştur'),
                ),
                const SizedBox(height: 12),
                const Text('Henüz bordro bulunmuyor'),
              ],
            ),
          );
        }

        // FAB’ın altında kalmasın diye alt padding
        return RefreshIndicator(
          onRefresh: () async => reload(),
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = items[i];
              return ListTile(
                title: Text('${p.bodroDonem}  •  Personel #${p.personId}'),
                subtitle: Text(
                  'Brüt: ${p.brutUcret.toStringAsFixed(2)}   Net: ${p.netUcret.toStringAsFixed(2)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(p.id ?? 0),
                ),
                onTap: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PayrollFormScreen(
                        personnelId: p.personId,
                        initialPeriod: p.bodroDonem,
                        initial: p,
                      ),
                    ),
                  );
                  if (ok == true) reload();
                },
              );
            },
          ),
        );
      },
    );
  }

  String _currentPeriod() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    return '${now.year}-$m';
  }
}

/// ---------------- Dosyalar sekmesi ----------------

class _FilesPage extends StatefulWidget {
  const _FilesPage();
  @override
  State<_FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<_FilesPage> {
  final _idCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Personel Dosyaları',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _idCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Personel ID',
                  hintText: 'Örn: 1',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _open(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Aç'),
              onPressed: _open,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Not: ID girip “Aç”a bastığınızda, o personele ait dosyaları listeleyip yükleyebileceğiniz ekrana gidersiniz.',
        ),
      ],
    );
  }

  void _open() {
    final id = int.tryParse(_idCtrl.text.trim());
    if (id == null || id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir Personel ID giriniz')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AttachmentScreen(personnelId: id)),
    );
  }
}
