class Personel {
  final int id;
  final String ad;
  final String soyad;
  final String gorev;
  final String eposta;
  final String tc;
  final bool aktif;

  Personel({
    required this.id,
    required this.ad,
    required this.soyad,
    required this.gorev,
    required this.eposta,
    this.tc = '',
    this.aktif = true,
  });

  String get adSoyad => [ad, soyad].where((s) => s.trim().isNotEmpty).join(' ');

  factory Personel.fromJson(Map<String, dynamic> j) => Personel(
        id: j['id'] ?? j['personelId'] ?? 0,
        ad: j['pAd'] ?? j['ad'] ?? '',
        soyad: j['pSoyad'] ?? j['soyad'] ?? '',
        gorev: j['pGorev'] ?? j['unvan'] ?? '',
        eposta: j['pIletisimEposta'] ?? j['email'] ?? '',
        tc: (j['pTc'] ?? '').toString(),
        aktif: (j['aktif'] ?? j['isActive'] ?? true) as bool,
      );
}
