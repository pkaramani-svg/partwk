import '../core/utils/safe_parser.dart';

class Book {
  final String id;
  // Localized fields: keys are language codes ('en', 'ku', 'ar')
  final Map<String, String> title;
  final Map<String, String> author;
  final Map<String, String> coverImageUrlMap;
  final List<String> categoryIds;
  final List<String> tags;
  final Map<String, String> description;
  final Map<String, String> fiveMinuteSummary;
  final Map<String, String> fifteenMinuteSummary;
  
  // Structured chapter summaries: Map<LanguageCode, List<ChapterItem>>
  // Where ChapterItem is Map<String, dynamic> containing 'title', 'content', 'audioUrl', 'duration'
  final Map<String, List<Map<String, dynamic>>> chapterSummaries;
  
  // Lists of localized items
  final Map<String, List<String>> keyIdeas;
  final Map<String, List<String>> keyQuotes;
  final Map<String, List<String>> actionPoints;
  
  final Map<String, String> audioUrl;
  final int duration; // In seconds
  final bool isPremium;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> hiddenLanguages;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required dynamic coverImageUrl,
    required this.categoryIds,
    required this.tags,
    required this.description,
    required this.fiveMinuteSummary,
    required this.fifteenMinuteSummary,
    required this.chapterSummaries,
    required this.keyIdeas,
    required this.keyQuotes,
    required this.actionPoints,
    required this.audioUrl,
    required this.duration,
    required this.isPremium,
    required this.createdAt,
    required this.updatedAt,
    required this.hiddenLanguages,
  }) : coverImageUrlMap = coverImageUrl is Map
            ? SafeParser.asMapStringString(coverImageUrl)
            : {'en': coverImageUrl?.toString() ?? ''};

  String getTitle(String langCode) => title[langCode] ?? title['en'] ?? '';
  String getAuthor(String langCode) => author[langCode] ?? author['en'] ?? '';
  String getDescription(String langCode) => description[langCode] ?? description['en'] ?? '';
  String getFiveMinuteSummary(String langCode) => fiveMinuteSummary[langCode] ?? fiveMinuteSummary['en'] ?? '';
  String getFifteenMinuteSummary(String langCode) => fifteenMinuteSummary[langCode] ?? fifteenMinuteSummary['en'] ?? '';
  List<Map<String, dynamic>> getChapterSummaries(String langCode) => chapterSummaries[langCode] ?? chapterSummaries['en'] ?? [];
  List<String> getKeyIdeas(String langCode) => keyIdeas[langCode] ?? keyIdeas['en'] ?? [];
  List<String> getKeyQuotes(String langCode) => keyQuotes[langCode] ?? keyQuotes['en'] ?? [];
  List<String> getActionPoints(String langCode) => actionPoints[langCode] ?? actionPoints['en'] ?? [];
  String getAudioUrl(String langCode) => audioUrl[langCode] ?? audioUrl['en'] ?? '';
  
  String get coverImageUrl => coverImageUrlMap['en'] ?? coverImageUrlMap['ar'] ?? coverImageUrlMap.values.firstOrNull ?? '';
  String getCoverImageUrl(String langCode) => coverImageUrlMap[langCode] ?? coverImageUrl;

  bool hasContentForLanguage(String langCode) {
    return title.containsKey(langCode) && title[langCode]!.isNotEmpty;
  }

  int getDurationForLanguage(String langCode) {
    final chapters = getChapterSummaries(langCode);
    if (chapters.isEmpty) return duration; // Fallback to global duration
    
    int total = 0;
    for (var chap in chapters) {
      final dur = chap['duration'];
      if (dur is num) {
        total += dur.toInt();
      }
    }
    return total > 0 ? total : duration;
  }

  int getKeypointsCount(String langCode) {
    final chapters = getChapterSummaries(langCode);
    if (chapters.isEmpty) return 0;
    
    int count = 0;
    for (var chap in chapters) {
      final title = (chap['title'] ?? '').toString().toLowerCase();
      
      final isIntro = title.contains('introduction') || 
                      title.contains('intro') || 
                      title.contains('pêşekî') || 
                      title.contains('پێشەکی') || 
                      title.contains('مقدمة') ||
                      title.contains('موقەدەمە') || 
                      title.contains('دەستپێک');
                      
      final isConclusion = title.contains('conclusion') || 
                           title.contains('concl') || 
                           title.contains('کۆتایی') || 
                           title.contains('خاتمة') || 
                           title.contains('ئەنجام') || 
                           title.contains('پوختە');
                           
      if (!isIntro && !isConclusion) {
        count++;
      }
    }
    // If all chapters matched (returning 0), fallback to total chapters length
    return count > 0 ? count : chapters.length;
  }

  factory Book.fromMap(String id, Map<String, dynamic> data) {
    try {
      final Map<String, List<Map<String, dynamic>>> parsedChapterSummaries = {};
      final rawChapters = data['chapterSummaries'];
      if (rawChapters is Map) {
        rawChapters.forEach((key, value) {
          if (value is List) {
            final List<Map<String, dynamic>> chapList = [];
            for (var item in value) {
              if (item is Map) {
                final Map<String, dynamic> chapMap = {};
                item.forEach((k, v) {
                  if (k == 'segments' && v is List) {
                    chapMap[k] = v.map((seg) {
                      if (seg is Map) {
                        return seg.map((sk, sv) => MapEntry(sk.toString(), sv));
                      }
                      return seg;
                    }).toList();
                  } else if (v is Map) {
                    chapMap[k] = v.map((mk, mv) => MapEntry(mk.toString(), mv));
                  } else {
                    chapMap[k] = v;
                  }
                });
                chapList.add(chapMap);
              }
            }
            parsedChapterSummaries[key.toString()] = chapList;
          }
        });
      }

      final Map<String, List<String>> parsedKeyIdeas = {};
      final rawKeyIdeas = data['keyIdeas'];
      if (rawKeyIdeas is Map) {
        rawKeyIdeas.forEach((k, v) {
          if (v is List) {
            parsedKeyIdeas[k.toString()] = v.map((e) => e?.toString() ?? '').toList();
          }
        });
      }

      final Map<String, List<String>> parsedKeyQuotes = {};
      final rawKeyQuotes = data['keyQuotes'];
      if (rawKeyQuotes is Map) {
        rawKeyQuotes.forEach((k, v) {
          if (v is List) {
            parsedKeyQuotes[k.toString()] = v.map((e) => e?.toString() ?? '').toList();
          }
        });
      }

      final Map<String, List<String>> parsedActionPoints = {};
      final rawActionPoints = data['actionPoints'];
      if (rawActionPoints is Map) {
        rawActionPoints.forEach((k, v) {
          if (v is List) {
            parsedActionPoints[k.toString()] = v.map((e) => e?.toString() ?? '').toList();
          }
        });
      }

      return Book(
        id: id,
        title: SafeParser.asMapStringString(data['title']),
        author: SafeParser.asMapStringString(data['author']),
        coverImageUrl: data['coverImageUrl'],
        categoryIds: SafeParser.asListString(data['categoryIds']),
        tags: SafeParser.asListString(data['tags']),
        description: SafeParser.asMapStringString(data['description']),
        fiveMinuteSummary: SafeParser.asMapStringString(data['fiveMinuteSummary']),
        fifteenMinuteSummary: SafeParser.asMapStringString(data['fifteenMinuteSummary']),
        chapterSummaries: parsedChapterSummaries,
        keyIdeas: parsedKeyIdeas,
        keyQuotes: parsedKeyQuotes,
        actionPoints: parsedActionPoints,
        audioUrl: SafeParser.asMapStringString(data['audioUrl']),
        duration: data['duration'] is num ? (data['duration'] as num).toInt() : 0,
        isPremium: data['isPremium'] == true,
        hiddenLanguages: SafeParser.asListString(data['hiddenLanguages']),
        createdAt: data['createdAt'] != null
            ? (data['createdAt'] is String
                ? DateTime.tryParse(data['createdAt']) ?? DateTime.now()
                : DateTime.now())
            : DateTime.now(),
        updatedAt: data['updatedAt'] != null
            ? (data['updatedAt'] is String
                ? DateTime.tryParse(data['updatedAt']) ?? DateTime.now()
                : DateTime.now())
            : DateTime.now(),
      );
    } catch (e, stack) {
      print('=== Book.fromMap Parse Error for book ID $id ===');
      print('Error detail: $e');
      print('Stack trace: \n$stack');
      print('Raw data keys: ${data.keys.toList()}');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'coverImageUrl': coverImageUrlMap,
      'categoryIds': categoryIds,
      'tags': tags,
      'description': description,
      'fiveMinuteSummary': fiveMinuteSummary,
      'fifteenMinuteSummary': fifteenMinuteSummary,
      'chapterSummaries': chapterSummaries,
      'keyIdeas': keyIdeas,
      'keyQuotes': keyQuotes,
      'actionPoints': actionPoints,
      'audioUrl': audioUrl,
      'duration': duration,
      'isPremium': isPremium,
      'hiddenLanguages': hiddenLanguages,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
