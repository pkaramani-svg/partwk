import sys
import os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from dynamic_summary_pipeline import (
    load_env_file,
    set_firestore_document
)

# Load env variables (contains FIREBASE_PROJECT_ID)
load_env_file()

def seed_learning_paths():
    paths = [
        {
            "id": "path-habit-building",
            "category": "Personal Growth",
            "title": {
                "en": "Habit Building & Productivity Mastery",
                "ar": "بناء العادات وإتقان الإنتاجية",
                "ku": "بونیادنانی خووەکان و زاڵبوون بەسەر بەرهەمداریدا"
            },
            "description": {
                "en": "Master the science of behavior change, build positive routines, eliminate procrastination, and optimize your daily systems for peak effectiveness.",
                "ar": "أتقن علم تغيير السلوك، وابنِ عادات إيجابية، واقضِ على التسويف، وحسّن أنظمتك اليومية لتحقيق أقصى درجات الفعالية.",
                "ku": "زاڵبە بەسەر زانستی گۆڕینی ڕەفتاردا، ڕۆتینی ئەرێنی بونیاد بنێ، کۆتایی بە دواخستنی کارەکان بهێنە، و سیستەمە ڕۆژانەکانت بۆ بەدەستهێنانی بەرزترین کارایی ڕێکبخە."
            },
            "bookIds": ["atomic_habits", "the_one_thing", "eat_that_frog", "make_time"]
        },
        {
            "id": "path-focus-performance",
            "category": "Productivity",
            "title": {
                "en": "Deep Focus & Mental Clarity",
                "ar": "التركيز العميق والوضوح العقلي",
                "ku": "سەرنجدانی قووڵ و ڕوونیی دەروونی"
            },
            "description": {
                "en": "Learn to eliminate distractions, prioritize the essential few, and cultivate intense concentration in an increasingly noisy digital world.",
                "ar": "تعلم كيفية التخلص من المشتتات، وتحديد الأولويات الأساسية، وتنمية التركيز الشديد في عالم رقمي يزداد صخباً.",
                "ku": "فێربە چۆن سەرنجڕفێنەرەکان نەهێڵیت، کارە سەرەکییەکان بخەیتە پێشینەی کارەکانت، و تەرکیزێکی بەهێز لە جیهانێکی دیجیتاڵیی پڕ ژاوەژاودا پەرە پێ بدەیت."
            },
            "bookIds": ["deep_work", "essentialism", "indistractable"]
        },
        {
            "id": "path-mindset-resilience",
            "category": "Mindset",
            "title": {
                "en": "Growth Mindset & Resilience",
                "ar": "عقلية النمو والمرونة النفسية",
                "ku": "عەقڵییەتی گەشەکردن و خۆڕاگری"
            },
            "description": {
                "en": "Unlock your hidden potential, overcome self-sabotage, embrace challenges, and build the grit required to sustain long-term achievement.",
                "ar": "أطلق العنان لقدراتك الكامنة، وتغلب على التدمير الذاتي، وتجاوز التحديات، وابنِ العزيمة المطلوبة لتحقيق إنجازات طويلة الأمد.",
                "ku": "توانا شاردراوەکانت بەکاربخە، بەسەر تێکدانی خۆتدا زاڵبە، ڕووبەڕووی تەحەددییەکان ببەرەوە، و ئەو سووربوون و خۆڕاگرییە بونیاد بنێ کە بۆ بەردەوامیی دەستکەوتی درێژخایەن پێویستە."
            },
            "bookIds": ["mindset", "grit", "hidden_potential", "the_mountain_is_you"]
        },
        {
            "id": "path-human-behavior",
            "category": "Psychology",
            "title": {
                "en": "Human Behavior & Social Dynamics",
                "ar": "السلوك البشري والديناميكيات الاجتماعية",
                "ku": "ڕەفتاری مرۆڤ و دینامیکیەتی کۆمەڵایەتی"
            },
            "description": {
                "en": "Explore the psychology of persuasion, uncover systematic biases in human decision-making, and learn ancient wisdom for modern relationships.",
                "ar": "استكشف علم نفس الإقناع، واكتشف الانحيازات المنهجية في اتخاذ القرار البشري، وتعلّم الحكمة القديمة للعلاقات الحديثة.",
                "ku": "سایکۆلۆژیای قایلکردن بکۆڵەرەوە، سەرنج بدە سەر لایەنگرییە سیستماتیکییەکان لە بڕیاردانی مرۆڤدا، و دانایی کۆن بۆ پەیوەندییە هاوچەرخەکان فێربە."
            },
            "bookIds": ["influence", "predictably_irrational", "the_four_agreement"]
        }
    ]

    print(f"[*] Seeding {len(paths)} learning paths to Firestore...")
    for p in paths:
        p_id = p["id"]
        data = {
            "title": p["title"],
            "description": p["description"],
            "bookIds": p["bookIds"],
            "category": p["category"]
        }
        try:
            set_firestore_document("learning_paths", p_id, data)
            print(f"  [✓] Seeded learning path: {p_id} ('{p['title']['en']}')")
        except Exception as e:
            print(f"  [!] Failed to seed {p_id}: {e}")
            
    print("[✓] Seeding completed!")

if __name__ == "__main__":
    seed_learning_paths()
