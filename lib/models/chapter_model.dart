class Chapter {
  final String id;
  final String titleId;
  final int chapterNumber;
  final String name;
  final DateTime? releaseDate;
  final bool isPaid;
  final int unlockPrice;
  final DateTime? freeAt;
  final int views;
  final double? ratingSum;
  final int ratingCount;

  Chapter({
    required this.id,
    required this.titleId,
    required this.chapterNumber,
    required this.name,
    this.releaseDate,
    this.isPaid = false,
    this.unlockPrice = 0,
    this.freeAt,
    this.views = 0,
    this.ratingSum,
    this.ratingCount = 0,
  });

  // Геттер, который проверяет, заблокирована ли глава для пользователя.
  // Глава заблокирована, если она платная (isPaid), и время бесплатного доступа (freeAt)
  // либо еще не наступило, либо вообще не задано.
  bool get isLocked {
    if (!isPaid) return false;
    if (freeAt == null) return true;
    return DateTime.now().isBefore(freeAt!);
  }

  factory Chapter.fromJson(Map<String, dynamic> json) {
    String titleId = '';
    if (json['titleId'] is Map) {
      titleId = json['titleId']['_id'] ?? '';
    } else {
      titleId = json['titleId'] ?? '';
    }

    return Chapter(
      id: json['_id'] ?? '',
      titleId: titleId,
      chapterNumber: (json['chapterNumber'] as num?)?.toInt() ?? 0,
      name: json['name'] ?? 'Глава ${json['chapterNumber']}',
      releaseDate: json['releaseDate'] != null
          ? DateTime.tryParse(json['releaseDate'])
          : null,
      isPaid: json['isPaid'] ?? false,
      unlockPrice: (json['unlockPrice'] as num?)?.toInt() ?? 0,
      freeAt: json['freeAt'] != null ? DateTime.tryParse(json['freeAt']) : null,
      views: (json['views'] as num?)?.toInt() ?? 0,
      ratingSum: (json['ratingSum'] as num?)?.toDouble(),
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
    );
  }
} // <-- Вот эта скобка у вас отсутствовала!