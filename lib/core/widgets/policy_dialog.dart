import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

void showPolicyDialog(BuildContext context, String policyType) {
  final localizations = AppLocalizations.of(context)!;
  final langCode = localizations.locale.languageCode;
  final isRtl = localizations.isRtl;

  final Map<String, Map<String, String>> policyData = {
    'privacy': {
      'en_title': 'Privacy Policy',
      'ku_title': 'سیاسەتی تایبەتمەندی',
      'ar_title': 'سياسة الخصوصية',
      'en_content': '''Last Updated: June 23, 2026

Partwk ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your personal information when you use our mobile application.

1. Information We Collect
• Account Information: When you register or subscribe, we collect your name, email address, subscription plan, and family sharing linkages.
• Usage Progress: We collect and store your reading progress, audio listening positions, daily learning streaks, and saved highlights to synchronize your learning state across devices.
• Device & Log Info: We may collect anonymous crash logs and performance indicators to resolve application bugs and errors.

2. How We Use Your Information
• To personalize your reading and listening experience.
• To synchronize your offline and online progress seamlessly.
• To manage your subscription entitlements and enforce single concurrent session rules.
• To send you daily study reminders and alerts (only if notifications are enabled).

3. Data Sharing & Security
• We do not sell, rent, or trade your personal data.
• Payment transactions are handled securely and directly by Apple App Store and Google Play Store billing systems.
• We implement industry-standard encryption and physical security measures to protect your user profile and license keys.

4. Account and Data Deletion
You can request the complete deletion of your account and associated learning history at any time by contacting our support team at support@partwk.com. We will process your deletion request within 30 days.''',
      'ku_content': '''دواین نوێکردنەوە: ٢٣ی حوزەیرانی ٢٠٢٦

پەرتوک ("ئێمە" یان "موڵکی ئێمە") پابەندە بە پاراستنی تایبەتمەندییەکانت. ئەم سیاسەتی تایبەتمەندییە ڕوونکردنەوە دەدات لەسەر چۆنیەتی کۆکردنەوە، بەکارهێنان، و پاراستنی زانیارییە کەسییەکانت کاتێک ئەپی پەرتوک بەکاردەهێنیت.

١. ئەو زانیارییانەی کۆیدەکەینەوە
• زانیارییەکانی هەژمارە: کاتێک تۆمار دەبیت یان بەشداری دەکەیت، ناو، ناونیشانی ئیمەیڵ، پلانی بەشداریکردن، و بەستەرەکانی پلانی خێزانی کۆدەکەینەوە.
• پێشکەوتنی بەکارهێنان: ئێمە پێشکەوتنی خوێندنەوە، شوێنی دەنگی گوێگرتن، زنجیرەی ڕۆژانەی فێربوون، و نیشانکردنەکان پاشەکەوت دەکەین بۆ هاوکاتکردنی هەژمارەکەت لەسەر ئامێرە جیاوازەکان.
• زانیاری ئامێر و لۆگ: لۆگی لەکارکەوتن و نیشاندەرەکانی کارایی کۆدەکەینەوە بۆ چاککردنی کێشەکان.

٢. چۆنیەتی بەکارهێنانی زانیارییەکانت
• بۆ کەسیکردنی ئەزموونی خوێندنەوە و گوێگرتنت.
• بۆ هاوکاتکردنی پێشکەوتنی ئۆفلاین و ئۆنلاینت بە ئاسانی.
• بۆ بەڕێوەبردنی مافەکانی بەشداریکردن و جێبەجێکردنی یاسای تەنها یەک چوونەژوورەوەی هاوکات.
• بۆ ناردنی بیرخستنەوەی ڕۆژانە (تەنها ئەگەر ئاگادارکەرەوەکان چالاک بن).

٣. هاوبەشکردن و پاراستنی زانیارییەکان
• ئێمە زانیارییە کەسییەکانت نافڕۆشین و ئاڵوگۆڕی پێوە ناکەین.
• پرۆسەی پارەدان بە تەواوی و بە شێوەیەکی پارێزراو لە ڕێگەی Apple App Store و Google Play Store ئەنجام دەدرێت.
• ئێمە تەکنەلۆژیای پاراستنی پێشکەوتوو بەکاردەهێنین بۆ پاراستنی هەژمارەکەت.

٤. سڕینەوەی هەژمارە و زانیارییەکان
تۆ دەتوانیت لە هەر کاتێکدا داوای سڕینەوەی تەواوەتی هەژمارەکەت و مێژووی فێربوونت بکەیت لە ڕێگەی پەیوەندیکردن بە ئیمەیڵی فەرمی support@partwk.com. ئێمە لە ماوەی ٣٠ ڕۆژدا داواکارییەکەت جێبەجێ دەکەین.''',
      'ar_content': '''آخر تحديث: 23 يونيو 2026

يلتزم تطبيق پەرتوک (Partwk) بحماية خصوصيتك. توضح سياسة الخصوصية هذه كيفية جمع واستخدام وحماية معلوماتك الشخصية عند استخدام تطبيقنا.

1. المعلومات التي نجمعها
• معلومات الحساب: عند التسجيل أو الاشتراك، نجمع اسمك وبريدك الإلكتروني وخطة الاشتراك وروابط مشاركة العائلة.
• تقدم الاستخدام: نقوم بجمع وتخزين تقدمك في القراءة، ومواقع الاستماع الصوتي، وسلسلة التعلم اليومية، والملاحظات لمزامنة حالة التعلم الخاصة بك عبر الأجهزة.
• معلومات الجهاز والسجلات: قد نجمع سجلات الأعطال والمؤشرات الفنية غير المحددة للهوية لحل مشكلات التطبيق.

2. كيف نستخدم معلوماتك
• لتخصيص تجربة القراءة والاستماع الخاصة بك.
• لمزامنة تقدمك دون اتصال بالإنترنت والاتصال بالإنترنت بسلاسة.
• لإدارة اشتراكاتك وفرض قواعد جلسة تسجيل الدخول الفردية المتزامنة.
• لإرسال تذكيرات وتنبيهات دراسية يومية (فقط إذا كانت الإشعارات مفعلة).

3. مشاركة البيانات وأمنها
• نحن لا نبيع أو نؤجر أو نتاجر ببياناتك الشخصية مع أي طرف ثالث.
• تتم معالجة معاملات الدفع بشكل آمن ومباشر بواسطة أنظمة الدفع لمتجري Apple App Store و Google Play Store.
• نحن نطبق معايير تشفير وأمان متقدمة لحماية ملفك الشخصي ومفاتيح الترخيص الخاصة بك.

4. طلب حذف الحساب والبيانات
يمكنك طلب حذف حسابك وتاريخك التعليمي بالكامل في أي وقت عن طريق الاتصال بفريق الدعم لدينا على support@partwk.com. سنقوم بمعالجة طلبك خلال 30 يوماً.''',
    },
    'terms': {
      'en_title': 'Terms & Conditions',
      'ku_title': 'مەرج و یاساکان',
      'ar_title': 'الشروط والأحكام',
      'en_content': '''Last Updated: June 23, 2026

Please read these Terms & Conditions carefully before using the Partwk application.

1. Intellectual Property
All book summaries, audio narrations, key ideas, graphics, layouts, and code provided within the application are the exclusive intellectual property of Partwk. Content is protected by copyright laws. You are granted a personal, non-commercial license to access the summaries. Copying, republishing, or redistributing our content is strictly prohibited.

2. Concurrent Session Constraint
Your Partwk subscription and account are for individual, single-user access only. Sharing credentials or using the application from multiple concurrent devices is prohibited. Our system automatically enforces a single active session rule. If a session is initiated on a new device, other sessions will be terminated automatically. Continued violations may result in account suspension.

3. Subscriptions & Billing
• Subscription purchases are processed through App Store and Play Store.
• Pricing and billing intervals are detailed during purchase.
• Unless turned off 24 hours before renewal, subscriptions auto-renew.
• Cancellation and refunds are governed by the respective store policies.

4. Limitation of Liability
Partwk provides educational summaries and interpretations for general guidance and learning. We do not guarantee the completeness or accuracy of any book summary, and shall not be liable for decisions made based on application content.''',
      'ku_content': '''دواین نوێکردنەوە: ٢٣ی حوزەیرانی ٢٠٢٦

تکایە بە قووڵی ئەم مەرج و یاسایانە بخوێنەرەوە پێش بەکارهێنانی ئەپی پەرتوک.

١. مافی خاوەندارێتی فکری
هەموو پوختەی کتێبەکان، گێڕانەوە دەنگییەکان، بیرۆکە سەرەکییەکان، وێنەکان، و کۆدەکان لە نێو ئەپەکەدا، موڵکی فکری و تایبەتی پەرتوکن. ئەم ناوەڕۆکە بە یاساکانی پاراستنی مافی بڵاوکردنەوە پارێزراوە. مۆڵەتێکی کەسی و ناناوخۆیی کاتی بەکارهێنەر پێدەدرێت. کۆپیکردن، بڵاوکردنەوە، یان فرۆشتنەوەی ناوەڕۆکەکان بە تەواوی قەدەغەیە.

٢. سنووردارکردنی بەکارهێنانی هاوکات
بەشداربوون و هەژمارەکەت لە پەرتوک تەنها بۆ یەک کەسە. هاوبەشکردنی هەژمارە یان بەکارهێنانی ئەپەکە لەسەر چەندین ئامێری هاوکات قەدەغەیە. سیستەمەکەمان بە شێوەیەکی ئۆتۆماتیکی چوونەژوورەوەی یەک ئامێری چالاک جێبەجێ دەکات. ئەگەر هەژمارەکە لە ئامێرێکی نوێ چالاک بکرێت، دانیشتنەکانی تر دادەخرێن. دووبارەکردنەوەی ئەم سەرپێچییە دەبێتە هۆی ڕاگرتنی هەژمارەکە.

٣. بەشداریکردن و پارەدان
• کڕین و نوێکردنەوەی بەشداریکردن لە ڕێگەی App Store و Play Store ئەنجام دەدرێت.
• نرخ و ماوەی نوێکردنەوە لە کاتی کڕیندا دیاریکراون.
• نوێبوونەوەی بەشداریکردن ئۆتۆماتیکییە مەگەر ٢٤ کاتژمێر پێش بەسەرچوون هەڵبوەشێنرێتەوە.
• گەڕاندنەوەی پارە لە ژێر یاسای سیاسەتی مۆڵەتی فرۆشگا فەرمییەکاندایە.

٤. سنووردارکردنی بەرپرسیارێتی
پەرتوک پوختەی کتێبەکان بۆ گەشەپێدان و فێربوونی گشتی پێشکەش دەکات. ئێمە گرەنتی تەواوی یان بێخەوشی ناوەڕۆکەکان ناکەین، و بەرپرسیار نین لە هیچ بڕیارێک کە لەسەر بنەمای پوختەکان دەدرێت.''',
      'ar_content': '''آخر تحديث: 23 يونيو 2026

يرجى قراءة هذه الشروط والأحكام بعناية قبل استخدام تطبيق پەرتوک (Partwk).

1. الملكية الفكرية
جميع ملخصات الكتب، والتعليقات الصوتية، والأفكار الرئيسية، والرسومات، والتصميمات، والكود البرمجي المقدمة في التطبيق هي ملكية فكرية حصرية لتطبيق پەرتوک. المحتوى محمي بقوانين حقوق النشر. نمنحك ترخيصاً شخصياً وغير تجاري للوصول إلى الملخصات. يمنع منعاً باتاً نسخ المحتوى أو إعادة نشره أو إعادة توزيعه.

2. قيود جلسة تسجيل الدخول المتزامن
اشتراكك وحسابك في پەرتوک مخصصان للاستخدام الفردي فقط. يحظر مشاركة بيانات الاعتماد أو استخدام التطبيق من أجهزة متعددة متزامنة. يفرض نظامنا تلقائياً قاعدة جلسة نشطة واحدة. إذا تم بدء جلسة على جهاز جديد، فسيتم إنهاء الجلسات الأخرى تلقائياً. قد تؤدي الانتهاكات المستمرة إلى تعليق الحساب.

3. الاشتراكات والفوترة
• تتم معالجة عمليات شراء الاشتراكات من خلال متجري التطبيقات.
• يتم توضيح الأسعار وفترات الفوترة بالتفصيل أثناء الشراء.
• تتجدد الاشتراكات تلقائياً ما لم يتم إيقافها قبل 24 ساعة من موعد التجديد.
• تخضع عمليات الإلغاء واسترداد الأموال لسياسات المتاجر المعنية.

4. حدود المسؤولية
يقدم تطبيق پەرتوک ملخصات وتفسيرات تعليمية للتوجيه والتعلم العام. نحن لا نضمن اكتمال أو دقة أي ملخص للكتاب، ولن نكون مسؤولين عن أي قرارات يتم اتخاذها بناءً على محتوى التطبيق.''',
    },
    'eula': {
      'en_title': 'EULA (End User License Agreement)',
      'ku_title': 'ڕێککەوتننامەی مۆڵەتی بەکارهێنەر',
      'ar_title': 'اتفاقية ترخيص المستخدم النهائي',
      'en_content': '''Last Updated: June 23, 2026

This End User License Agreement ("EULA") is a legal agreement between you and Partwk for the use of our mobile application.

1. Grant of License
Partwk grants you a limited, non-exclusive, non-transferable, revocable license to download, install, and use the application on mobile devices owned or controlled by you, solely for personal, non-commercial purposes in accordance with this agreement.

2. Restrictions on Use
You agree not to, and you will not permit others to:
• License, sell, rent, lease, assign, distribute, or host the application.
• Modify, make derivative works of, decrypt, reverse compile, or reverse engineer any part of the application.
• Circumvent, disable, or tamper with any security protection, session lock, or digital rights management (DRM) features in the application.

3. Termination
This Agreement is effective until terminated by you or Partwk. Your rights under this license will terminate automatically without notice from us if you fail to comply with any term of this agreement. Upon termination, you must cease all use of the application and delete all copies from your devices.''',
      'ku_content': '''دواین نوێکردنەوە: ٢٣ی حوزەیرانی ٢٠٢٦

ئەم ڕێککەوتننامەی مۆڵەتی بەکارهێنەری کۆتایی ("EULA") پەیوەندییەکی یاساییە لە نێوان تۆ و پەرتوک بۆ بەکارهێنانی ئەپەکەمان.

١. پێدانی مۆڵەت
پەرتوک مۆڵەتێکی سنووردار، ناتایبەت، و فەرمی پێدەبەخشێت بۆ داگرتن، دامەزراندن، و بەکارهێنانی ئەپی پەرتوک لەسەر مۆبایلی کەسی خۆت، تەنها بۆ مەبەستی فێربوون و بەکارهێنانی کەسی ناناوخۆیی.

٢. سنووردارکردنی بەکارهێنان
تۆ ڕێکدەکەویت کە خۆت و کەسانی تر نەکەن بە:
• فرۆشتن، بەکرێدان، دابەشکردن، یان میوانداریکردنی ئەپەکە.
• دەستکاریکردن، کۆپی کردن، یان هەڵوەشاندنەوەی (Reverse Engineer) کۆدە فەرمییەکانی نێو ئەپەکە.
• تێپەڕاندن یان دەستکاریکردنی سیستەمی پاراستنی سەرچاوەی دەنگەکان، پاراستنی هەژمارەکان، و پاراستنی مافی دیجیتاڵی (DRM).

٣. کۆتایی هاتن
ئەم مۆڵەتە چالاک دەبێت تا ئەو کاتەی لەلایەن تۆ یان پەرتوک هەڵدەوەشێندرێتەوە. مافەکانت بە شێوەیەکی ئۆتۆماتیکی بەبێ ئاگادارکردنەوە ڕادەگیرێن ئەگەر پابەند نەبیت بە خاڵەکانی ئەم ڕێککەوتننامەیە. دوای کۆتایی هاتن، دەبێت بە تەواوی بەکارهێنانی ئەپەکە ڕابگریت و بیسڕیتەوە لەسەر ئامێرەکەت.''',
      'ar_content': '''آخر تحديث: 23 يونيو 2026

تعتبر اتفاقية ترخيص المستخدم النهائي هذه ("EULA") اتفاقية قانونية بينك وبين پەرتوک لاستخدام تطبيق الهاتف المحمول الخاص بنا.

1. منح الترخيص
تمنحك پەرتوک ترخيصاً محدوداً وغير حصري وغير قابل للتحويل وقابلاً للإلغاء لتنزيل التطبيق وتثبيته واستخدامه على الأجهزة المحمولة التي تمتلكها أو تتحكم فيها، فقط للأغراض الشخصية وغير التجارية وفقاً لهذه الاتفاقية.

2. قيود الاستخدام
أنت توافق على عدم القيام بالتالي، ولن تسمح للآخرين بالقيام به:
• ترخيص التطبيق أو بيعه أو تأجيره أو توزيعه أو استضافته.
• تعديل أو عمل أعمال مشتقة من التطبيق، أو فك تشفيره، أو الهندسة العكسية لأي جزء منه.
• التحايل على أي حماية أمنية، أو قفل الجلسة، أو ميزات إدارة الحقوق الرقمية (DRM) في التطبيق أو تعطيلها.

3. الإنهاء
تظل هذه الاتفاقية سارية المفعول حتى يتم إنهاؤها من قبلك أو من قبل پەرتوک. ستنتهي حقوقك بموجب هذا الترخيص تلقائياً دون إشعار منا إذا فشلت في الالتزام بأي شرط من شروط هذه الاتفاقية. عند الإنهاء، يجب عليك التوقف عن استخدام التطبيق وحذفه بالكامل من أجهزتك.''',
    }
  };

  final data = policyData[policyType] ?? policyData['privacy']!;
  final title = langCode == 'ku' ? data['ku_title']! : (langCode == 'ar' ? data['ar_title']! : data['en_title']!);
  final content = langCode == 'ku' ? data['ku_content']! : (langCode == 'ar' ? data['ar_content']! : data['en_content']!);

  showDialog(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final localizations = AppLocalizations.of(dialogContext)!;
      final closeText = langCode == 'ku' ? 'داخستن' : (langCode == 'ar' ? 'إغلاق' : 'Close');

      return Center(
        child: Dialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      policyType == 'privacy'
                          ? Icons.privacy_tip_outlined
                          : (policyType == 'terms' ? Icons.gavel_outlined : Icons.description_outlined),
                      color: theme.colorScheme.secondary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(dialogContext).size.height * 0.5,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: SingleChildScrollView(
                      child: Directionality(
                        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                        child: Text(
                          content,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            height: 1.6,
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      closeText,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
