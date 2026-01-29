import 'package:flutter/foundation.dart';

@immutable
class Attachment {
  final int id;
  final int personnelId;
  final String fileName;
  final String url; // backend veriyorsa doldur
  final DateTime createdAt;

  const Attachment({
    required this.id,
    required this.personnelId,
    required this.fileName,
    required this.url,
    required this.createdAt,
  });

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        id: j['id'] is String ? int.parse(j['id']) : (j['id'] ?? 0),
        personnelId: j['personnelId'] is String
            ? int.parse(j['personnelId'])
            : (j['personnelId'] ?? 0),
        fileName: j['fileName'] ?? j['filename'] ?? '',
        url: j['url'] ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'personnelId': personnelId,
        'fileName': fileName,
        'url': url,
        'createdAt': createdAt.toIso8601String(),
      };
}
