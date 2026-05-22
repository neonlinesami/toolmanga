class MangaTitle {
  final String id;
  final String name;
  final String slug;
  final String? coverImage;
  final String? description;
  final String type;
  final String status;
  final int? releaseYear;
  final double? averageRating;
  final int? totalChapters;
  final int? views;
  final int? weekViews;
  final List<String> genres;
  final List<String> altNames;
  final String? author;
  final String? artist;
  final bool isAdult;
  final int ageLimit;

  MangaTitle({
    required this.id,
    required this.name,
    required this.slug,
    this.coverImage,
    this.description,
    required this.type,
    required this.status,
    this.releaseYear,
    this.averageRating,
    this.totalChapters,
    this.views,
    this.weekViews,
    this.genres = const [],
    this.altNames = const [],
    this.author,
    this.artist,
    this.isAdult = false,
    this.ageLimit = 0,
  });

  factory MangaTitle.fromJson(Map<String, dynamic> json) {
    return MangaTitle(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      coverImage: json['coverImage'],
      description: json['description'],
      type: json['type'] ?? 'manga',
      status: json['status'] ?? 'ongoing',
      releaseYear: json['releaseYear'],
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      totalChapters: json['totalChapters'],
      views: json['views'],
      weekViews: json['weekViews'],
      genres: List<String>.from(json['genres'] ?? []),
      altNames: List<String>.from(json['altNames'] ?? []),
      author: json['author'],
      artist: json['artist'],
      isAdult: json['isAdult'] ?? false,
      ageLimit: json['ageLimit'] ?? 0,
    );
  }

  /// Разрешает coverImage в полный URL.
  /// API возвращает 4 варианта:
  ///   1. /uploads/titles/{id}/cover.jpg   → https://tomilo-lib.ru/uploads/...
  ///   2. /titles/{id}/cover.jpeg          → https://tomilo-lib.ru/titles/...
  ///   3. /uploads/covers/filename.png     → https://tomilo-lib.ru/uploads/covers/...
  ///   4. https://tomilolib.s3.regru.cloud → https://s3.regru.cloud/tomilolib/...
  String get coverUrl {
    const oldS3 = 'https://tomilolib.s3.regru.cloud';
    const s3Base = 'https://s3.regru.cloud/tomilolib';

    if (coverImage == null || coverImage!.isEmpty) {
      return '$s3Base/titles/$id/cover.jpg';
    }

    final img = coverImage!;

    // Уже полный старый S3 → переписываем на новый
    if (img.startsWith(oldS3)) {
      return img.replaceFirst(oldS3, s3Base);
    }

    // Уже полный новый S3 → оставляем
    if (img.startsWith(s3Base)) {
      return img;
    }

    // Любой другой полный URL → оставляем
    if (img.startsWith('https://') || img.startsWith('http://')) {
      return img;
    }

    // /uploads/titles/{id}/cover.* → убираем /uploads, кладём на S3
    final normalized = img.replaceFirst('/uploads', '');
    return '$s3Base$normalized';
  }

  String get typeLabel {
    switch (type) {
      case 'manga':   return 'Манга';
      case 'manhwa':  return 'Манхва';
      case 'manhua':  return 'Маньхуа';
      case 'comic':   return 'Комикс';
      default:        return type;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'ongoing':   return 'Выходит';
      case 'completed': return 'Завершён';
      case 'hiatus':    return 'Заморожен';
      case 'cancelled': return 'Отменён';
      default:          return status;
    }
  }
}
