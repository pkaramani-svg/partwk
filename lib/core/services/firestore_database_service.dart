import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart' as dio_client;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/book.dart';
import '../../models/category.dart';
import '../../models/quiz.dart';
import '../../models/flashcard.dart';
import '../../models/note.dart';
import '../../models/highlight.dart';
import '../../models/learning_path.dart';
import '../../models/achievement.dart';
import '../../services/download_service.dart';
import 'database_service.dart';
import 'network_guard.dart';

class FirestoreDatabaseService extends DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Category> _categories = [];
  List<Book> _books = [];
  List<LearningPath> _learningPaths = [];
  List<Achievement> _achievements = [];
  String _currentLangCode = 'en';

  FirestoreDatabaseService() {
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  @override
  List<Category> get categories => _categories;
  @override
  List<Book> get books => _books.where((b) => !b.hiddenLanguages.contains(_currentLangCode)).toList();
  @override
  List<LearningPath> get learningPaths => _learningPaths;
  @override
  List<Achievement> get achievements => _achievements;

  Future<List<Map<String, dynamic>>> _fetchCollectionRest(String collectionName) async {
    final dio = dio_client.Dio();
    final projectId = "partwk-bd4ec";
    final url = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collectionName?pageSize=100";
    
    try {
      final response = await dio.get(url);
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final docs = data['documents'] as List?;
        if (docs == null) return [];
        
        final List<Map<String, dynamic>> results = [];
        for (var doc in docs) {
          final docMap = doc as Map<String, dynamic>;
          final name = docMap['name'] as String;
          final docId = name.split('/').last;
          
          final fieldsData = _fromFirestoreDoc(docMap);
          fieldsData['id'] = docId; // save ID inside map
          results.add(fieldsData);
        }
        return results;
      }
    } catch (e) {
      print('REST fallback error for $collectionName: $e');
    }
    return [];
  }

  dynamic _fromFirestoreValue(Map<String, dynamic> fieldVal) {
    if (fieldVal.containsKey('stringValue')) return fieldVal['stringValue'];
    if (fieldVal.containsKey('integerValue')) return int.parse(fieldVal['integerValue']);
    if (fieldVal.containsKey('doubleValue')) return fieldVal['doubleValue'];
    if (fieldVal.containsKey('booleanValue')) return fieldVal['booleanValue'];
    if (fieldVal.containsKey('nullValue')) return null;
    if (fieldVal.containsKey('arrayValue')) {
      final list = fieldVal['arrayValue']['values'] as List?;
      if (list == null) return [];
      return list.map((v) => _fromFirestoreValue(v as Map<String, dynamic>)).toList();
    }
    if (fieldVal.containsKey('mapValue')) {
      final fields = fieldVal['mapValue']['fields'] as Map<String, dynamic>?;
      if (fields == null) return {};
      return fields.map((k, v) => MapEntry(k, _fromFirestoreValue(v as Map<String, dynamic>)));
    }
    return null;
  }

  Map<String, dynamic> _fromFirestoreDoc(Map<String, dynamic> docData) {
    final fields = docData['fields'] as Map<String, dynamic>? ?? {};
    return fields.map((k, v) => MapEntry(k, _fromFirestoreValue(v as Map<String, dynamic>)));
  }

  @override
  Future<List<Book>> fetchBooks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentLangCode = prefs.getString('language_code') ?? 'en';

      final hasInternet = await NetworkGuard.hasConnection();
      final snapshot = await _firestore.collection('books').get(
        GetOptions(source: hasInternet ? Source.serverAndCache : Source.cache),
      );
      final firestoreBooks = snapshot.docs.map((doc) => Book.fromMap(doc.id, doc.data())).toList();

      // Merge with downloaded books to ensure they are always present
      final downloaded = await DownloadService().getDownloadedBooks();
      final Map<String, Book> merged = {};
      for (var b in firestoreBooks) {
        merged[b.id] = b;
      }
      for (var b in downloaded) {
        merged[b.id] = b;
      }
      
      // Deduplicate by English title to prevent duplicate cached entries
      final Map<String, Book> uniqueByTitle = {};
      for (var b in merged.values) {
        final titleEn = b.title['en']?.toLowerCase() ?? b.id;
        uniqueByTitle[titleEn] = b;
      }
      _books = uniqueByTitle.values.toList();
      return books;
    } catch (e) {
      print('Error fetching books: $e');
      
      // Try REST API fallback if online
      final hasInternet = await NetworkGuard.hasConnection();
      if (hasInternet) {
        try {
          final restDocs = await _fetchCollectionRest('books');
          if (restDocs.isNotEmpty) {
            final List<Book> restBooks = restDocs.map((data) {
              final id = data['id'] as String;
              return Book.fromMap(id, data);
            }).toList();
            
            final downloaded = await DownloadService().getDownloadedBooks();
            final Map<String, Book> merged = {};
            for (var b in restBooks) {
              merged[b.id] = b;
            }
            for (var b in downloaded) {
              merged[b.id] = b;
            }
            
            final Map<String, Book> uniqueByTitle = {};
            for (var b in merged.values) {
              final titleEn = b.title['en']?.toLowerCase() ?? b.id;
              uniqueByTitle[titleEn] = b;
            }
            _books = uniqueByTitle.values.toList();
            return books;
          }
        } catch (restEx) {
          print('REST fallback for books failed: $restEx');
        }
      }

      try {
        final offline = await DownloadService().getDownloadedBooks();
        if (offline.isNotEmpty) {
          final Map<String, Book> uniqueByTitle = {};
          for (var b in offline) {
            final titleEn = b.title['en']?.toLowerCase() ?? b.id;
            uniqueByTitle[titleEn] = b;
          }
          _books = uniqueByTitle.values.toList();
          return books;
        }
      } catch (ex) {
        print('Error fetching offline books: $ex');
      }
      return [];
    }
  }

  @override
  Future<List<Category>> fetchCategories() async {
    try {
      final hasInternet = await NetworkGuard.hasConnection();
      final snapshot = await _firestore.collection('categories').get(
        GetOptions(source: hasInternet ? Source.serverAndCache : Source.cache),
      );
      _categories = snapshot.docs.map((doc) => Category.fromMap(doc.id, doc.data())).toList();
      return _categories;
    } catch (e) {
      print('Error fetching categories: $e');
      
      final hasInternet = await NetworkGuard.hasConnection();
      if (hasInternet) {
        try {
          final restDocs = await _fetchCollectionRest('categories');
          if (restDocs.isNotEmpty) {
            _categories = restDocs.map((data) {
              final id = data['id'] as String;
              return Category.fromMap(id, data);
            }).toList();
            return _categories;
          }
        } catch (restEx) {
          print('REST fallback for categories failed: $restEx');
        }
      }
      
      return [];
    }
  }

  @override
  Future<List<LearningPath>> fetchLearningPaths() async {
    try {
      final hasInternet = await NetworkGuard.hasConnection();
      final snapshot = await _firestore.collection('learning_paths').get(
        GetOptions(source: hasInternet ? Source.serverAndCache : Source.cache),
      );
      _learningPaths = snapshot.docs.map((doc) => LearningPath.fromMap(doc.id, doc.data())).toList();
      return _learningPaths;
    } catch (e) {
      print('Error fetching learning paths: $e');
      
      final hasInternet = await NetworkGuard.hasConnection();
      if (hasInternet) {
        try {
          final restDocs = await _fetchCollectionRest('learning_paths');
          if (restDocs.isNotEmpty) {
            _learningPaths = restDocs.map((data) {
              final id = data['id'] as String;
              return LearningPath.fromMap(id, data);
            }).toList();
            return _learningPaths;
          }
        } catch (restEx) {
          print('REST fallback for learning paths failed: $restEx');
        }
      }
      
      return [];
    }
  }

  @override
  Future<List<Achievement>> fetchAchievements() async {
    try {
      final hasInternet = await NetworkGuard.hasConnection();
      final snapshot = await _firestore.collection('achievements').get(
        GetOptions(source: hasInternet ? Source.serverAndCache : Source.cache),
      );
      if (snapshot.docs.isNotEmpty) {
        _achievements = snapshot.docs.map((doc) => Achievement.fromMap(doc.id, doc.data())).toList();
      } else {
        // Fallback static list
        _achievements = [
          Achievement(
            id: 'ach-books-1',
            title: {'en': 'First Step', 'ku': 'یەکەم هەنگاو', 'ar': 'الخطوة الأولى'},
            description: {'en': 'Completed your first book summary.', 'ku': 'یەکەم کورتە کتێبت تەواو کرد.', 'ar': 'أكملت أول ملخص كتاب.'},
            badgeIcon: 'rocket_launch',
          ),
          Achievement(
            id: 'ach-books-5',
            title: {'en': 'Avid Reader', 'ku': 'خوێنەری تامەزرۆ', 'ar': 'قارئ نهم'},
            description: {'en': 'Completed 5 book summaries.', 'ku': '٥ کورتە کتێبت تەواو کرد.', 'ar': 'أكملت 5 ملخصات كتب.'},
            badgeIcon: 'auto_stories',
          ),
          Achievement(
            id: 'ach-books-10',
            title: {'en': 'Bookworm', 'ku': 'کتێب دۆست', 'ar': 'دودة كتب'},
            description: {'en': 'Completed 10 book summaries.', 'ku': '١٠ کورتە کتێبت تەواو کرد.', 'ar': 'أكملت 10 ملخصات كتب.'},
            badgeIcon: 'library_books',
          ),
          Achievement(
            id: 'ach-books-25',
            title: {'en': 'Scholar', 'ku': 'زانا', 'ar': 'باحث'},
            description: {'en': 'Completed 25 book summaries.', 'ku': '٢٥ کورتە کتێبت تەواو کرد.', 'ar': 'أكملت 25 ملخص كتاب.'},
            badgeIcon: 'menu_book',
          ),
          Achievement(
            id: 'ach-books-50',
            title: {'en': 'Master', 'ku': 'مامۆستا', 'ar': 'سيد'},
            description: {'en': 'Completed 50 book summaries.', 'ku': '٥٠ کورتە کتێبت تەواو کرد.', 'ar': 'أكملت 50 ملخص كتاب.'},
            badgeIcon: 'school',
          ),
          Achievement(
            id: 'ach-books-100',
            title: {'en': 'Grandmaster', 'ku': 'مامۆستای گەورە', 'ar': 'السيد الأكبر'},
            description: {'en': 'Completed 100 book summaries.', 'ku': '١٠٠ کورتە کتێبت تەواو کرد.', 'ar': 'أكملت 100 ملخص كتاب.'},
            badgeIcon: 'account_balance',
          ),
          Achievement(
            id: 'ach-streak-3',
            title: {'en': 'Consistency King', 'ku': 'پاشای بەردەوامی', 'ar': 'ملك الاستمرارية'},
            description: {'en': 'Maintained a 3-day streak.', 'ku': 'بەردەوامی بۆ ٣ ڕۆژ.', 'ar': 'حافظت على سلسلة من 3 أيام.'},
            badgeIcon: 'local_fire_department',
          ),
          Achievement(
            id: 'ach-streak-7',
            title: {'en': 'On Fire', 'ku': 'لە جۆشدا', 'ar': 'مشتعل'},
            description: {'en': 'Maintained a 7-day streak.', 'ku': 'بەردەوامی بۆ ٧ ڕۆژ.', 'ar': 'حافظت على سلسلة من 7 أيام.'},
            badgeIcon: 'whatshot',
          ),
          Achievement(
            id: 'ach-streak-14',
            title: {'en': 'Unstoppable', 'ku': 'وەستێنەنەکراو', 'ar': 'لا يمكن إيقافه'},
            description: {'en': 'Maintained a 14-day streak.', 'ku': 'بەردەوامی بۆ ١٤ ڕۆژ.', 'ar': 'حافظت على سلسلة من 14 يومًا.'},
            badgeIcon: 'bolt',
          ),
          Achievement(
            id: 'ach-streak-30',
            title: {'en': 'Legendary', 'ku': 'ئەفسانەیی', 'ar': 'أسطوري'},
            description: {'en': 'Maintained a 30-day streak.', 'ku': 'بەردەوامی بۆ ٣٠ ڕۆژ.', 'ar': 'حافظت على سلسلة من 30 يومًا.'},
            badgeIcon: 'star',
          ),
          Achievement(
            id: 'ach-streak-100',
            title: {'en': 'Immortal', 'ku': 'نەمر', 'ar': 'خالد'},
            description: {'en': 'Maintained a 100-day streak.', 'ku': 'بەردەوامی بۆ ١٠٠ ڕۆژ.', 'ar': 'حافظت على سلسلة من 100 يومًا.'},
            badgeIcon: 'workspace_premium',
          ),
          Achievement(
            id: 'ach-saved-1',
            title: {'en': 'Curious', 'ku': 'چاوکراوە', 'ar': 'فضولي'},
            description: {'en': 'Saved 1 book.', 'ku': '١ کتێبت پاشەکەوت کرد.', 'ar': 'حفظت كتابًا واحدًا.'},
            badgeIcon: 'bookmark_add',
          ),
          Achievement(
            id: 'ach-saved-10',
            title: {'en': 'Collector', 'ku': 'کۆکەرەوە', 'ar': 'جامع'},
            description: {'en': 'Saved 10 books.', 'ku': '١٠ کتێبت پاشەکەوت کرد.', 'ar': 'حفظت 10 كتب.'},
            badgeIcon: 'bookmarks',
          ),
          Achievement(
            id: 'ach-saved-50',
            title: {'en': 'Librarian', 'ku': 'کتێبخانەوان', 'ar': 'أمين مكتبة'},
            description: {'en': 'Saved 50 books.', 'ku': '٥٠ کتێبت پاشەکەوت کرد.', 'ar': 'حفظت 50 كتابًا.'},
            badgeIcon: 'collections_bookmark',
          ),
          Achievement(
            id: 'ach-liked-1',
            title: {'en': 'Fan', 'ku': 'هەوادار', 'ar': 'معجب'},
            description: {'en': 'Liked 1 book.', 'ku': '١ کتێبت بەدڵ بوو.', 'ar': 'أعجبت بكتاب واحد.'},
            badgeIcon: 'favorite_border',
          ),
          Achievement(
            id: 'ach-liked-10',
            title: {'en': 'Enthusiast', 'ku': 'پەرۆش', 'ar': 'متحمس'},
            description: {'en': 'Liked 10 books.', 'ku': '١٠ کتێبت بەدڵ بوو.', 'ar': 'أعجبت بـ 10 كتب.'},
            badgeIcon: 'favorite',
          ),
          Achievement(
            id: 'ach-liked-50',
            title: {'en': 'Superfan', 'ku': 'هەواداری سەرسەخت', 'ar': 'معجب كبير'},
            description: {'en': 'Liked 50 books.', 'ku': '٥٠ کتێبت بەدڵ بوو.', 'ar': 'أعجبت بـ 50 كتابًا.'},
            badgeIcon: 'volunteer_activism',
          ),
          Achievement(
            id: 'ach-polyglot-2',
            title: {'en': 'Bilingual Explorer', 'ku': 'گەڕیدەی دووزمان', 'ar': 'مستكشف ثنائي اللغة'},
            description: {'en': 'Used 2 different languages.', 'ku': '٢ زمانی جیاوازت بەکارهێنا.', 'ar': 'استخدمت لغتين مختلفتين.'},
            badgeIcon: 'translate',
          ),
          Achievement(
            id: 'ach-polyglot-3',
            title: {'en': 'Polyglot', 'ku': 'فرەزمان', 'ar': 'متعدد اللغات'},
            description: {'en': 'Used 3 different languages.', 'ku': '٣ زمانی جیاوازت بەکارهێنا.', 'ar': 'استخدمت 3 لغات مختلفة.'},
            badgeIcon: 'language',
          ),
          Achievement(
            id: 'ach-time-1',
            title: {'en': 'Focused', 'ku': 'تەرکیزکراو', 'ar': 'مركز'},
            description: {'en': 'Studied for 1 hour.', 'ku': 'بۆ ١ کاتژمێر خوێندت.', 'ar': 'درست لمدة ساعة.'},
            badgeIcon: 'timer',
          ),
          Achievement(
            id: 'ach-time-10',
            title: {'en': 'Dedicated', 'ku': 'تەرخانکراو', 'ar': 'متفان'},
            description: {'en': 'Studied for 10 hours.', 'ku': 'بۆ ١٠ کاتژمێر خوێندت.', 'ar': 'درست لمدة 10 ساعات.'},
            badgeIcon: 'hourglass_bottom',
          ),
          Achievement(
            id: 'ach-time-50',
            title: {'en': 'Relentless', 'ku': 'بێ وچان', 'ar': 'لا هوادة فيه'},
            description: {'en': 'Studied for 50 hours.', 'ku': 'بۆ ٥٠ کاتژمێر خوێندت.', 'ar': 'درست لمدة 50 ساعة.'},
            badgeIcon: 'access_time_filled',
          ),
          Achievement(
            id: 'ach-cat-business',
            title: {'en': 'Entrepreneur', 'ku': 'خاوەنکار', 'ar': 'رائد أعمال'},
            description: {'en': 'Completed a Business book.', 'ku': 'کتێبێکی بازرگانیت تەواو کرد.', 'ar': 'أكملت كتابًا في الأعمال.'},
            badgeIcon: 'business_center',
          ),
          Achievement(
            id: 'ach-cat-history',
            title: {'en': 'Historian', 'ku': 'مێژوونووس', 'ar': 'مؤرخ'},
            description: {'en': 'Completed a History & Big Ideas book.', 'ku': 'کتێبێکی مێژوویی و بیرۆکە گەورەکانت تەواو کرد.', 'ar': 'أكملت كتابًا في التاريخ والأفكار الكبرى.'},
            badgeIcon: 'account_balance',
          ),
          Achievement(
            id: 'ach-cat-psychology',
            title: {'en': 'Psychologist', 'ku': 'دەروونناس', 'ar': 'عالم نفس'},
            description: {'en': 'Completed a Psychology book.', 'ku': 'کتێبێکی دەروونناسیت تەواو کرد.', 'ar': 'أكملت كتابًا في علم النفس.'},
            badgeIcon: 'psychology',
          ),
          // Backwards compatible old mock keys if needed
          Achievement(
            id: 'ach-first-step',
            title: {'en': 'First Ascent', 'ku': 'یەکەم هەنگاو', 'ar': 'الخطوة الأولى'},
            description: {'en': 'Completed your first book summary reading or audio session.', 'ku': 'یەکەم کورتە کتێبت خوێندەوە یان گوێ لێ گرت.', 'ar': 'أكملت أول قراءة لملخص كتاب أو جلسة استماع صوتية.'},
            badgeIcon: 'rocket_launch',
          ),
          Achievement(
            id: 'ach-streak-three',
            title: {'en': 'Consistency King', 'ku': 'پاشای بەردەوامی', 'ar': 'ملك الاستمرارية'},
            description: {'en': 'Maintain a 3-day learning streak.', 'ku': 'پاراستنی ٣ ڕۆژ لە بەردەوامیی فێربوون.', 'ar': 'حافظ على سلسلة تعلم متتالية لمدة 3 أيام.'},
            badgeIcon: 'local_fire_department',
          ),
          Achievement(
            id: 'ach-polyglot',
            title: {'en': 'Bilingual Explorer', 'ku': 'گەڕیدەی فرەزمان', 'ar': 'المستكشف متعدد اللغات'},
            description: {'en': 'Switch languages to study translations in English, Kurdish, or Arabic.', 'ku': 'گۆڕینی زمانی ئەپەکە بۆ خوێندنی وەرگێڕانەکان.', 'ar': 'قم بتبديل اللغات لدراسة التراجم بالإنجليزية، أو الكردية، أو العربية.'},
            badgeIcon: 'translate',
          )
        ];
      }
      return _achievements;
    } catch (e) {
      print('Error fetching achievements: $e');
      
      final hasInternet = await NetworkGuard.hasConnection();
      if (hasInternet) {
        try {
          final restDocs = await _fetchCollectionRest('achievements');
          if (restDocs.isNotEmpty) {
            _achievements = restDocs.map((data) {
              final id = data['id'] as String;
              return Achievement.fromMap(id, data);
            }).toList();
            return _achievements;
          }
        } catch (restEx) {
          print('REST fallback for achievements failed: $restEx');
        }
      }
      
      return [];
    }
  }

  @override
  Future<Quiz?> fetchQuizForBook(String bookId, String langCode) async {
    try {
      final hasInternet = await NetworkGuard.hasConnection();
      final snapshot = await _firestore.collection('quizzes')
        .where('bookId', isEqualTo: bookId)
        .where('langCode', isEqualTo: langCode)
        .limit(1)
        .get(
          GetOptions(source: hasInternet ? Source.serverAndCache : Source.cache),
        );
      if (snapshot.docs.isNotEmpty) {
        return Quiz.fromMap(snapshot.docs.first.id, snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error fetching quiz: $e');
      return null;
    }
  }

  @override
  Future<List<Flashcard>> fetchFlashcardsForBook(String bookId, String langCode) async {
    try {
      final hasInternet = await NetworkGuard.hasConnection();
      final snapshot = await _firestore.collection('flashcards')
        .where('bookId', isEqualTo: bookId)
        .where('langCode', isEqualTo: langCode)
        .get(
          GetOptions(source: hasInternet ? Source.serverAndCache : Source.cache),
        );
      return snapshot.docs.map((doc) => Flashcard.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      print('Error fetching flashcards: $e');
      return [];
    }
  }

  @override
  Future<List<Note>> fetchNotes(String userId) async {
    try {
      final hasInternet = await NetworkGuard.hasConnection();
      final snapshot = await _firestore.collection('notes')
        .where('userId', isEqualTo: userId)
        .get(
          GetOptions(source: hasInternet ? Source.serverAndCache : Source.cache),
        );
      return snapshot.docs.map((doc) => Note.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      print('Error fetching notes: $e');
      return [];
    }
  }

  @override
  Future<void> addNote(Note note) async {
    await _firestore.collection('notes').doc(note.id).set(note.toMap());
    notifyListeners();
  }

  @override
  Future<void> deleteNote(String noteId) async {
    await _firestore.collection('notes').doc(noteId).delete();
    notifyListeners();
  }

  @override
  Future<List<Highlight>> fetchHighlights(String userId) async {
    try {
      final hasInternet = await NetworkGuard.hasConnection();
      final snapshot = await _firestore.collection('highlights')
        .where('userId', isEqualTo: userId)
        .get(
          GetOptions(source: hasInternet ? Source.serverAndCache : Source.cache),
        );
      return snapshot.docs.map((doc) => Highlight.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      print('Error fetching highlights: $e');
      return [];
    }
  }

  @override
  Future<void> addHighlight(Highlight highlight) async {
    await _firestore.collection('highlights').doc(highlight.id).set(highlight.toMap());
    notifyListeners();
  }

  @override
  Future<void> deleteHighlight(String highlightId) async {
    await _firestore.collection('highlights').doc(highlightId).delete();
    notifyListeners();
  }

  @override
  Future<void> addBook(Book book) async {
    await _firestore.collection('books').doc(book.id).set(book.toMap());
    _books.add(book);
    notifyListeners();
  }

  @override
  Future<void> addQuiz(Quiz quiz) async {
    await _firestore.collection('quizzes').doc(quiz.id).set(quiz.toMap());
    notifyListeners();
  }

  @override
  Future<void> updateTranslations(String key, String enVal, String kuVal, String arVal) async {
    // Implement global translation dictionary update via Firestore
  }
}
