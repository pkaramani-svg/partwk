import 'dart:convert';
import 'dart:io';

class Book {
  final String id;
  final Map<String, String> title;
  final Map<String, String> author;
  final Map<String, String> coverImageUrlMap;
  final List<String> categoryIds;
  final List<String> tags;
  final Map<String, String> description;
  final Map<String, String> fiveMinuteSummary;
  final Map<String, String> fifteenMinuteSummary;
  final Map<String, List<Map<String, dynamic>>> chapterSummaries;
  final Map<String, List<String>> keyIdeas;
  final Map<String, List<String>> keyQuotes;
  final Map<String, List<String>> actionPoints;
  final Map<String, String> audioUrl;
  final int duration;
  final bool isPremium;
  final DateTime createdAt;
  final DateTime updatedAt;

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
  }) : coverImageUrlMap = coverImageUrl is Map
            ? Map<String, String>.from(coverImageUrl)
            : {'en': coverImageUrl?.toString() ?? ''};

  static Map<String, String> _asMapStringString(dynamic map) {
    if (map == null || map is! Map) return {};
    return map.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  }

  static List<String> _asListString(dynamic list) {
    if (list == null || list is! List) return [];
    return list.map((e) => e?.toString() ?? '').toList();
  }

  factory Book.fromMap(String id, Map<String, dynamic> data) {
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
      title: _asMapStringString(data['title']),
      author: _asMapStringString(data['author']),
      coverImageUrl: data['coverImageUrl'],
      categoryIds: _asListString(data['categoryIds']),
      tags: _asListString(data['tags']),
      description: _asMapStringString(data['description']),
      fiveMinuteSummary: _asMapStringString(data['fiveMinuteSummary']),
      fifteenMinuteSummary: _asMapStringString(data['fifteenMinuteSummary']),
      chapterSummaries: parsedChapterSummaries,
      keyIdeas: parsedKeyIdeas,
      keyQuotes: parsedKeyQuotes,
      actionPoints: parsedActionPoints,
      audioUrl: _asMapStringString(data['audioUrl']),
      duration: data['duration'] is num ? (data['duration'] as num).toInt() : 0,
      isPremium: data['isPremium'] == true,
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
  }
}

dynamic fromFirestoreValue(Map<String, dynamic> fieldVal) {
  if (fieldVal.containsKey('stringValue')) return fieldVal['stringValue'];
  if (fieldVal.containsKey('integerValue')) return int.parse(fieldVal['integerValue']);
  if (fieldVal.containsKey('doubleValue')) return fieldVal['doubleValue'];
  if (fieldVal.containsKey('booleanValue')) return fieldVal['booleanValue'];
  if (fieldVal.containsKey('nullValue')) return null;
  if (fieldVal.containsKey('arrayValue')) {
    final list = fieldVal['arrayValue']['values'] as List?;
    if (list == null) return [];
    return list.map((v) => fromFirestoreValue(v as Map<String, dynamic>)).toList();
  }
  if (fieldVal.containsKey('mapValue')) {
    final fields = fieldVal['mapValue']['fields'] as Map<String, dynamic>?;
    if (fields == null) return {};
    return fields.map((k, v) => MapEntry(k, fromFirestoreValue(v as Map<String, dynamic>)));
  }
  return null;
}

Map<String, dynamic> fromFirestoreDoc(Map<String, dynamic> docData) {
  final fields = docData['fields'] as Map<String, dynamic>? ?? {};
  return fields.map((k, v) => MapEntry(k, fromFirestoreValue(v as Map<String, dynamic>)));
}

void main() async {
  final projectId = "partwk-bd4ec";
  final url = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/books";
  
  print("Connecting to Firestore REST API...");
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    final data = json.decode(responseBody) as Map<String, dynamic>;
    
    final docs = data['documents'] as List?;
    if (docs == null) {
      print("No documents found in response: $data");
      return;
    }
    
    print("Fetched ${docs.length} books. Checking each book parsing...");
    int successCount = 0;
    int failCount = 0;
    for (var doc in docs) {
      final docMap = doc as Map<String, dynamic>;
      final name = docMap['name'] as String;
      final docId = name.split('/').last;
      
      final bookData = fromFirestoreDoc(docMap);
      try {
        Book.fromMap(docId, bookData);
        successCount++;
      } catch (e, stack) {
        failCount++;
        print("  [ERROR] $docId failed to parse: $e");
        print(stack);
      }
    }
    print("Parsing check finished. Success: $successCount, Failures: $failCount");
  } catch (e) {
    print("Request failed: $e");
  } finally {
    client.close();
  }
}
