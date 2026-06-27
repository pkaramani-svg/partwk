import { initializeApp } from 'firebase/app';
import { getFirestore, collection, doc, setDoc } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyCVCIDRXB53ovMQkAahmCECUuWBXmdtn2Q",
  authDomain: "partwk-bd4ec.firebaseapp.com",
  projectId: "partwk-bd4ec",
  storageBucket: "partwk-bd4ec.firebasestorage.app",
  messagingSenderId: "545483273382",
  appId: "1:545483273382:web:f4f66e84dad787f4bb3067",
  measurementId: "G-944TF54VP1"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

const badges = [
  // Books Completed
  { id: 'ach-books-1', icon: 'rocket_launch', en: 'First Step', ku: 'یەکەم هەنگاو', ar: 'الخطوة الأولى', enDesc: 'Completed your first book summary.', kuDesc: 'یەکەم کورتە کتێبت تەواو کرد.', arDesc: 'أكملت أول ملخص كتاب.' },
  { id: 'ach-books-5', icon: 'auto_stories', en: 'Avid Reader', ku: 'خوێنەری تامەزرۆ', ar: 'قارئ نهم', enDesc: 'Completed 5 book summaries.', kuDesc: '٥ کورتە کتێبت تەواو کرد.', arDesc: 'أكملت 5 ملخصات كتب.' },
  { id: 'ach-books-10', icon: 'library_books', en: 'Bookworm', ku: 'کتێب دۆست', ar: 'دودة كتب', enDesc: 'Completed 10 book summaries.', kuDesc: '١٠ کورتە کتێبت تەواو کرد.', arDesc: 'أكملت 10 ملخصات كتب.' },
  { id: 'ach-books-25', icon: 'menu_book', en: 'Scholar', ku: 'زانا', ar: 'باحث', enDesc: 'Completed 25 book summaries.', kuDesc: '٢٥ کورتە کتێبت تەواو کرد.', arDesc: 'أكملت 25 ملخص كتاب.' },
  { id: 'ach-books-50', icon: 'school', en: 'Master', ku: 'مامۆستا', ar: 'سيد', enDesc: 'Completed 50 book summaries.', kuDesc: '٥٠ کورتە کتێبت تەواو کرد.', arDesc: 'أكملت 50 ملخص كتاب.' },
  { id: 'ach-books-100', icon: 'account_balance', en: 'Grandmaster', ku: 'مامۆستای گەورە', ar: 'السيد الأكبر', enDesc: 'Completed 100 book summaries.', kuDesc: '١٠٠ کورتە کتێبت تەواو کرد.', arDesc: 'أكملت 100 ملخص كتاب.' },

  // Streaks
  { id: 'ach-streak-3', icon: 'local_fire_department', en: 'Consistency King', ku: 'پاشای بەردەوامی', ar: 'ملك الاستمرارية', enDesc: 'Maintained a 3-day streak.', kuDesc: 'بەردەوامی بۆ ٣ ڕۆژ.', arDesc: 'حافظت على سلسلة من 3 أيام.' },
  { id: 'ach-streak-7', icon: 'whatshot', en: 'On Fire', ku: 'لە جۆشدا', ar: 'مشتعل', enDesc: 'Maintained a 7-day streak.', kuDesc: 'بەردەوامی بۆ ٧ ڕۆژ.', arDesc: 'حافظت على سلسلة من 7 أيام.' },
  { id: 'ach-streak-14', icon: 'bolt', en: 'Unstoppable', ku: 'وەستێنەنەکراو', ar: 'لا يمكن إيقافه', enDesc: 'Maintained a 14-day streak.', kuDesc: 'بەردەوامی بۆ ١٤ ڕۆژ.', arDesc: 'حافظت على سلسلة من 14 يومًا.' },
  { id: 'ach-streak-30', icon: 'star', en: 'Legendary', ku: 'ئەفسانەیی', ar: 'أسطوري', enDesc: 'Maintained a 30-day streak.', kuDesc: 'بەردەوامی بۆ ٣٠ ڕۆژ.', arDesc: 'حافظت على سلسلة من 30 يومًا.' },
  { id: 'ach-streak-100', icon: 'workspace_premium', en: 'Immortal', ku: 'نەمر', ar: 'خالد', enDesc: 'Maintained a 100-day streak.', kuDesc: 'بەردەوامی بۆ ١٠٠ ڕۆژ.', arDesc: 'حافظت على سلسلة من 100 يومًا.' },

  // Saved Books
  { id: 'ach-saved-1', icon: 'bookmark_add', en: 'Curious', ku: 'چاوکراوە', ar: 'فضولي', enDesc: 'Saved 1 book.', kuDesc: '١ کتێبت پاشەکەوت کرد.', arDesc: 'حفظت كتابًا واحدًا.' },
  { id: 'ach-saved-10', icon: 'bookmarks', en: 'Collector', ku: 'کۆکەرەوە', ar: 'جامع', enDesc: 'Saved 10 books.', kuDesc: '١٠ کتێبت پاشەکەوت کرد.', arDesc: 'حفظت 10 كتب.' },
  { id: 'ach-saved-50', icon: 'collections_bookmark', en: 'Librarian', ku: 'کتێبخانەوان', ar: 'أمين مكتبة', enDesc: 'Saved 50 books.', kuDesc: '٥٠ کتێبت پاشەکەوت کرد.', arDesc: 'حفظت 50 كتابًا.' },

  // Liked Books
  { id: 'ach-liked-1', icon: 'favorite_border', en: 'Fan', ku: 'هەوادار', ar: 'معجب', enDesc: 'Liked 1 book.', kuDesc: '١ کتێبت بەدڵ بوو.', arDesc: 'أعجبت بكتاب واحد.' },
  { id: 'ach-liked-10', icon: 'favorite', en: 'Enthusiast', ku: 'پەرۆش', ar: 'متحمس', enDesc: 'Liked 10 books.', kuDesc: '١٠ کتێبت بەدڵ بوو.', arDesc: 'أعجبت بـ 10 كتب.' },
  { id: 'ach-liked-50', icon: 'volunteer_activism', en: 'Superfan', ku: 'هەواداری سەرسەخت', ar: 'معجب كبير', enDesc: 'Liked 50 books.', kuDesc: '٥٠ کتێبت بەدڵ بوو.', arDesc: 'أعجبت بـ 50 كتابًا.' },

  // Bilingual
  { id: 'ach-polyglot-2', icon: 'translate', en: 'Bilingual Explorer', ku: 'گەڕیدەی دووزمان', ar: 'مستكشف ثنائي اللغة', enDesc: 'Used 2 different languages.', kuDesc: '٢ زمانی جیاوازت بەکارهێنا.', arDesc: 'استخدمت لغتين مختلفتين.' },
  { id: 'ach-polyglot-3', icon: 'language', en: 'Polyglot', ku: 'فرەزمان', ar: 'متعدد اللغات', enDesc: 'Used 3 different languages.', kuDesc: '٣ زمانی جیاوازت بەکارهێنا.', arDesc: 'استخدمت 3 لغات مختلفة.' },

  // Specific Categories (We simulate this by checking completedBooks in backend)
  { id: 'ach-cat-history', icon: 'account_balance', en: 'Historian', ku: 'مێژوونووس', ar: 'مؤرخ', enDesc: 'Completed a History & Big Ideas book.', kuDesc: 'کتێبێکی مێژوویی و بیرۆکە گەورەکانت تەواو کرد.', arDesc: 'أكملت كتابًا في التاريخ والأفكار الكبرى.' },
  { id: 'ach-cat-business', icon: 'business_center', en: 'Entrepreneur', ku: 'خاوەنکار', ar: 'رائد أعمال', enDesc: 'Completed a Business book.', kuDesc: 'کتێبێکی بازرگانیت تەواو کرد.', arDesc: 'أكملت كتابًا في الأعمال.' },
  { id: 'ach-cat-psychology', icon: 'psychology', en: 'Psychologist', ku: 'دەروونناس', ar: 'عالم نفس', enDesc: 'Completed a Psychology book.', kuDesc: 'کتێبێکی دەروونناسیت تەواو کرد.', arDesc: 'أكملت كتابًا في علم النفس.' },

  // Listening time (Assuming we track in backend)
  { id: 'ach-time-1', icon: 'timer', en: 'Focused', ku: 'تەرکیزکراو', ar: 'مركز', enDesc: 'Studied for 1 hour.', kuDesc: 'بۆ ١ کاتژمێر خوێندت.', arDesc: 'درست لمدة ساعة.' },
  { id: 'ach-time-10', icon: 'hourglass_bottom', en: 'Dedicated', ku: 'تەرخانکراو', ar: 'متفان', enDesc: 'Studied for 10 hours.', kuDesc: 'بۆ ١٠ کاتژمێر خوێندت.', arDesc: 'درست لمدة 10 ساعات.' },
  { id: 'ach-time-50', icon: 'access_time_filled', en: 'Relentless', ku: 'بێ وچان', ar: 'لا هوادة فيه', enDesc: 'Studied for 50 hours.', kuDesc: 'بۆ ٥٠ کاتژمێر خوێندت.', arDesc: 'درست لمدة 50 ساعة.' }
];

async function seedAchievements() {
  console.log('Seeding achievements...');
  for (const b of badges) {
    const data = {
      title: { en: b.en, ku: b.ku, ar: b.ar },
      description: { en: b.enDesc, ku: b.kuDesc, ar: b.arDesc },
      badgeIcon: b.icon
    };
    await setDoc(doc(collection(db, 'achievements'), b.id), data);
    console.log(`Seeded ${b.id}`);
  }
  console.log('Done!');
  process.exit(0);
}

seedAchievements();
