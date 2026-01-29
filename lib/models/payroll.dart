class Payroll {
  final int? id;
  final int personId; // personid
  final String bodroDonem; // "YYYY-MM"
  final String bodroYil; // "YYYY" (Swagger'da string)
  final String islemTarihi; // "2025-08-29T00:00:00" gibi ISO string

  // Ücret & oran/kesintiler (UI'da double tut, JSON'da string gönder)
  final double brutUcret;
  final double netUcret;
  final double gunlukUcret;
  final int calismaGunu;

  final double gelirVergisi;
  final double damgaVergisi;
  final double issizlikSigKes; // issizlikSigKes
  final double besKesinti; // besKesinti
  final double besOran; // besOran
  final double ortGelirVergOran; // ortGelirVergOran

  // Opsiyoneller
  final String? agi; // asgari geçim indirimi (metin/string)
  final String? odemeDurum; // "Ödendi"/"Bekliyor" vb.
  final String? kullaniciAdi;
  final int? cariIslemId;
  final String? digerKesinti; // swagger string gösteriyor
  final String? kumuleVergiMatrahi;
  final int? puantajId;

  Payroll({
    this.id,
    required this.personId,
    required this.bodroDonem,
    required this.bodroYil,
    required this.islemTarihi,
    required this.brutUcret,
    required this.netUcret,
    required this.gunlukUcret,
    required this.calismaGunu,
    required this.gelirVergisi,
    required this.damgaVergisi,
    required this.issizlikSigKes,
    required this.besKesinti,
    required this.besOran,
    required this.ortGelirVergOran,
    this.agi,
    this.odemeDurum,
    this.kullaniciAdi,
    this.cariIslemId,
    this.digerKesinti,
    this.kumuleVergiMatrahi,
    this.puantajId,
  });

  // Backend bazen "0,14" gibi string döndürebiliyor; parse ederken nokta yapalım.
  static double _parseNum(dynamic v) {
    if (v == null) return 0.0;
    final s = v.toString().replaceAll(',', '.');
    return double.tryParse(s) ?? 0.0;
  }

  factory Payroll.fromJson(Map<String, dynamic> j) {
    return Payroll(
      id: j['id'] as int?,
      personId: j['personid'] ?? j['personId'] ?? 0,
      bodroDonem: j['bodroDonem']?.toString() ?? '',
      bodroYil: j['bodroYil']?.toString() ?? '',
      islemTarihi: j['islemTarihi']?.toString() ?? '',
      brutUcret: _parseNum(j['brutUcret']),
      netUcret: _parseNum(j['netUcret']),
      gunlukUcret: _parseNum(j['gunlukUcret']),
      calismaGunu: int.tryParse(j['calismaGunu']?.toString() ?? '0') ?? 0,
      gelirVergisi: _parseNum(j['gelirVergisi']),
      damgaVergisi: _parseNum(j['damgaVergisi']),
      issizlikSigKes: _parseNum(j['issizlikSigKes']),
      besKesinti: _parseNum(j['besKesinti']),
      besOran: _parseNum(j['besOran']),
      ortGelirVergOran: _parseNum(j['ortGelirVergOran']),
      agi: j['agi']?.toString(),
      odemeDurum: j['odemeDurum']?.toString(),
      kullaniciAdi: j['kullaniciAdi']?.toString(),
      cariIslemId: j['cariIslemId'] as int?,
      digerKesinti: j['digerKesinti']?.toString(),
      kumuleVergiMatrahi: j['kumuleVergiMatrahi']?.toString(),
      puantajId: j['puantajId'] as int?,
    );
  }

  // JSON’da SAYILARI string olarak gönderelim (Swagger öyle bekliyor gibi)
  Map<String, dynamic> toJson() {
    String s(num v) => v.toString(); // noktalı string

    return {
      if (id != null) 'id': id,
      'personid': personId,
      'bodroDonem': bodroDonem,
      'bodroYil': bodroYil,
      'islemTarihi': islemTarihi,
      'brutUcret': s(brutUcret),
      'netUcret': s(netUcret),
      'gunlukUcret': s(gunlukUcret),
      'calismaGunu': calismaGunu.toString(),
      'gelirVergisi': s(gelirVergisi),
      'damgaVergisi': s(damgaVergisi),
      'issizlikSigKes': s(issizlikSigKes),
      'besKesinti': s(besKesinti),
      'besOran': s(besOran),
      'ortGelirVergOran': s(ortGelirVergOran),
      if (agi != null) 'agi': agi,
      if (odemeDurum != null) 'odemeDurum': odemeDurum,
      if (kullaniciAdi != null) 'kullaniciAdi': kullaniciAdi,
      if (cariIslemId != null) 'cariIslemId': cariIslemId,
      if (digerKesinti != null) 'digerKesinti': digerKesinti,
      if (kumuleVergiMatrahi != null) 'kumuleVergiMatrahi': kumuleVergiMatrahi,
      if (puantajId != null) 'puantajId': puantajId,
    };
  }
}
