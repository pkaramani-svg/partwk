import 'package:flutter/material.dart';

abstract class AICoachService extends ChangeNotifier {
  List<Map<String, String>> getChatHistory(String bookId);
  Future<String> askCoach(String bookId, String question, String langCode);
  Future<String> askStatelessCoach(String bookId, String question, String langCode);
  void clearChat(String bookId);
}

class MockAICoachService extends AICoachService {
  // bookId -> list of chat messages: {'sender': 'user'|'coach', 'text': 'message'}
  final Map<String, List<Map<String, String>>> _chatHistories = {};

  @override
  List<Map<String, String>> getChatHistory(String bookId) {
    return _chatHistories[bookId] ?? [];
  }

  @override
  Future<String> askCoach(String bookId, String question, String langCode) async {
    // Save user question
    _chatHistories.putIfAbsent(bookId, () => []);
    _chatHistories[bookId]!.add({'sender': 'user', 'text': question});
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    String reply = '';
    final q = question.toLowerCase();
    
    if (q.contains('translate this exactly')) {
      reply = '(Mock Translation) ئەمە وەرگێڕانێکی ساختەیە. بۆ بەکارهێنانی زیرەکی دەستکردی ڕاستەقینە، تکایە کلیلی OpenAI بنووسە.';
    } else if (q.contains('provide a short and clear definition')) {
      reply = '(Mock Definition) پێناسەی ساختە: وشەیەکە یان ڕستەیەکە کە تەنها بۆ تاقیکردنەوە بەکاردێت. بۆ پێناسەی ڕاستەقینە کلیلی OpenAI بنووسە.';
    } else if (langCode == 'ku') {
      reply = _generateKurdishReply(question, bookId);
    } else if (langCode == 'ar') {
      reply = _generateArabicReply(question, bookId);
    } else {
      reply = _generateEnglishReply(question, bookId);
    }

    _chatHistories[bookId]!.add({'sender': 'coach', 'text': reply});
    notifyListeners();
    return reply;
  }

  @override
  Future<String> askStatelessCoach(String bookId, String question, String langCode) async {
    await Future.delayed(const Duration(seconds: 1));
    String reply = '';
    final q = question.toLowerCase();
    
    if (q.contains('translate this')) {
      reply = '(Mock Translation) ئەمە وەرگێڕانێکی ساختەیە. بۆ بەکارهێنانی زیرەکی دەستکردی ڕاستەقینە، تکایە کلیلی OpenAI بنووسە.';
    } else if (q.contains('definition for this')) {
      reply = '(Mock Definition) پێناسەی ساختە: وشەیەکە یان ڕستەیەکە کە تەنها بۆ تاقیکردنەوە بەکاردێت. بۆ پێناسەی ڕاستەقینە کلیلی OpenAI بنووسە.';
    } else if (langCode == 'ku') {
      reply = _generateKurdishReply(question, bookId);
    } else if (langCode == 'ar') {
      reply = _generateArabicReply(question, bookId);
    } else {
      reply = _generateEnglishReply(question, bookId);
    }
    return reply;
  }

  @override
  void clearChat(String bookId) {
    _chatHistories[bookId] = [];
    notifyListeners();
  }

  String _generateEnglishReply(String question, String bookId) {
    final q = question.toLowerCase();
    if (q.contains('how') || q.contains('apply')) {
      return "To apply this, start small. For example, integrate this concept into your first 30 minutes of the morning. Focus on building the habit before scaling it.";
    } else if (q.contains('why')) {
      return "This is essential because cognitive friction builds up when you don't follow these guidelines. Over time, that reduces your output and leads to mental exhaustion.";
    } else {
      return "That is a brilliant question. This summary emphasizes that true learning occurs when you relate the content to your personal projects. Try to write down one direct action item based on this today.";
    }
  }

  String _generateKurdishReply(String question, String bookId) {
    final q = question.toLowerCase();
    if (q.contains('چۆن') || q.contains('جێبەجێ')) {
      return "بۆ جێبەجێکردنی ئەم بیرۆکەیە، لە هەنگاوی بچووکەوە دەست پێبکە. بۆ نموونە، ئەم بابەتە بخەرە ناو یەکەم ٣٠ خولەکی بەیانیان لە کارەکانتدا.";
    } else if (q.contains('بۆچی')) {
      return "ئەمە زۆر گرنگە چونکە مێشکی مرۆڤ کاتێک تووشی بێهیوایی دەبێت کە بەبێ پلان کار بکات. پاراستنی وزە کلیلی سەرکەوتنی بەردەوامە.";
    } else {
      return "پرسیارێکی زۆر باشە. ئەم کورتەکراوەیە جەخت لەسەر ئەوە دەکاتەوە کە فێربوونی ڕاستەقینە کاتێک ڕوودەدات کە تۆ زانیارییەکان لە ژیانی ڕۆژانەتدا بەکاربهێنیت.";
    }
  }

  String _generateArabicReply(String question, String bookId) {
    final q = question.toLowerCase();
    if (q.contains('كيف') || q.contains('تطبيق')) {
      return "لتطبيق هذا المفهوم، ابدأ بخطوات صغيرة. على سبيل المثال، قم بدمج هذه الفكرة في أول 30 دقيقة من صباحك لبناء عادة مستدامة.";
    } else if (q.contains('لماذا') || q.contains('سبب')) {
      return "هذا أمر بالغ الأهمية لأن العقل البشري يتعرض للإرهاق المعرفي عندما يعمل بدون تنظيم. الحفاظ على طاقتك هو سر النجاح المستمر.";
    } else {
      return "سؤال رائع ومهم جداً. يوضح هذا الملخص أن التعلم الحقيقي يتحقق عندما تربط المفاهيم النظرية بمشاريعك الشخصية وأهدافك اليومية.";
    }
  }
}

class RealAICoachService extends MockAICoachService {}
