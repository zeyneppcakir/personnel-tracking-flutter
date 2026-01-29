// lib/screens/payroll_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/payroll.dart';
import '../models/payroll_setting.dart';
import '../services/payroll_api.dart';

/// Hesaplama modları:
/// - grossBase: Brüt taban + mesai + ek kazançlar
/// - netTarget: Net hedefe göre brütü ters hesapla
/// - dailyNetTimesDays: Günlük net * gün hedefine göre brütü ters hesapla
enum CalcMode { grossBase, netTarget, dailyNetTimesDays }

class PayrollFormScreen extends StatefulWidget {
  final int personnelId; // seçili personel
  final String initialPeriod; // "YYYY-MM"
  final Payroll? initial; // düzenleme için (opsiyonel)

  const PayrollFormScreen({
    super.key,
    required this.personnelId,
    required this.initialPeriod,
    this.initial,
  });

  @override
  State<PayrollFormScreen> createState() => _PayrollFormScreenState();
}

// Yalın satır öğesi (UI için)
class PayrollItem {
  final String name;
  final double amount;
  final bool isEarning; // true = kazanç, false = kesinti
  PayrollItem({
    required this.name,
    required this.amount,
    required this.isEarning,
  });
}

class _PayrollFormScreenState extends State<PayrollFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // ---- Giriş alanları
  late int _personnelId;
  late String _period; // YYYY-MM

  CalcMode _mode = CalcMode.grossBase;

  // Brüt taban modu
  double _baseGross = 0;

  // Net hedef modu
  double _targetNet = 0;

  // Günlük net × gün modu
  double _dailyNet = 0;
  int _workDays = 30;

  // Mesai
  double _otHours = 0, _otRate = 0;

  // Serbest kalemler
  final List<PayrollItem> _items = [];

  // Ayarlar (API)
  bool _loadingSettings = false;
  PayrollSetting? _ps;

  // Ayar override’ları (shared_preferences)
  double? _ovSgk, _ovIss, _ovDam;

  // Kaydetme
  bool _saving = false;

  // yalnızca sayı + . , kabul eden formatter
  final List<TextInputFormatter> _numFmt = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
  ];

  @override
  void initState() {
    super.initState();
    _personnelId = widget.personnelId;
    _period = widget.initial?.bodroDonem ?? widget.initialPeriod;

    if (widget.initial != null) {
      _fillFromExisting(widget.initial!);
    }
    _loadSettings();
  }

  void _fillFromExisting(Payroll p) {
    _personnelId = p.personId;
    _period = p.bodroDonem; // "YYYY-MM"
    _baseGross = p.brutUcret; // mevcut kayıttan brüt
    _workDays = p.calismaGunu > 0 ? p.calismaGunu : 30;
  }

  Future<void> _loadSettings() async {
    setState(() => _loadingSettings = true);
    try {
      final list = await PayrollApi.fetchSettings();
      if (!mounted) return;
      _ps = list.isNotEmpty ? list.first : null;

      // Yerel override’ları oku (ayarlar ekranında kaydedilenler)
      final sp = await SharedPreferences.getInstance();
      _ovSgk = sp.getDouble('ps_sgk');
      _ovIss = sp.getDouble('ps_issizlik');
      _ovDam = sp.getDouble('ps_damga');

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bordro ayarı alınamadı: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingSettings = false);
    }
  }

  // --- Hesaplamalar ---
  double get _overtimePay => _otHours * _otRate;
  double get _earningsSum =>
      _items.where((i) => i.isEarning).fold(0.0, (s, i) => s + i.amount);
  double get _deductionsSum =>
      _items.where((i) => !i.isEarning).fold(0.0, (s, i) => s + i.amount);

  // Etkin oran (override varsa onu, yoksa API’den geleni kullan)
  double get _sgkRate => _ovSgk ?? _ps?.sgkKesintiOran ?? 0.0;
  double get _issizlikRate =>
      _ovIss ?? _ps?.issizlikSigortasiKesintiOran ?? 0.0;
  double get _damgaRate => _ovDam ?? _ps?.damgaVergisiOran ?? 0.0;

  double _totalRate() => _sgkRate + _issizlikRate + _damgaRate;

  // Mode → Gross/Net türet
  // gross = basePart + overtime + earnings
  // net   = gross - (gross * totalRate) - deductions
  double get _gross {
    switch (_mode) {
      case CalcMode.grossBase:
        return (_baseGross) + _overtimePay + _earningsSum;
      case CalcMode.netTarget:
        final t = _totalRate().clamp(0.0, 0.999999);
        final needGrossForNet = (_targetNet + _deductionsSum) / (1 - t);
        return needGrossForNet + _overtimePay + _earningsSum;
      case CalcMode.dailyNetTimesDays:
        final targetNet = (_dailyNet * _workDays);
        final t2 = _totalRate().clamp(0.0, 0.999999);
        final needGrossForNet2 = (targetNet + _deductionsSum) / (1 - t2);
        return needGrossForNet2 + _overtimePay + _earningsSum;
    }
  }

  double get _net {
    final gross = _gross;
    final taxes = gross * _totalRate();
    return gross - taxes - _deductionsSum;
  }

  double get _sgk => _gross * _sgkRate;
  double get _issizlik => _gross * _issizlikRate;
  double get _damga => _gross * _damgaRate;

  String _pct(num? v) => '${(((v ?? 0) * 100)).toStringAsFixed(2)}%';

  Future<void> _addItemDialog(bool isEarning) async {
    final nameCtrl = TextEditingController();
    final amtCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEarning ? 'Kazanç Ekle' : 'Kesinti Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Ad'),
            ),
            TextField(
              controller: amtCtrl,
              inputFormatters: _numFmt,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Tutar'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ekle')),
        ],
      ),
    );

    if (ok == true) {
      final name = nameCtrl.text.trim();
      final amount = double.tryParse(amtCtrl.text.replaceAll(',', '.')) ?? 0.0;
      if (name.isEmpty || amount <= 0) return;
      setState(() => _items
          .add(PayrollItem(name: name, amount: amount, isEarning: isEarning)));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final yil = _period.split('-').first; // "YYYY-MM" -> "YYYY"
    final nowIso = DateTime.now().toIso8601String();

    final payload = Payroll(
      id: widget.initial?.id, // düzenleme ise id’yi gönder
      personId: _personnelId,
      bodroDonem: _period,
      bodroYil: yil,
      islemTarihi: nowIso,

      // Hesaplanan alanlar
      brutUcret: _gross,
      netUcret: _net,
      gunlukUcret: (_workDays > 0 ? (_net / _workDays) : 0),
      calismaGunu: _workDays,

      // Vergi/primler (ayarlarla)
      gelirVergisi: 0, // şimdilik boş
      damgaVergisi: _damga,
      issizlikSigKes: _issizlik,
      besKesinti: 0,
      besOran: 0,
      ortGelirVergOran: 0,

      // meta
      odemeDurum: 'Bekliyor',
      kullaniciAdi: 'zeynep',
    );

    setState(() => _saving = true);
    try {
      if (widget.initial == null) {
        await PayrollApi.create(payload);
      } else {
        await PayrollApi.update(payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bordro kaydedildi')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydetme hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bordro Oluştur'),
        actions: [
          if (_loadingSettings)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Personel / dönem
              TextFormField(
                initialValue: _personnelId.toString(),
                decoration: const InputDecoration(labelText: 'Personel ID'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Geçerli ID' : null,
                onChanged: (v) =>
                    _personnelId = int.tryParse(v) ?? _personnelId,
              ),
              TextFormField(
                initialValue: _period,
                decoration: const InputDecoration(
                    hintText: 'YYYY-MM', labelText: 'Dönem'),
                validator: (v) =>
                    (v == null || !RegExp(r'^\d{4}-\d{2}$').hasMatch(v))
                        ? 'YYYY-MM formatında giriniz'
                        : null,
                onChanged: (v) => _period = v,
              ),

              const SizedBox(height: 16),
              // Hesaplama modu
              DropdownButtonFormField<CalcMode>(
                value: _mode,
                decoration: const InputDecoration(labelText: 'Hesaplama Modu'),
                items: const [
                  DropdownMenuItem(
                      value: CalcMode.grossBase, child: Text('Brüt taban')),
                  DropdownMenuItem(
                      value: CalcMode.netTarget, child: Text('Net hedefi')),
                  DropdownMenuItem(
                      value: CalcMode.dailyNetTimesDays,
                      child: Text('Günlük net × gün')),
                ],
                onChanged: (m) => setState(() => _mode = m ?? _mode),
              ),

              const SizedBox(height: 8),
              if (_mode == CalcMode.grossBase) ...[
                TextFormField(
                  initialValue: _baseGross.toString(),
                  inputFormatters: _numFmt,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Temel Brüt (₺)'),
                  validator: (v) =>
                      (double.tryParse((v ?? '').replaceAll(',', '.')) ?? -1) <
                              0
                          ? 'Geçerli tutar'
                          : null,
                  onChanged: (v) => setState(() => _baseGross =
                      double.tryParse(v.replaceAll(',', '.')) ?? 0),
                ),
              ] else if (_mode == CalcMode.netTarget) ...[
                TextFormField(
                  initialValue: _targetNet.toString(),
                  inputFormatters: _numFmt,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Net Hedef (₺)'),
                  validator: (v) =>
                      (double.tryParse((v ?? '').replaceAll(',', '.')) ?? -1) <
                              0
                          ? 'Geçerli tutar'
                          : null,
                  onChanged: (v) => setState(() => _targetNet =
                      double.tryParse(v.replaceAll(',', '.')) ?? 0),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _dailyNet.toString(),
                        inputFormatters: _numFmt,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Günlük Net (₺)'),
                        validator: (v) =>
                            (double.tryParse((v ?? '').replaceAll(',', '.')) ??
                                        -1) <
                                    0
                                ? 'Geçerli'
                                : null,
                        onChanged: (v) => setState(() => _dailyNet =
                            double.tryParse(v.replaceAll(',', '.')) ?? 0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: _workDays.toString(),
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Çalışma Günü'),
                        validator: (v) => (int.tryParse(v ?? '') ?? -1) <= 0
                            ? 'Geçerli'
                            : null,
                        onChanged: (v) => setState(
                            () => _workDays = int.tryParse(v) ?? _workDays),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              // Mesai
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _otHours.toString(),
                      inputFormatters: _numFmt,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Mesai Saat'),
                      validator: (v) =>
                          (double.tryParse((v ?? '').replaceAll(',', '.')) ??
                                      -1) <
                                  0
                              ? 'Geçerli'
                              : null,
                      onChanged: (v) => setState(() => _otHours =
                          double.tryParse(v.replaceAll(',', '.')) ?? 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _otRate.toString(),
                      inputFormatters: _numFmt,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Mesai Saat Ücreti'),
                      validator: (v) =>
                          (double.tryParse((v ?? '').replaceAll(',', '.')) ??
                                      -1) <
                                  0
                              ? 'Geçerli'
                              : null,
                      onChanged: (v) => setState(() => _otRate =
                          double.tryParse(v.replaceAll(',', '.')) ?? 0),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              // Kalemler
              Row(
                children: [
                  FilledButton(
                      onPressed: () => _addItemDialog(true),
                      child: const Text('Kazanç Ekle')),
                  const SizedBox(width: 8),
                  OutlinedButton(
                      onPressed: () => _addItemDialog(false),
                      child: const Text('Kesinti Ekle')),
                ],
              ),
              const SizedBox(height: 8),
              ..._items.map((i) => ListTile(
                    leading: Icon(i.isEarning
                        ? Icons.add_circle_outline
                        : Icons.remove_circle_outline),
                    title: Text(i.name),
                    subtitle: Text(i.isEarning ? 'Kazanç' : 'Kesinti'),
                    trailing: Text(i.amount.toStringAsFixed(2)),
                    onLongPress: () => setState(() => _items.remove(i)),
                  )),

              const Divider(),
              // Özet
              ListTile(
                  title: const Text('Brüt'),
                  trailing: Text(_gross.toStringAsFixed(2))),
              ListTile(
                  title: const Text('Net'),
                  trailing: Text(_net.toStringAsFixed(2))),
              ListTile(
                title: const Text('SGK'),
                subtitle: Text('Oran: ${_pct(_sgkRate)}'),
                trailing: Text(_sgk.toStringAsFixed(2)),
              ),
              ListTile(
                title: const Text('İşsizlik'),
                subtitle: Text('Oran: ${_pct(_issizlikRate)}'),
                trailing: Text(_issizlik.toStringAsFixed(2)),
              ),
              ListTile(
                title: const Text('Damga'),
                subtitle: Text('Oran: ${_pct(_damgaRate)}'),
                trailing: Text(_damga.toStringAsFixed(2)),
              ),

              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
