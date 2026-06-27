import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/book.dart';
import '../../models/category.dart';
import '../../models/quiz.dart';
import '../../models/flashcard.dart';
import '../../models/note.dart';
import '../../models/highlight.dart';
import '../../models/learning_path.dart';
import '../../models/achievement.dart';

abstract class DatabaseService extends ChangeNotifier {
  List<Category> get categories;
  List<Book> get books;
  List<LearningPath> get learningPaths;
  List<Achievement> get achievements;

  Future<List<Book>> fetchBooks();
  Future<List<Category>> fetchCategories();
  Future<List<LearningPath>> fetchLearningPaths();
  Future<List<Achievement>> fetchAchievements();
  Future<Quiz?> fetchQuizForBook(String bookId, String langCode);
  Future<List<Flashcard>> fetchFlashcardsForBook(String bookId, String langCode);
  
  // Notes & Highlights
  Future<List<Note>> fetchNotes(String userId);
  Future<void> addNote(Note note);
  Future<void> deleteNote(String noteId);
  Future<List<Highlight>> fetchHighlights(String userId);
  Future<void> addHighlight(Highlight highlight);
  Future<void> deleteHighlight(String highlightId);

  // Admin writes
  Future<void> addBook(Book book);
  Future<void> addQuiz(Quiz quiz);
  Future<void> updateTranslations(String key, String enVal, String kuVal, String arVal);
}

class MockDatabaseService extends DatabaseService {
  final List<Category> _categories = [];
  final List<Book> _books = [];
  final List<LearningPath> _learningPaths = [];
  final List<Achievement> _achievements = [];
  final List<Quiz> _quizzes = [];
  
  final List<Note> _notes = [];
  final List<Highlight> _highlights = [];

  String _currentLangCode = 'en';

  @override
  List<Category> get categories => _categories;
  @override
  List<Book> get books => _books.where((b) => !b.hiddenLanguages.contains(_currentLangCode)).toList();
  @override
  List<LearningPath> get learningPaths => _learningPaths;
  @override
  List<Achievement> get achievements => _achievements;

  MockDatabaseService() {
    _initMockData();
  }

  void _initMockData() {
    // Categories
    _categories.addAll([
      Category(id: 'cat-productivity', name: {'en': 'Productivity', 'ku': 'بەرهەمهێنان', 'ar': 'الإنتاجية'}, iconName: 'bolt'),
      Category(id: 'cat-psychology', name: {'en': 'Psychology', 'ku': 'دەروونناسی', 'ar': 'علم النفس'}, iconName: 'psychology'),
      Category(id: 'cat-personal-development', name: {'en': 'Personal Development', 'ku': 'گەشەپێدانی کەسی', 'ar': 'التطوير الشخصي'}, iconName: 'self_improvement'),
      Category(id: 'cat-business', name: {'en': 'Business', 'ku': 'بازرگانی', 'ar': 'أعمال'}, iconName: 'business_center'),
      Category(id: 'cat-leadership', name: {'en': 'Leadership', 'ku': 'سەرکردایەتی', 'ar': 'القيادة'}, iconName: 'stars'),
      Category(id: 'cat-money-investing', name: {'en': 'Money & Investing', 'ku': 'پارە و وەبەرهێنان', 'ar': 'المال والاستثمار'}, iconName: 'attach_money'),
      Category(id: 'cat-communication', name: {'en': 'Communication', 'ku': 'پەیوەندی', 'ar': 'التواصل'}, iconName: 'chat'),
      Category(id: 'cat-health-wellness', name: {'en': 'Health & Wellness', 'ku': 'تەندروستی و باشی', 'ar': 'الصحة والعافية'}, iconName: 'health_and_safety'),
      Category(id: 'cat-entrepreneurship', name: {'en': 'Entrepreneurship', 'ku': 'کارسازی', 'ar': 'ريادة الأعمال'}, iconName: 'rocket_launch'),
      Category(id: 'cat-technology-innovation', name: {'en': 'Technology & Innovation', 'ku': 'تەکنەلۆژیا و داهێنان', 'ar': 'التكنولوجيا والابتكار'}, iconName: 'lightbulb'),
      Category(id: 'cat-biography-memoir', name: {'en': 'Biography & Memoir', 'ku': 'ژیاننامە و یادەوەری', 'ar': 'السيرة الذاتية والمذكرات'}, iconName: 'menu_book'),
      Category(id: 'cat-modern-wisdom', name: {'en': 'Modern Wisdom', 'ku': 'دانایی مۆدێرن', 'ar': 'الحكمة الحديثة'}, iconName: 'auto_awesome'),
      Category(id: 'cat-history-big-ideas', name: {'en': 'History & Big Ideas', 'ku': 'مێژوو و بیرۆکە گەورەکان', 'ar': 'التاريخ والأفكار الكبيرة'}, iconName: 'account_balance'),
    ]);

    // Preloaded books (Original, non-copyrighted summaries)
    _books.addAll([
      Book(
        id: 'book-focus',
        title: {
          'en': 'The Art of Relentless Focus',
          'ku': 'هونەری سەرنجدانی بێوچان',
          'ar': 'فن التركيز المتواصل'
        },
        author: {
          'en': 'Darren Vance',
          'ku': 'دارین ڤانس',
          'ar': 'دارين فانس'
        },
        coverImageUrl: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?q=80&w=400',
        categoryIds: ['cat-productivity'],
        tags: ['focus', 'productivity', 'success'],
        description: {
          'en': 'A practical blueprint for eliminating distractions and achieving deep cognitive flow in a hyper-connected world.',
          'ku': 'نەخشەڕێگەیەکی پراکتیکی بۆ نەهێشتنی سەرنجپەرشبوون و بەدەستهێنانی قووڵترین توانای عەقڵی لە جیهانێکی پڕ پەیوەندیدا.',
          'ar': 'مخطط عملي للتخلص من المشتتات وتحقيق التدفق الإدراكي العميق في عالم شديد الاتصال.'
        },
        fiveMinuteSummary: {
          'en': 'The core message is that human attention is a finite resource. In the digital age, our attention is constantly mined for profit by social media and notification engines. To regain agency, you must treat your attention as your most valuable asset. Set rigorous boundaries, structure your day into blocks of isolated work, and systematically filter out low-value inputs. Focus is not a talent; it is a muscle trained through intentional silence and routine.',
          'ku': 'پەیامی سەرەکی ئەوەیە کە سەرنجی مرۆڤ سەرچاوەیەکی سنووردارە. لە سەردەمی دیجیتاڵیدا، سەرنجمان بەردەوام بۆ قازانج بەکاردەهێنرێت لەلایەن تۆڕە کۆمەڵایەتییەکانەوە. بۆ بەدەستهێنانەوەی کۆنترۆڵ، پێویستە وەک بەهادارترین سامانی خۆت مامەڵە لەگەڵ سەرنجتدا بکەیت. سنووری توند دابنێ، ڕۆژەکەت دابەش بکە بەسەر کاتی کارکردنی جیاوازدا، و بە شێوازێکی سیستماتیکی زانیارییە کەم بەهاکان لاببە.',
          'ar': 'الرسالة الأساسية هي أن الانتباه البشري هو مورد محدود. في العصر الرقمي، يتم استخراج انتباهنا باستمرار لتحقيق الربح من خلال شبكات التواصل الاجتماعي ومحركات الإشعارات. لاستعادة السيطرة، يجب أن تعامل انتباهك كأثمن أصولك. ضع حدوداً صارمة، وقسم يومك إلى فترات عمل معزولة، وقم بتصفية المدخلات منخفضة القيمة بشكل منهجي. التركيز ليس موهبة؛ إنه عضلة تدرب من خلال الصمت المتعمد والروتين اليومي.'
        },
        fifteenMinuteSummary: {
          'en': 'Chapter 1: The Attention Economy. The digital environment is engineered to fragment our focus. Chapter 2: Deep Work Routines. High-quality output is directly proportional to time spent in isolation. Chapter 3: Eliminating Cognitive Load. Multi-tasking is a myth; switching tasks leaves attention residue that degrades output. Chapter 4: Environmental Audits. Clean physical and digital environments lead to clean thinking.',
          'ku': 'بەشی ١: ئابووریی سەرنج. ژینگەی دیجیتاڵی بە شێوازێک دروستکراوە کە سەرنجمان پەرش بکات. بەشی ٢: ڕۆتینی کاری قووڵ. بەرهەمی باڵا پەیوەستە بەو کاتەی لە گۆشەگیریدا بەسەری دەبەیت. بەشی ٣: نەهێشتنی باری گران لەسەر مێشک. ئەنجامدانی چەند کارێک لە یەک کاتدا تەنها خەیاڵە. بەشی ٤: پاککردنەوەی ژینگە. ژینگەیەکی فیزیکی و دیجیتاڵی خاوێن دەبێتە هۆی بیرکردنەوەیەکی ڕوون.',
          'ar': 'الفصل الأول: اقتصاد الانتباه. تم تصميم البيئة الرقمية لتفتيت تركيزنا. الفصل الثاني: روتين العمل العميق. تتناسب جودة المخرجات طردياً مع الوقت الذي نقضيه في عزلة. الفصل الثالث: القضاء على الحمل المعرفي. تعدد المهام خرافة؛ ترك المهام يؤدي إلى بقايا انتباه تقلل من جودة الأداء. الفصل الرابع: تدقيق البيئة المحيطة. البيئات المادية والرقمية النظيفة تؤدي إلى تفكير نقي.'
        },
        chapterSummaries: {
          'en': [
            {'title': 'Chapter 1: The Fragmentation of Mind', 'content': 'In this initial chapter, Darren Vance discusses how modern software engineering targets dopamine loops to keep users constantly checking updates, thereby destroying sustained cognitive stamina.'},
            {'title': 'Chapter 2: Designing the Sanctuary', 'content': 'Vance argues that environment dictates behavior. By building a dedicated workspace empty of smart devices, one can double productivity within two weeks.'}
          ],
          'ku': [
            {'title': 'بەشی ١: پەرشبوونی مێشک', 'content': 'لەم بەشە سەرەتاییەدا، نووسەر باس لەوە دەکات چۆن ئەندازیاریی نەرمەکاڵای سەردەم هۆرمۆنی دۆپامین بەکاردێنێت بۆ هێشتنەوەی بەکارهێنەران لە چاودێریکردنی بەردەوام، کە ئەمەش سەرنج لەناو دەبات.'},
            {'title': 'بەشی ٢: دیزاینکردنی شوێنی تایبەت', 'content': 'ڤانس دەڵێت ژینگە ڕەفتار دیاری دەکات. بە دروستکردنی ژینگەیەکی کارکردنی دوور لە ئامێرە زیرەکەکان، دەتوانیت لە ماوەی دوو هەفتەدا بەرهەمداریت دوو هێندە بکەیت.'}
          ],
          'ar': [
            {'title': 'الفصل الأول: تشتت الذهن', 'content': 'في هذا الفصل التمهيدي، يناقش دارين فانس كيف تستهدف هندسة البرمجيات الحديثة مسارات الدوبامين لإبقاء المستخدمين في حالة تحقق دائم من التحديثات، مما يدمر القدرة المعرفية المستمرة.'},
            {'title': 'الفصل الثاني: تصميم الملاذ الخاص', 'content': 'يجادل فانس بأن البيئة تملي السلوك. من خلال بناء مساحة عمل مخصصة خالية من الأجهزة الذكية، يمكن للفرد مضاعفة إنتاجيته في غضون أسبوعين.'}
          ]
        },
        keyIdeas: {
          'en': [
            'Attention is finite; protect it as currency.',
            'Task switching results in "attention residue" which ruins focus.',
            'Boredom is a trigger for creative thinking; don\'t escape it with screens.'
          ],
          'ku': [
            'سەرنجدان سنووردارە؛ وەک دراوێک بیپارێزە.',
            'گۆڕینی خێرای کارەکان دەبێتە هۆی کەمبوونەوەی توانای مێشک.',
            'بێزاری سەرەتایەکە بۆ بیرکردنەوەی داهێنەرانە؛ بە شاشەکان لێی ڕامەکە.'
          ],
          'ar': [
            'الانتباه محدود؛ احمِه كأنه عملة ثمينة.',
            'التبديل بين المهام يؤدي إلى "بقايا الانتباه" مما يخرب التركيز.',
            'الملل هو محفز للتفكير الإبداعي؛ لا تهرب منه نحو الشاشات.'
          ]
        },
        keyQuotes: {
          'en': [
            '"He who is everywhere is nowhere."',
            '"Focus is not about saying yes to one thing, it is saying no to the other hundred good ideas."'
          ],
          'ku': [
            '"ئەوەی لە هەموو شوێنێک بێت، لە هیچ شوێنێک نییە."',
            '"سەرنجدان بەواتای بەڵێ کردن نییە بۆ یەک شت، بەڵکو نەخێر کردنە بۆ سەد بیرۆکەی باشی تر."'
          ],
          'ar': [
            '"من يتواجد في كل مكان لا يتواجد في أي مكان."',
            '"التركيز لا يعني قول نعم لشيء واحد، بل يعني قول لا للمئة فكرة جيدة الأخرى."'
          ]
        },
        actionPoints: {
          'en': [
            'Set your phone to "Do Not Disturb" during the first 3 hours of work.',
            'Designate a physical table solely for deep reading and writing.'
          ],
          'ku': [
            'مۆبایلەکەت بخەرە دۆخی "بێدەنگ" لە ماوەی ٣ کاتژمێری یەکەمی کارەکەتدا.',
            'مێزێکی فیزیکی تایبەت بکە تەنها بۆ خوێندنەوەی قووڵ و نووسین.'
          ],
          'ar': [
            'ضع هاتفك على وضع "عدم الإزعاج" خلال أول 3 ساعات من العمل.',
            'خصص طاولة مادية فقط للقراءة العميقة والكتابة.'
          ]
        },
        audioUrl: {
          'en': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
          'ku': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
          'ar': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3'
        },
        duration: 480,
        isPremium: false,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now(),
        hiddenLanguages: const [],
      ),
      Book(
        id: 'book-heritage',
        title: {
          'en': 'Sumer & Mesopotamia: Cradle of Science',
          'ku': 'سۆمەر و مێزۆپۆتامیا: لانکەی زانست',
          'ar': 'سومر وبلاد الرافدين: مهد العلوم'
        },
        author: {
          'en': 'Dr. Alan Kurdi',
          'ku': 'د. ئالان کوردی',
          'ar': 'د. آلان كردي'
        },
        coverImageUrl: 'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?q=80&w=400',
        categoryIds: ['cat-productivity'],
        tags: ['mesopotamia', 'kurdish', 'history', 'science'],
        description: {
          'en': 'An exploration of the scientific, architectural, and philosophical achievements originating in Mesopotamia, with custom highlights on Kurdish and Arabic translations.',
          'ku': 'لێکۆڵینەوەیەک لە دەستکەوتە زانستی، تەلارسازی و فەلسەفییەکانی مێزۆپۆتامیا، لەگەڵ تیشک خستنە سەر بەشداریی ناوچەکە.',
          'ar': 'استكشاف للإنجازات العلمية والمعمارية والفلسفية التي نشأت في بلاد الرافدين، مع تسليط الضوء على الترجمات الكردية والعربية.'
        },
        fiveMinuteSummary: {
          'en': 'This book details the birth of written civilization in the valleys of Tigris and Euphrates. Mesopotamia gifted humanity the cuneiform script, astronomical calendars, irrigation mathematics, and legal codices. Dr. Kurdi emphasizes that understanding the intellectual roots of this geography provides modern Middle Eastern societies with an empowering blueprint for contemporary innovation.',
          'ku': 'ئەم کتێبە باس لە لەدایکبوونی شارستانیەتی نووسراو دەکات لە دۆڵی دیجلە و فوڕات. مێزۆپۆتامیا خەتی بزماری، ڕۆژژمێری گەردوونی، بیرکاری و یاساکانی پێشکەش بە مرۆڤایەتی کرد. د. ئالان جەخت دەکاتەوە کە تێگەیشتن لەم مێژووە دەبێتە هۆی هاندانی گەنجان بۆ داهێنان.',
          'ar': 'يفصل هذا الكتاب ولادة الحضارة المكتوبة في واديي دجلة والفرات. وهبت بلاد الرافدين البشرية الخط المسماري، والتقويم الفلكي، ورياضيات الري، والقوانين المدنية. يؤكد الدكتور كردي أن فهم الجذور الفكرية لهذه الجغرافيا يمنح المجتمعات الشرق أوسطية مخططاً لتمكين الابتكار المعاصر.'
        },
        fifteenMinuteSummary: {
          'en': 'Chapter 1: Cuneiform and Literacy. Clay tablets as the world\'s first external hard drives. Chapter 2: The Base-60 Mathematical System. How Sumerian numbers still define our 60-second minutes and 360-degree circles. Chapter 3: Ancient Philosophy. Deep cultural analysis of the Epic of Gilgamesh, searching for meaning and immortality.',
          'ku': 'بەشی ١: خەتی بزماری و خوێندەواری. بەشی ٢: سیستەمی بیرکاری بنکە-٦٠. چۆن ژمارە سۆمەرییەکان هێشتا کات و بازنە دیاری دەکەن. بەشی ٣: فەلسەفەی کۆن. شیکردنەوەی قووڵی داستانی گلگامێش بۆ دۆزینەوەی مانای ژیان.',
          'ar': 'الفصل الأول: الخط المسماري والتعليم. الألواح الطينية كأول محركات أقراص خارجية في العالم. الفصل الثاني: النظام الرياضي الستيني. كيف لا تزال الأرقام السومرية تحدد دقائقنا ذات الـ 60 ثانية ودوائرنا ذات الـ 360 درجة. الفصل الثالث: الفلسفة القديمة. تحليل ثقافي عميق لملحمة جلجامش، والبحث عن المعنى والخلود.'
        },
        chapterSummaries: {
          'en': [
            {'title': 'Chapter 1: The First Written Words', 'content': 'Discover how trade and agriculture ledger systems drove Sumerian accountants to invent symbols that eventually became literature.'}
          ],
          'ku': [
            {'title': 'بەشی ١: یەکەم وشەی نووسراو', 'content': 'بزانە چۆن بازرگانی و کشتوکاڵ سۆمەرییەکانی ناچارکرد هێما دابهێنن کە دواتر بوو بە ئەدەب.'}
          ],
          'ar': [
            {'title': 'الفصل الأول: الكلمات المكتوبة الأولى', 'content': 'اكتشف كيف دفعت أنظمة دفاتر التجارة والزراعة المحاسبين السومريين إلى ابتكار رموز أصبحت في النهاية أدباً.'}
          ]
        },
        keyIdeas: {
          'en': [
            'Our division of time is inherited directly from Mesopotamia.',
            'Cuneiform writing changed human consciousness by outsourcing memory.'
          ],
          'ku': [
            'دابەشکردنی کات لەلایەن ئێمەوە لە مێزۆپۆتامیاوە بە میرات ماوەتەوە.',
            'نووسینی بزماری مێشکی مرۆڤی گۆڕی بە پاراستنی بیرەوەرییەکان.'
          ],
          'ar': [
            'تقسيمنا الحالي للوقت موروث مباشرة من بلاد الرافدين.',
            'الكتابة المسمارية غيرت الوعي البشري عن طريق حفظ الذاكرة خارجياً.'
          ]
        },
        keyQuotes: {
          'en': [
            '"Writing is the mother of wisdom and the guardian of memory."'
          ],
          'ku': [
            '"نووسین دایکی داناییە و پاسەوانی بیرەوەرییە."'
          ],
          'ar': [
            '"الكتابة هي أم الحكمة وحارسة الذاكرة."'
          ]
        },
        actionPoints: {
          'en': [
            'Read the Epic of Gilgamesh to understand classical regional storytelling structures.'
          ],
          'ku': [
            'داستانی گلگامێش بخوێنەرەوە بۆ تێگەیشتن لە ئەدەبیاتی کۆنی ناوچەکە.'
          ],
          'ar': [
            'اقرأ ملحمة جلجامش لفهم بنيات السرد الإقليمية الكلاسيكية.'
          ]
        },
        audioUrl: {
          'en': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
          'ku': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
          'ar': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3'
        },
        duration: 620,
        isPremium: true,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now(),
        hiddenLanguages: const [],
      )
    ]);

    // Learning Paths
    _learningPaths.addAll([
      LearningPath(
        id: 'path-cognitive-beast',
        title: {
          'en': 'High-Performance Mindset',
          'ku': 'عەقڵیەتی کارامەیی بەرز',
          'ar': 'العقلية عالية الأداء'
        },
        description: {
          'en': 'A curated collection of text and audio insights to supercharge focus, memory, and cognitive speed.',
          'ku': 'کۆمەڵەیەکی تایبەت لە کورتە دەق و دەنگییەکان بۆ بەرزکردنەوەی ئاستی تەرکیز و بیرەوەری.',
          'ar': 'مجموعة منسقة من النصوص والملخصات الصوتية لتعزيز التركيز والذاكرة والسرعة المعرفية.'
        },
        bookIds: ['book-focus'],
        category: 'Personal Development',
      ),
      LearningPath(
        id: 'path-mesopotamian-roots',
        title: {
          'en': 'Cultural Heritage & Wisdom',
          'ku': 'کەلەپوور و دانایی کولتووری',
          'ar': 'التراث الثقافي والحكمة'
        },
        description: {
          'en': 'Connect with the historical innovations, philosophy, and cultural values of Mesopotamia and the Middle East.',
          'ku': 'پەیوەست بە بە داهێنانە مێژووییەکان و فەلسەفەی ناوچەی مێزۆپۆتامیا.',
          'ar': 'تواصل مع الابتكارات التاريخية والفلسفة والقيم الثقافية لبلاد الرافدين والشرق الأوسط.'
        },
        bookIds: ['book-heritage'],
        category: 'History',
      )
    ]);

    // Achievements
    _achievements.addAll([
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
    ]);

    // Quizzes
    _quizzes.addAll([
      Quiz(
        id: 'quiz-focus',
        bookId: 'book-focus',
        langCode: 'en',
        questions: [
          QuizQuestion(
            questionText: 'According to Vance, what is focus?',
            choices: ['A genetic talent', 'A muscle trained through routines', 'A modern illusion'],
            correctOptionIndex: 1,
          ),
          QuizQuestion(
            questionText: 'What does task switching cause?',
            choices: ['Attention residue', 'Increased intelligence', 'Instant relaxation'],
            correctOptionIndex: 0,
          )
        ],
      )
    ]);
  }

  @override
  Future<List<Book>> fetchBooks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentLangCode = prefs.getString('language_code') ?? 'en';
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 300));
    return books;
  }

  @override
  Future<List<Category>> fetchCategories() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _categories;
  }

  @override
  Future<List<LearningPath>> fetchLearningPaths() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _learningPaths;
  }

  @override
  Future<List<Achievement>> fetchAchievements() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _achievements;
  }

  @override
  Future<Quiz?> fetchQuizForBook(String bookId, String langCode) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final quiz = _quizzes.firstWhere((element) => element.bookId == bookId && element.langCode == langCode, orElse: () {
      // Generate dynamically if not found
      return Quiz(
        id: 'quiz-dyn-$bookId-$langCode',
        bookId: bookId,
        langCode: langCode,
        questions: [
          QuizQuestion(
            questionText: langCode == 'en' ? 'What is the primary message of this summary?' :
                          langCode == 'ku' ? 'پەیامی سەرەکی ئەم کورتەکراوەیە چییە؟' :
                          'ما هي الرسالة الأساسية لهذا الملخص؟',
            choices: langCode == 'en' ? ['Empowerment through knowledge', 'Passive relaxation', 'Rapid multitasking'] :
                     langCode == 'ku' ? ['بەهێزبوون لەڕێگەی زانیارییەوە', 'حەسانەوەی پاسیڤ', 'ئەنجامدانی چەند کارێک بە خێرایی'] :
                     ['التمكين من خلال المعرفة', 'الاسترخاء السلبي', 'تعدد المهام السريع'],
            correctOptionIndex: 0,
          )
        ],
      );
    });
    return quiz;
  }

  @override
  Future<List<Flashcard>> fetchFlashcardsForBook(String bookId, String langCode) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // For mock, just return empty or you can build mock cards
    return [];
  }

  @override
  Future<List<Note>> fetchNotes(String userId) async {
    return _notes.where((note) => note.userId == userId).toList();
  }

  @override
  Future<void> addNote(Note note) async {
    _notes.add(note);
    notifyListeners();
  }

  @override
  Future<void> deleteNote(String noteId) async {
    _notes.removeWhere((note) => note.id == noteId);
    notifyListeners();
  }

  @override
  Future<List<Highlight>> fetchHighlights(String userId) async {
    return _highlights.where((hl) => hl.userId == userId).toList();
  }

  @override
  Future<void> addHighlight(Highlight highlight) async {
    _highlights.add(highlight);
    notifyListeners();
  }

  @override
  Future<void> deleteHighlight(String highlightId) async {
    _highlights.removeWhere((hl) => hl.id == highlightId);
    notifyListeners();
  }

  @override
  Future<void> addBook(Book book) async {
    _books.add(book);
    notifyListeners();
  }

  @override
  Future<void> addQuiz(Quiz quiz) async {
    _quizzes.add(quiz);
    notifyListeners();
  }

  @override
  Future<void> updateTranslations(String key, String enVal, String kuVal, String arVal) async {
    // Mimic translations dictionary updates
    notifyListeners();
  }
}
