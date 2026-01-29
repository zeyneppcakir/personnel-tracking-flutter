// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/payroll_setting.dart';
import '../services/payroll_api.dart';

// Uygulama-genel ayar yönetimi (tema/dil) için
import '../shared/app_settings.dart';
import '../shared/settings_prefs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // --- Bordro oranları (API’den)
  late Future<List<PayrollSetting>> _settingsFuture;

  // --- Uygulama ayarları (yerel depolanan alanlar)
  final _userCtrl = TextEditingController();
  final _apiCtrl = TextEditingController();
  final _daysCtrl = TextEditingController();

  // Yerel oranlar (manuel override)
  bool _useLocalRates = false;
  final _sgkCtrl = TextEditingController(); // yüzde olarak girilecek (örn: 14)
  final _issizCtrl = TextEditingController(); // yüzde (örn: 1)
  final _damgaCtrl = TextEditingController(); // yüzde (örn: 0.759)

  // Tema & Dil provider’dan okunup yazılacak
  bool _dark = false; // ThemeMode.dark?
  String _lang = 'tr'; // 'tr' | 'en'
  bool _logging = false;

  bool _saving = false;

  // SharedPreferences KEY’leri (yerel alanlar için)
  static const _kUsername = 'settings.username';
  static const _kDays = 'settings.defaultWorkDays';
  static const _kApi = 'settings.apiUrl';
  static const _kLog = 'settings.logging';

  // Yerel oran override anahtarları (PayrollApi ile tutarlı)
  static const _kLocalUse = 'ps.local.enabled';
  static const _kLocalSgk = 'ps.local.sgk';
  static const _kLocalIssiz = 'ps.local.issiz';
  static const _kLocalDamga = 'ps.local.damga';

  @override
  void initState() {
    super.initState();
    _settingsFuture = PayrollApi.fetchSettings();
    _loadAll();
  }

  // "14" -> 0.14; "0,759" -> 0.00759 (yüzde kabulü)
  double? _parsePercentToFraction(String input) {
    final s = input.trim().replaceAll('%', '').replaceAll(',', '.');
    if (s.isEmpty) return null;
    final v = double.tryParse(s);
    if (v == null) return null;
    return v / 100.0;
  }

  // 0.14 -> "14.00", 0.00759 -> "0.76"
  String _formatFractionAsPercent(double? f) {
    if (f == null) return '';
    return (f * 100).toStringAsFixed(2);
  }

  Future<void> _loadAll() async {
    // 1) Tema & Dil -> provider + SettingsPrefs
    final app = context.read<AppSettings>();
    setState(() {
      _dark = app.themeMode == ThemeMode.dark;
      _lang = app.langCode; // AppSettings içinde 'tr' / 'en'
    });

    // 2) Diğer ayarlar -> SharedPreferences
    final sp = await SharedPreferences.getInstance();
    _userCtrl.text = sp.getString(_kUsername) ?? 'zeynep';
    _apiCtrl.text = sp.getString(_kApi) ?? 'https://apiv3.bilsoft.com';
    _daysCtrl.text = (sp.getInt(_kDays) ?? 30).toString();
    _logging = sp.getBool(_kLog) ?? false;

    // 3) Yerel oranlar
    _useLocalRates = sp.getBool(_kLocalUse) ?? false;
    final sgk = sp.getDouble(_kLocalSgk);
    final issiz = sp.getDouble(_kLocalIssiz);
    final damga = sp.getDouble(_kLocalDamga);
    _sgkCtrl.text = _formatFractionAsPercent(sgk); // yüzde string
    _issizCtrl.text = _formatFractionAsPercent(issiz);
    _damgaCtrl.text = _formatFractionAsPercent(damga);

    if (mounted) setState(() {});
  }

  Future<void> _saveAll() async {
    final app = context.read<AppSettings>();
    final messenger = ScaffoldMessenger.of(context);

    // Normalize alanlar
    final username =
        _userCtrl.text.trim().isEmpty ? 'zeynep' : _userCtrl.text.trim();
    final api = _apiCtrl.text.trim().isEmpty
        ? 'https://apiv3.bilsoft.com'
        : _apiCtrl.text.trim();
    final days = int.tryParse(_daysCtrl.text.trim()) ?? 30;

    // Yerel oranları yüzde -> kesir çevir
    final sgkFrac = _parsePercentToFraction(_sgkCtrl.text); // ör: 14 -> 0.14
    final issizFrac = _parsePercentToFraction(_issizCtrl.text); // ör: 1 -> 0.01
    final damgaFrac =
        _parsePercentToFraction(_damgaCtrl.text); // ör: 0.759 -> 0.00759

    if (_useLocalRates) {
      // Basit validasyon
      bool invalid = false;
      for (final x in [sgkFrac, issizFrac, damgaFrac]) {
        if (x == null || x < 0 || x > 1) {
          invalid = true;
          break;
        }
      }
      if (invalid) {
        messenger.showSnackBar(const SnackBar(
          content: Text(
              'Yerel oranları doğru yüzde olarak giriniz (örn: 14, 1, 0.759)'),
        ));
        return;
      }
    }

    setState(() => _saving = true);

    // 1) Tema & Dil -> hem provider’ı güncelle hem prefs’e yaz
    final themeMode = _dark ? ThemeMode.dark : ThemeMode.light;
    app.setThemeMode(themeMode);
    await SettingsPrefs.saveTheme(themeMode);

    app.setLang(_lang);
    await SettingsPrefs.saveLang(_lang);

    // 2) Diğer alanları prefs’e yaz
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kUsername, username);
    await sp.setString(_kApi, api);
    await sp.setInt(_kDays, days <= 0 ? 30 : days);
    await sp.setBool(_kLog, _logging);

    // 3) Yerel oranları yaz
    await sp.setBool(_kLocalUse, _useLocalRates);
    if (_useLocalRates) {
      await sp.setDouble(_kLocalSgk, sgkFrac!);
      await sp.setDouble(_kLocalIssiz, issizFrac!);
      await sp.setDouble(_kLocalDamga, damgaFrac!);
    } else {
      // Kapatıldıysa değerleri temizlemeye gerek yok ama istersen:
      // await sp.remove(_kLocalSgk); await sp.remove(_kLocalIssiz); await sp.remove(_kLocalDamga);
    }

    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(const SnackBar(content: Text('Ayarlar kaydedildi')));

    // Yerel oran değiştiyse üstteki kartı tazele
    setState(() {
      _settingsFuture = PayrollApi.fetchSettings();
    });
  }

  String _pct(num? v) => '${(((v ?? 0) * 100)).toStringAsFixed(2)}%';

  @override
  void dispose() {
    _userCtrl.dispose();
    _apiCtrl.dispose();
    _daysCtrl.dispose();
    _sgkCtrl.dispose();
    _issizCtrl.dispose();
    _damgaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------------- BORDRO AYARLARI ----------------
          Text(
            'Bordro Ayarları',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: cs.primary),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<PayrollSetting>>(
            future: _settingsFuture,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snap.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ayarlar alınamadı: ${snap.error}',
                        style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => setState(
                          () => _settingsFuture = PayrollApi.fetchSettings()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Yenile'),
                    ),
                  ],
                );
              }

              final list = snap.data ?? const <PayrollSetting>[];
              if (list.isEmpty) {
                return FilledButton.icon(
                  onPressed: () => setState(
                      () => _settingsFuture = PayrollApi.fetchSettings()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yenile'),
                );
              }

              final s = list.first;
              return Column(
                children: [
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.health_and_safety_outlined),
                          title: const Text('SGK Kesinti Oranı'),
                          trailing: Text(_pct(s.sgkKesintiOran)),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.work_outline),
                          title: const Text('İşsizlik Sigortası Oranı'),
                          trailing: Text(_pct(s.issizlikSigortasiKesintiOran)),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.sticky_note_2_outlined),
                          title: const Text('Damga Vergisi Oranı'),
                          trailing: Text(_pct(s.damgaVergisiOran)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Yerel oranlar bölümü
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Yerel oranları kullan'),
                            subtitle: const Text(
                                'Aşağıdaki SGK / İşsizlik / Damga yüzdeleri API’dan gelen oranların yerine uygulanır'),
                            value: _useLocalRates,
                            onChanged: (v) =>
                                setState(() => _useLocalRates = v),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  enabled: _useLocalRates,
                                  controller: _sgkCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'SGK (%)',
                                    hintText: 'örn. 14',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  enabled: _useLocalRates,
                                  controller: _issizCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'İşsizlik (%)',
                                    hintText: 'örn. 1',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            enabled: _useLocalRates,
                            controller: _damgaCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Damga (%)',
                              hintText: 'örn. 0.759',
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Not: Yüzde olarak giriniz. Örn. 14 → 14.00 (kaydedilirken 0.14’e çevrilir).',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // ---------------- UYGULAMA AYARLARI ----------------
          Text(
            'Uygulama Ayarları',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: cs.primary),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Kullanıcı Adı'),
                  subtitle: const Text(
                      'Bordro kayıtlarındaki "kullaniciAdi" alanında kullanılır'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      hintText: 'ör. zeynep',
                      labelText: 'Kullanıcı Adı',
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Karanlık Tema'),
                  subtitle: const Text('Tema değişimi anında uygulanır'),
                  value: _dark,
                  onChanged: (v) => setState(() => _dark = v),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Dil'),
                  subtitle: const Text('Uygulama dili'),
                  trailing: DropdownButton<String>(
                    value: _lang,
                    items: const [
                      DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (v) => setState(() => _lang = v ?? 'tr'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Varsayılan Çalışma Günü'),
                  subtitle: const Text('Bordro hesaplamasında öneri değer'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextField(
                    controller: _daysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'örn. 30',
                      labelText: 'Çalışma Günü',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ---------------- TEKNİK AYARLAR ----------------
          Text(
            'Teknik Ayarlar',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: cs.primary),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('API URL'),
                  subtitle:
                      const Text('Geliştirme/üretim arasında geçişte yararlı'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _apiCtrl,
                    decoration: const InputDecoration(
                      hintText: 'https://apiv3.bilsoft.com',
                      labelText: 'API URL',
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Loglama'),
                  subtitle: const Text('Hata/istek loglarını aç/kapat'),
                  value: _logging,
                  onChanged: (v) => setState(() => _logging = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _saveAll,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: const Text('Kaydet'),
          ),
          const SizedBox(height: 8),
          Text(
            'Not: Tema/Dil değişiklikleri büyük ölçüde anında uygulanır. '
            'Bordro oranlarını değiştirince üstteki kart “Yeniden Yüklenir” ve hesaplamalara yansır.',
            style: TextStyle(color: Colors.black.withOpacity(.6), fontSize: 12),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
