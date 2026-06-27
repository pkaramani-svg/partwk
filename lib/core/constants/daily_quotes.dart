class DailyQuotes {
  static const List<Map<String, String>> quotes = [
    {
      'author': 'Darren Vance',
      'en': 'Focus is not about saying yes to one thing, it is saying no to the other hundred good ideas.',
      'ku': 'سەرنجدان بە مانای بەڵێکردن نییە بۆ یەک شت، بەڵکو نەخێرکردنە بۆ سەد بیرۆکەی باشی تر.',
      'ar': 'التركيز لا يعني قول نعم لشيء واحد، بل يعني قول لا للمئة فكرة جيدة الأخرى.'
    },
    {
      'author': 'James Clear',
      'en': 'You do not rise to the level of your goals. You fall to the level of your systems.',
      'ku': 'تۆ ناگەیتە ئاستی ئامانجەکانت، بەڵکو دادەبەزیتە سەر ئاستی سیستمەکانت.',
      'ar': 'أنت لا ترتقي إلى مستوى أهدافك، بل تسقط إلى مستوى أنظمتك.'
    },
    {
      'author': 'Nelson Mandela',
      'en': 'Education is the most powerful weapon which you can use to change the world.',
      'ku': 'پەروەردە بەهێزترین چەکە کە دەتوانیت بۆ گۆڕینی جیهان بەکاری بهێنیت.',
      'ar': 'التعليم هو أقوى سلاح يمكنك استخدامه لتغيير العالم.'
    },
    {
      'author': 'Albert Einstein',
      'en': 'Intellectual growth should commence at birth and cease only at death.',
      'ku': 'گەشەی هزری دەبێت لە کاتی لەدایکبوونەوە دەست پێبکات و تەنیا لە کاتی مردندا بوەستێت.',
      'ar': 'يجب أن يبدأ النمو الفكري عند الولادة ويتوقف فقط عند الموت.'
    },
    {
      'author': 'Mahatma Gandhi',
      'en': 'Live as if you were to die tomorrow. Learn as if you were to live forever.',
      'ku': 'بژی وەک ئەوەی سبەینێ بمریت. فێربە وەک ئەوەی بۆ هەمیشە بژیت.',
      'ar': 'عش كما لو كنت ستموت غدًا. وتعلم كما لو كنت ستعيش للأبد.'
    },
    {
      'author': 'Naval Ravikant',
      'en': 'Read what you love until you love to read.',
      'ku': 'ئەوە بخوێنەوە کە خۆشت دەوێت تا ئەو کاتەی حەزت لە خوێندنەوە دەبێت.',
      'ar': 'اقرأ ما تحب حتى تحب القراءة.'
    },
    {
      'author': 'Steve Jobs',
      'en': 'Stay hungry, stay foolish.',
      'ku': 'هەمیشە برسی بە، هەمیشە گەمژە بە (بەردەوام بە لە گەڕان بەدوای زانین).',
      'ar': 'ابق جائعًا، ابق أحمق (استمر في التعلم وتجربة أشياء جديدة).'
    },
    {
      'author': 'Epictetus',
      'en': 'Only the educated are free.',
      'ku': 'تەنیا کەسانی پەروەردەکراو ئازادن.',
      'ar': 'فقط المتعلمون هم الأحرار.'
    },
    {
      'author': 'Confucius',
      'en': 'It does not matter how slowly you go as long as you do not stop.',
      'ku': 'گرنگ نییە چەندە بە خاوی دەڕۆیت تا ئەو کاتەی ناوەستیت.',
      'ar': 'لا يهم مدى بطئك في المشي طالما أنك لا تتوقف.'
    },
    {
      'author': 'Warren Buffett',
      'en': 'The more you learn, the more you earn.',
      'ku': 'چەندە زیاتر فێربیت، زیاتر بەدەست دەهێنیت.',
      'ar': 'كلما تعلمت أكثر، كسبت أكثر.'
    },
  ];

  static Map<String, String> getTodaysQuote() {
    final now = DateTime.now();
    // Calculate days since a fixed date so it increments by 1 exactly every day
    final daysSinceEpoch = now.difference(DateTime(2024, 1, 1)).inDays;
    final index = daysSinceEpoch % quotes.length;
    return quotes[index];
  }
}
