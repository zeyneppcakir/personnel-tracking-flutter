class PayrollSetting {
  final int id;
  final double sgkKesintiOran; // örn 0.14
  final double issizlikSigortasiKesintiOran; // örn 0.01
  final double damgaVergisiOran; // örn 0.00759

  PayrollSetting({
    required this.id,
    required this.sgkKesintiOran,
    required this.issizlikSigortasiKesintiOran,
    required this.damgaVergisiOran,
  });

  factory PayrollSetting.fromJson(Map<String, dynamic> j) {
    // Swagger bazı oranları "0,14" gibi string/virgüllü döndürüyor olabilir
    double _toDouble(dynamic v) {
      if (v == null) return 0.0;
      final s = v.toString().replaceAll(',', '.');
      return double.tryParse(s) ?? 0.0;
    }

    return PayrollSetting(
      id: j['id'] ?? 0,
      sgkKesintiOran: _toDouble(j['sgkKesintiOran']),
      issizlikSigortasiKesintiOran:
          _toDouble(j['issizlikSigortasikesintiOran']),
      damgaVergisiOran: _toDouble(j['damgaVergisiOran']),
    );
  }
}
