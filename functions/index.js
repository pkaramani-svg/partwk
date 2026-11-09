const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const { Timestamp, FieldValue } = require('firebase-admin/firestore');
const nodemailer = require('nodemailer');

admin.initializeApp();

// ============================================================================
// SMTP CONFIGURATION (NAMECHEAP PRIVATE EMAIL)
// Reads credentials securely from Secret Manager or environment variables
// ============================================================================
const smtpPass = defineSecret('SMTP_PASS');

function getSmtpPassword() {
  try {
    return smtpPass.value() || process.env.SMTP_PASS || "";
  } catch (_) {
    return process.env.SMTP_PASS || "";
  }
}

function getTransporter() {
  const user = process.env.SMTP_USER || "info@partwk.com";
  const pass = getSmtpPassword();
  const host = process.env.SMTP_HOST || "mail.privateemail.com";
  const port = parseInt(process.env.SMTP_PORT || "465", 10);
  const secure = (process.env.SMTP_SECURE || "true") === "true";

  return nodemailer.createTransport({
    host: host,
    port: port,
    secure: secure,
    auth: {
      user: user,
      pass: pass,
    },
  });
}

// Helper function to send emails
async function sendEmail(to, subject, html) {
  const user = process.env.SMTP_USER || "info@partwk.com";
  const pass = getSmtpPassword();
  if (!user || !pass) {
    console.warn("SMTP credentials not configured (SMTP_USER / SMTP_PASS). Skipping email delivery.");
    return;
  }
  const transporter = getTransporter();
  try {
    const info = await transporter.sendMail({
      from: `"Partwk Team" <${user}>`,
      to: to,
      subject: subject,
      html: html,
    });
    console.log("Message sent: %s", info.messageId);
    return info;
  } catch (error) {
    console.error("Error sending email:", error);
    throw error;
  }
}

// ============================================================================
// EMAIL TEMPLATES
// ============================================================================

const logoImg = `<div style="text-align: center; margin-bottom: 20px;"><img src="https://partwk-bd4ec.web.app/email_logo.png?v=emblem-2026" alt="Partwk - Read, Learn, Grow" style="height: 75px; width: auto; max-width: 100%; border: 0; outline: none; display: inline-block;" /></div>`;

const getWelcomeFreeEmailHTML = (name) => `
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #333; background-color: #fff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
  <div style="background-color: #ffffff; padding: 30px 20px; text-align: center; border-bottom: 4px solid #F59E0B;">
    ${logoImg}
    <h1 style="color: #1E293B; margin: 0; font-size: 24px;">Welcome to Partwk!</h1>
  </div>
  <div style="padding: 30px;">
    <p>Hi ${name || 'there'},</p>
    <p>Welcome to Partwk! You are currently on the <strong>Free Plan</strong>. Enjoy limited access to our library of summaries and audiobooks. To unlock unlimited reading, listening, and offline downloads, upgrade to Premium today!</p>
    
    <hr style="border: 0; border-top: 1px solid #E2E8F0; margin: 25px 0;" />
    
    <p dir="rtl" style="text-align: right; font-size: 16px;">بەخێربێیت بۆ پەرتوک! تۆ ئێستا لەسەر پلانی بێبەرامبەریت. چێژ وەربگرە لە دەستڕاگەیشتنێکی سنووردار بە کتێبخانە پوختەکان و پەرتووکە دەنگییەکانمان. بۆ کردنەوە و خوێندنەوە، گوێگرتن، و دابەزاندنی بێسنوور، بەشداری پریمیۆم بکە و سوودمەندبە لە تەواوی پوختەی پەرتووکە دەنگییە کانمان.</p>
    
    <hr style="border: 0; border-top: 1px solid #E2E8F0; margin: 25px 0;" />
    
    <p dir="rtl" style="text-align: right; font-size: 16px;">أهلاً بك في بارتوك! أنت حالياً على <strong>الخطة المجانية</strong>. استمتع بوصول محدود إلى مكتبتنا من الملخصات والكتب الصوتية. لفتح القراءة والاستماع غير المحدود والتنزيلات دون اتصال بالإنترنت، قم بالترقية إلى الخطة المميزة اليوم!</p>
  </div>
</div>
`;

const getPremiumUpgradeEmailHTML = (name, planType, startDate, expiryDate) => `
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #333; background-color: #fff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
  <div style="background-color: #ffffff; padding: 30px 20px; text-align: center; border-bottom: 4px solid #F59E0B;">
    ${logoImg}
    <h1 style="color: #1E293B; margin: 0; font-size: 24px;">Welcome to Premium! 👑</h1>
  </div>
  <div style="padding: 30px;">
    <p>Hi ${name || 'there'},</p>
    <p>Thank you for upgrading to Partwk Premium! Your <strong>${planType}</strong> subscription is now active.</p>
    <ul style="background: #F8FAFC; padding: 15px 30px; border-radius: 8px; border: 1px solid #E2E8F0;">
      <li style="margin-bottom: 8px;"><strong>Start Date:</strong> ${startDate}</li>
      <li><strong>Expiry Date:</strong> ${expiryDate}</li>
    </ul>
    <p>You now have unlimited access to all books, audio, and offline downloads!</p>
    
    <hr style="border: 0; border-top: 1px solid #E2E8F0; margin: 25px 0;" />
    
    <div dir="rtl" style="text-align: right; font-size: 16px;">
      <p>سوپاس بۆ بەرزکردنەوەی هەژمارەکەت بۆ پەرتوک پریمیۆم! بەشداریکردنی <strong>${planType === 'monthly' ? 'مانگانە' : 'ساڵانە'}</strong>ت ئێستا چالاکە.</p>
      <ul style="background: #F8FAFC; padding: 15px 30px; border-radius: 8px; border: 1px solid #E2E8F0; list-style-position: inside;">
        <li style="margin-bottom: 8px;"><strong>بەرواری دەستپێکردن:</strong> ${startDate}</li>
        <li><strong>بەرواری بەسەرچوون:</strong> ${expiryDate}</li>
      </ul>
      <p>ئێستا دەستڕاگەیشتنی بێسنوورت هەیە بۆهەموو پەرتووکەکان، دەنگ، و دابەزاندنەکان!</p>
    </div>
    
    <hr style="border: 0; border-top: 1px solid #E2E8F0; margin: 25px 0;" />
    
    <div dir="rtl" style="text-align: right; font-size: 16px;">
      <p>شكرًا لترقيتك إلى بارتوك المميز! اشتراكك الـ <strong>${planType === 'monthly' ? 'الشهري' : 'السنوي'}</strong> نشط الآن.</p>
      <ul style="background: #F8FAFC; padding: 15px 30px; border-radius: 8px; border: 1px solid #E2E8F0; list-style-position: inside;">
        <li style="margin-bottom: 8px;"><strong>تاريخ البدء:</strong> ${startDate}</li>
        <li><strong>تاريخ الانتهاء:</strong> ${expiryDate}</li>
      </ul>
      <p>لديك الآن وصول غير محدود إلى جميع الكتب والصوتيات والتنزيلات دون اتصال بالإنترنت!</p>
    </div>
  </div>
</div>
`;

const getRenewalReminderEmailHTML = (name, expiryDate) => `
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #333; background-color: #fff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
  <div style="background-color: #ffffff; padding: 30px 20px; text-align: center; border-bottom: 4px solid #F59E0B;">
    ${logoImg}
    <h1 style="color: #1E293B; margin: 0; font-size: 24px;">Your Premium is Expiring Soon! ⏳</h1>
  </div>
  <div style="padding: 30px;">
    <p>Hi ${name || 'there'},</p>
    <p>This is a friendly reminder that your Partwk Premium subscription is set to expire in <strong>3 days</strong> on <strong>${expiryDate}</strong>.</p>
    <p>To ensure uninterrupted access to unlimited summaries, high-quality audio narration, offline downloads, and your AI learning coach, please renew your subscription today.</p>
    
    <hr style="border: 0; border-top: 1px solid #E2E8F0; margin: 25px 0;" />
    
    <div dir="rtl" style="text-align: right; font-size: 16px;">
      <p>بەشداری پریمیۆمەکەت بەم زوانە بەسەردەچێت!</p>
      <p>ئەمە وەبیرهێنانەوەیەکە کە بەشداریکردنی پەرتوک پریمیۆمەکەت لە ماوەی <strong>٣ ڕۆژدا</strong> لە ڕێکەوتی <strong>${expiryDate}</strong> بەسەردەچێت.</p>
      <p>بۆ دڵنیابوون لە دەستڕاگەیشتنی بەردەوام بە پوختەی بێسنوور، خوێندنەوەی دەنگی، دابەزاندنی ئۆفلاین، و ڕاهێنەری زیرەکی دەستکرد، تکایە ئەمڕۆ بەشداریکردنی نوێ بکەرەوە.</p>
    </div>
    
    <hr style="border: 0; border-top: 1px solid #E2E8F0; margin: 25px 0;" />
    
    <div dir="rtl" style="text-align: right; font-size: 16px;">
      <p>اشتراكك المميز سينتهي قريبًا!</p>
      <p>هذا تذكير ودّي بأن اشتراكك في بارتوك المميز سينتهي خلال <strong>٣ أيام</strong> في تاريخ <strong>${expiryDate}</strong>.</p>
      <p>لضمان استمرار وصولك غير المحدود للملخصات، والتعليق الصوتي عالي الجودة، والتنزيلات دون اتصال، ومدرب الذكاء الاصطناعي، يرجى تجديد اشتراكك اليوم.</p>
    </div>
  </div>
</div>
`;

const getFamilyInvitationEmailHTML = (inviterName, recipientEmail, lang) => {
  const isKu = lang === 'ku';
  const isAr = lang === 'ar';
  const appLink = "https://partwk.com";

  if (isKu) {
    return `
<div dir="rtl" style="direction: rtl; text-align: right; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #1E293B; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.08); border: 1px solid #E2E8F0;">
  <div style="background-color: #ffffff; padding: 32px 24px; text-align: center; border-bottom: 4px solid #FF7B00;">
    ${logoImg}
    <h1 style="color: #0F172A; margin: 12px 0 0 0; font-size: 22px; font-weight: 700;">بانگهێشت کراویت بۆ پەرتوک خێزانی! 🌟</h1>
  </div>
  <div style="padding: 28px 24px;">
    <p style="font-size: 16px; line-height: 1.6; margin-top: 0;">سڵاو،</p>
    <p style="font-size: 16px; line-height: 1.6;"><strong>${inviterName || 'بەکارهێنەرێکی پەرتوک'}</strong> تۆی بانگهێشت کردووە بۆ بەشداریکردنی خێزانی لە <strong>پەرتوک (Partwk Family Sharing)</strong>.</p>
    
    <div style="background-color: #FFF7ED; border-right: 4px solid #FF7B00; padding: 16px; border-radius: 8px; margin: 20px 0;">
      <p style="margin: 0; font-size: 15px; line-height: 1.6; color: #9A3412;">
        <strong>تایبەتمەندی بەشداریکردن:</strong> تۆ دەستڕاگەیشتنی تەواوی پریمیۆم (Premium) بەدەستدەهێنیت لەڕێگەی بەشداریکردنی سەرەکییەوە بە بێبەرامبەر.
      </p>
    </div>

    <p style="font-size: 15px; line-height: 1.6; color: #475569;">
      دەستڕاگەیشتنی پریمیۆمەکەت بەردەوام دەبێت هەتاوەکو بەشداریکردنی سەرەکی چالاک بێت، و خۆکارانە کۆتایی دێت کاتێک بەشداریکردنی سەرەکی بەسەربچێت یان خاوەنی هەژمارەکە تۆ لابدات یان پلانی خێزانی جێبهێڵێت.
    </p>

    <div style="margin: 24px 0; background: #F8FAFC; padding: 20px; border-radius: 10px; border: 1px solid #E2E8F0;">
      <h3 style="margin: 0 0 12px 0; font-size: 16px; color: #0F172A;">چۆنێتی چالاککردنی پریمیۆم:</h3>
      <ol style="margin: 0; padding-right: 20px; font-size: 15px; line-height: 1.8; color: #334155;">
        <li>بە هەمان ئەم ناونیشانی ئیمەیڵەی خۆت (<strong>${recipientEmail}</strong>) لە پەرتوک بچۆ ژوورەوە یان هەژمارێکی نوێ دروستبکە.</li>
        <li>لەناو ئەپڵیکەیشن بچۆ بۆ <strong>ڕێکخستنەکان (Settings) ← بەشداریکردنی خێزانی (Family Sharing)</strong>.</li>
        <li>کرتە بکە لەسەر <strong>قبوڵکردنی بانگهێشتنامە</strong> بۆ چالاککردنی دەستبەجێی تایبەتمەندییەکان.</li>
      </ol>
    </div>

    <p style="font-size: 15px; line-height: 1.6; color: #475569;">
      لە کاتی چالاکبوونی پلانی خێزانیدا، دەتوانیت بە بێسنووری پوختەی سەدان پەرتووک بخوێنیتەوە و گوێیان لێ بگریت، دابەزاندنی ئۆفلاین بکەیت و لە هەموو مۆڵەتەکانی پریمیۆم سوودمەند بیت.
    </p>

    <div style="text-align: center; margin: 32px 0 16px 0;">
      <a href="${appLink}" style="background-color: #FF7B00; color: #ffffff; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-size: 16px; font-weight: bold; display: inline-block;">کردنەوەی پەرتوک</a>
    </div>
  </div>
</div>`;
  }

  if (isAr) {
    return `
<div dir="rtl" style="direction: rtl; text-align: right; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #1E293B; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.08); border: 1px solid #E2E8F0;">
  <div style="background-color: #ffffff; padding: 32px 24px; text-align: center; border-bottom: 4px solid #FF7B00;">
    ${logoImg}
    <h1 style="color: #0F172A; margin: 12px 0 0 0; font-size: 22px; font-weight: 700;">تمت دعوتك إلى بارتوك العائلي! 🌟</h1>
  </div>
  <div style="padding: 28px 24px;">
    <p style="font-size: 16px; line-height: 1.6; margin-top: 0;">مرحبًا،</p>
    <p style="font-size: 16px; line-height: 1.6;">دعاك <strong>${inviterName || 'أحد مستخدمي بارتوك'}</strong> للانضمام إلى خطة <strong>المشاركة العائلية في بارتوك (Partwk Family Sharing)</strong>.</p>
    
    <div style="background-color: #FFF7ED; border-right: 4px solid #FF7B00; padding: 16px; border-radius: 8px; margin: 20px 0;">
      <p style="margin: 0; font-size: 15px; line-height: 1.6; color: #9A3412;">
        <strong>ميزة الاشتراك:</strong> ستحصل على وصول كامل وغير محدود إلى باقة بارتوك بريميوم (Premium) عبر المشترك الأساسي دون أي تكلفة إضافية.
      </p>
    </div>

    <p style="font-size: 15px; line-height: 1.6; color: #475569;">
      ينتهي وصولك إلى بريميوم تلقائيًا عند انتهاء اشتراك المشترك الأساسي، أو إذا قام المشترك الأساسي بإزالة العضو أو مغادرة الخطة العائلية.
    </p>

    <div style="margin: 24px 0; background: #F8FAFC; padding: 20px; border-radius: 10px; border: 1px solid #E2E8F0;">
      <h3 style="margin: 0 0 12px 0; font-size: 16px; color: #0F172A;">خطوات تفعيل الاشتراك:</h3>
      <ol style="margin: 0; padding-right: 20px; font-size: 15px; line-height: 1.8; color: #334155;">
        <li>سجّل الدخول أو أنشئ حسابًا جديدًا في بارتوك باستخدام نفس هذا البريد الإلكتروني (<strong>${recipientEmail}</strong>).</li>
        <li>في التطبيق، انتقل إلى <strong>الإعدادات (Settings) ← المشاركة العائلية (Family Sharing)</strong>.</li>
        <li>اضغط على <strong>قبول الدعوة</strong> لتفعيل باقة بريميوم فورًا.</li>
      </ol>
    </div>

    <p style="font-size: 15px; line-height: 1.6; color: #475569;">
      طالما أن الاشتراك العائلي نشط، يمكنك قراءة والاستماع إلى ملخصات الكتب بلا حدود والاستفادة من التحميل دون اتصال وكافة مزايا بريميوم.
    </p>

    <div style="text-align: center; margin: 32px 0 16px 0;">
      <a href="${appLink}" style="background-color: #FF7B00; color: #ffffff; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-size: 16px; font-weight: bold; display: inline-block;">فتح تطبيق بارتوك</a>
    </div>
  </div>
</div>`;
  }

  // English fallback
  return `
<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #1E293B; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.08); border: 1px solid #E2E8F0;">
  <div style="background-color: #ffffff; padding: 32px 24px; text-align: center; border-bottom: 4px solid #FF7B00;">
    ${logoImg}
    <h1 style="color: #0F172A; margin: 12px 0 0 0; font-size: 22px; font-weight: 700;">You're Invited to Partwk Family Sharing! 🌟</h1>
  </div>
  <div style="padding: 28px 24px;">
    <p style="font-size: 16px; line-height: 1.6; margin-top: 0;">Hi there,</p>
    <p style="font-size: 16px; line-height: 1.6;"><strong>${inviterName || 'A Partwk member'}</strong> has invited you to join their <strong>Partwk Family Sharing</strong> plan.</p>
    
    <div style="background-color: #FFF7ED; border-left: 4px solid #FF7B00; padding: 16px; border-radius: 8px; margin: 20px 0;">
      <p style="margin: 0; font-size: 15px; line-height: 1.6; color: #9A3412;">
        <strong>Your Benefit:</strong> You receive full Partwk Premium access through the primary subscriber at no additional cost.
      </p>
    </div>

    <p style="font-size: 15px; line-height: 1.6; color: #475569;">
      Your Premium access remains active as long as the primary subscriber's plan is active. It ends automatically if the primary subscription expires, or if the primary member removes or leaves the family plan.
    </p>

    <div style="margin: 24px 0; background: #F8FAFC; padding: 20px; border-radius: 10px; border: 1px solid #E2E8F0;">
      <h3 style="margin: 0 0 12px 0; font-size: 16px; color: #0F172A;">How to Activate Your Access:</h3>
      <ol style="margin: 0; padding-left: 20px; font-size: 15px; line-height: 1.8; color: #334155;">
        <li>Sign in or create a Partwk account using this exact email address (<strong>${recipientEmail}</strong>).</li>
        <li>Open <strong>Settings &rarr; Family Sharing</strong> in the app.</li>
        <li>Tap <strong>Accept Invitation</strong> to immediately activate Premium.</li>
      </ol>
    </div>

    <p style="font-size: 15px; line-height: 1.6; color: #475569;">
      Once accepted, you will have unlimited access to read and listen to all book summaries, download editions offline, and explore all Premium features.
    </p>

    <div style="text-align: center; margin: 32px 0 16px 0;">
      <a href="${appLink}" style="background-color: #FF7B00; color: #ffffff; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-size: 16px; font-weight: bold; display: inline-block;">Open Partwk</a>
    </div>
  </div>
</div>`;
};

// ============================================================================
// CLOUD FUNCTIONS
// ============================================================================

// Trigger: When a new user registers (document created in 'users' collection)
exports.onUserCreated = onDocumentCreated({ document: 'users/{userId}', secrets: [smtpPass] }, async (event) => {
    const snap = event.data;
    if (!snap) return;
    const userData = snap.data();
    
    // Only send if email exists
    if (userData && userData.email) {
      console.log(`Sending Welcome Free Email to ${userData.email}`);
      const htmlContent = getWelcomeFreeEmailHTML(userData.name);
      await sendEmail(userData.email, "Welcome to Partwk! (Free Plan)", htmlContent);
    }
  });

// Trigger: When an existing user updates their profile/subscription
exports.onUserUpdated = onDocumentUpdated({ document: 'users/{userId}', secrets: [smtpPass] }, async (event) => {
    if (!event.data) return;
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    // Check if subscriptionStatus changed from 'free' (or undefined) to 'premium' (or 'pro')
    const wasFree = !beforeData.subscriptionStatus || beforeData.subscriptionStatus === 'free';
    const isNowPremium = afterData.subscriptionStatus === 'premium' || afterData.subscriptionStatus === 'pro';

    if (wasFree && isNowPremium) {
      // Clear sentExpiryReminder3Days so it can be sent again on next expiry
      const db = admin.firestore();
      await db.collection('users').doc(event.params.userId).update({
        sentExpiryReminder3Days: FieldValue.delete()
      }).catch(err => console.error("Error clearing sentExpiryReminder3Days:", err));

      if (afterData.email) {
        console.log(`Sending Premium Upgrade Email to ${afterData.email}`);
        
        const planType = afterData.subscriptionPlanType || 'monthly';
        const startDate = afterData.subscriptionStartDate ? new Date(afterData.subscriptionStartDate).toLocaleDateString() : new Date().toLocaleDateString();
        const expiryDate = afterData.subscriptionExpiryDate ? new Date(afterData.subscriptionExpiryDate).toLocaleDateString() : 'Unknown';

        const htmlContent = getPremiumUpgradeEmailHTML(afterData.name, planType, startDate, expiryDate);
        await sendEmail(afterData.email, "Welcome to Partwk Premium! 👑", htmlContent);
      }
    }
  });

// Trigger: When a user document is deleted from Firestore, delete the Auth record
exports.onUserDeleted = onDocumentDeleted('users/{userId}', async (event) => {
    const userId = event.params.userId;
    try {
        await admin.auth().deleteUser(userId);
        console.log(`Successfully deleted auth user: ${userId}`);
    } catch (error) {
        // If error is user-not-found, it's fine.
        console.error(`Error deleting auth user ${userId}:`, error.message);
    }
});

const getPasswordResetEmailHTML = (link) => `
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #333; background-color: #fff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
  <div style="background-color: #ffffff; padding: 30px 20px; text-align: center; border-bottom: 4px solid #F59E0B;">
    ${logoImg}
    <h1 style="color: #1E293B; margin: 0; font-size: 24px;">Reset Your Password</h1>
  </div>
  <div style="padding: 30px; text-align: center;">
    <p>We received a request to reset your password for your Partwk account.</p>
    <p>Click the button below to choose a new password. If you didn't request this, you can safely ignore this email.</p>
    
    <a href="${link}" style="display: inline-block; background-color: #F59E0B; color: white; text-decoration: none; padding: 14px 28px; border-radius: 8px; font-weight: bold; margin: 20px 0;">Reset Password</a>
    
    <hr style="border: 0; border-top: 1px solid #E2E8F0; margin: 25px 0;" />
    
    <div dir="rtl" style="text-align: right; font-size: 16px;">
      <p>داواکارییەکمان پێگەیشت بۆ گۆڕینی وشەی نهێنی هەژماری پەرتوکەکەت.</p>
      <p>کرتە لە دوگمەی خوارەوە بکە بۆ هەڵبژاردنی وشەیەکی نهێنی نوێ. ئەگەر تۆ ئەم داواکارییەت نەکردووە، دەتوانیت پشتگوێی بخەیت.</p>
      <div style="text-align: center;">
        <a href="${link}" style="display: inline-block; background-color: #F59E0B; color: white; text-decoration: none; padding: 14px 28px; border-radius: 8px; font-weight: bold; margin: 20px 0;">گۆڕینی وشەی نهێنی</a>
      </div>
    </div>
    
    <hr style="border: 0; border-top: 1px solid #E2E8F0; margin: 25px 0;" />
    
    <div dir="rtl" style="text-align: right; font-size: 16px;">
      <p>تلقينا طلبًا لإعادة تعيين كلمة المرور لحساب بارتوك الخاص بك.</p>
      <p>انقر على الزر أدناه لاختيار كلمة مرور جديدة. إذا لم تقم بهذا الطلب، يمكنك تجاهل هذا البريد الإلكتروني بأمان.</p>
      <div style="text-align: center;">
        <a href="${link}" style="display: inline-block; background-color: #F59E0B; color: white; text-decoration: none; padding: 14px 28px; border-radius: 8px; font-weight: bold; margin: 20px 0;">إعادة تعيين كلمة المرور</a>
      </div>
    </div>
  </div>
</div>
`;

exports.sendCustomPasswordReset = onCall({ secrets: [smtpPass] }, async (request) => {
    const rawEmail = request.data?.email;
    if (!rawEmail || typeof rawEmail !== 'string') {
        throw new HttpsError('invalid-argument', 'The function must be called with an "email" argument.');
    }
    const email = rawEmail.trim().toLowerCase();

    try {
        const link = await admin.auth().generatePasswordResetLink(email);
        const htmlContent = getPasswordResetEmailHTML(link);
        await sendEmail(email, "Reset Your Partwk Password", htmlContent);
        
        return { success: true, message: "If an account exists with this email, a password reset link has been sent." };
    } catch (error) {
        if (error.code === 'auth/user-not-found') {
            // Generic success response to prevent account enumeration
            console.log(`Password reset requested for non-existent email: ${email}. Returning generic success.`);
            return { success: true, message: "If an account exists with this email, a password reset link has been sent." };
        }
        console.error("Error sending custom password reset:", error);
        throw new HttpsError('internal', 'Unable to send password reset email.', error.message);
    }
});

// Scheduled job running daily to check premium expirations and send reminders
exports.checkPremiumExpirations = onSchedule({ schedule: 'every day 00:00', secrets: [smtpPass] }, async (event) => {
  const db = admin.firestore();
  const now = new Date();

  // 1. Query all premium users to find expired ones
  const premiumUsers = await db.collection('users')
    .where('subscriptionStatus', 'in', ['premium', 'pro'])
    .get();

  console.log(`Checking expirations for ${premiumUsers.docs.length} premium users.`);

  for (const docSnap of premiumUsers.docs) {
    const userData = docSnap.data();
    const expiryStr = userData.subscriptionExpiryDate;
    if (expiryStr) {
      const expiryDate = new Date(expiryStr);
      if (expiryDate <= now) {
        console.log(`User ${userData.email || docSnap.id} premium expired on ${expiryStr}. Downgrading to free.`);
        await db.collection('users').doc(docSnap.id).update({
          subscriptionStatus: 'free',
        });
      } else {
        // Expiry date is in the future. Check if they expire in exactly 3 days.
        const diffTime = expiryDate.getTime() - now.getTime();
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        
        if (diffDays === 3 && !userData.sentExpiryReminder3Days) {
          console.log(`User ${userData.email || docSnap.id} is expiring in 3 days. Sending renewal reminder.`);
          if (userData.email) {
            const formattedExpiry = expiryDate.toLocaleDateString();
            const htmlContent = getRenewalReminderEmailHTML(userData.name, formattedExpiry);
            await sendEmail(userData.email, "Your Partwk Premium is Expiring Soon! ⏳", htmlContent);
            await db.collection('users').doc(docSnap.id).update({
              sentExpiryReminder3Days: true
            });
          }
        }
      }
    }
  }
});

exports.adminUpdateUserPassword = onCall(async (request) => {
  // 1. Enforce Authentication
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required. Caller must be signed in.');
  }

  // 2. Enforce Admin Authorization
  const callerUid = request.auth.uid;
  const callerEmail = (request.auth.token.email || '').toLowerCase();
  let isCallerAdmin = callerUid === '9ZpveoOzAednE7Z3J5viC3hPfgC3' ||
                      request.auth.token.admin === true ||
                      callerEmail === 'pkaramani@gmail.com' ||
                      callerEmail === 'admin@partwk.com';

  if (!isCallerAdmin) {
    try {
      const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
      if (callerDoc.exists && callerDoc.data()?.role === 'admin') {
        isCallerAdmin = true;
      }
    } catch (e) {
      console.warn("Could not check caller doc for admin role:", e);
    }
  }

  if (!isCallerAdmin) {
    throw new HttpsError('permission-denied', 'Access denied. Administrator privileges required.');
  }

  const { uid, email, newPassword } = request.data || {};
  if ((!uid && !email) || !newPassword) {
    throw new HttpsError('invalid-argument', 'Must provide (uid or email) and newPassword.');
  }

  if (typeof newPassword !== 'string' || newPassword.length < 6) {
    throw new HttpsError('invalid-argument', 'Password must be at least 6 characters long.');
  }

  try {
    let targetUid = uid;
    if (targetUid) {
      try {
        await admin.auth().getUser(targetUid);
      } catch (err) {
        if (err.code === 'auth/user-not-found' && email) {
          const userRecord = await admin.auth().getUserByEmail(email.trim().toLowerCase());
          targetUid = userRecord.uid;
        } else {
          throw err;
        }
      }
    } else if (email) {
      const userRecord = await admin.auth().getUserByEmail(email.trim().toLowerCase());
      targetUid = userRecord.uid;
    }

    // Direct password update in Firebase Authentication ONLY
    await admin.auth().updateUser(targetUid, { password: newPassword });

    // Update only timestamp metadata in Firestore - NEVER write password or hash to database
    await admin.firestore().collection('users').doc(targetUid).set({
      passwordUpdatedAt: new Date().toISOString()
    }, { merge: true });

    return { success: true, message: "User password updated successfully in Firebase Auth." };
  } catch (error) {
    console.error("Error updating user password:", error);
    if (error.code === 'auth/user-not-found') {
      throw new HttpsError('not-found', 'User account was not found in Firebase Authentication.');
    }
    if (error.code === 'auth/weak-password') {
      throw new HttpsError('invalid-argument', 'Password does not meet complexity requirements.');
    }
    throw new HttpsError('internal', error.message || 'Unable to update password.', error);
  }
});

// ============================================================================
// TRUSTED FAMILY + ENTITLEMENT OPERATIONS
// ============================================================================
// These callables are deliberately the sole writer for /families,
// /familyMemberships and /entitlements. Invitations are in-app records; email
// is not a security dependency and is intentionally not sent from this code.
const db = admin.firestore();
const ts = () => Timestamp.now();

function requireUser(request) {
  if (!request.auth || request.auth.token.firebase?.sign_in_provider === 'anonymous') {
    throw new HttpsError('unauthenticated', 'A registered account is required.');
  }
  return request.auth.uid;
}
function isAdminToken(request) {
  return request.auth && (request.auth.token.admin === true || request.auth.uid === '9ZpveoOzAednE7Z3J5viC3hPfgC3');
}
function activeEntitlement(data) {
  if (!data) return false;
  const expiry = data.expiresAt;
  return data.status === 'active' && (!expiry || expiry.toMillis() > Date.now());
}
async function writeAudit(actorUid, action, details) {
  await db.collection('audit_logs').add({ actorUid, action, details, createdAt: ts(), source: 'trusted-family-function' });
}
async function effectiveEntitlement(uid, transaction) {
  const ref = db.doc(`entitlements/${uid}`);
  const snap = transaction ? await transaction.get(ref) : await ref.get();
  return { ref, data: snap.exists ? snap.data() : null };
}

// Publish only the selected draft language; other published languages and
// the draft are left in place. Catalogue and private text commit atomically.
exports.publishBookLanguage = onCall(async request => {
  requireUser(request);
  if (!isAdminToken(request)) throw new HttpsError('permission-denied', 'Administrator required.');
  const bookId = String(request.data?.bookId || '');
  const language = String(request.data?.language || '');
  if (!/^[A-Za-z0-9_-]{1,150}$/.test(bookId) || !['en', 'ku', 'ar'].includes(language)) {
    throw new HttpsError('invalid-argument', 'Invalid book or language.');
  }
  await db.runTransaction(async transaction => {
    const pubRef = db.doc(`books/${bookId}`), draftRef = db.doc(`books_draft/${bookId}`), privateRef = db.doc(`premiumBookText/${bookId}`);
    const studyQuery = collection => db.collection(collection).where('bookId', '==', bookId).where('langCode', '==', language);
    const [published, draft, privateSnap, draftQuizzes, draftCards, oldQuizzes, oldCards] = await Promise.all([
      transaction.get(pubRef), transaction.get(draftRef), transaction.get(privateRef),
      transaction.get(studyQuery('quizzes_draft')), transaction.get(studyQuery('flashcards_draft')),
      transaction.get(studyQuery('quizzes')), transaction.get(studyQuery('flashcards')),
    ]);
    if (!draft.exists) throw new HttpsError('not-found', 'Draft not found.');
    const incoming = draft.data(), old = published.exists ? published.data() : null;
    if (old && (old.isPremium === true) !== (incoming.isPremium === true)) throw new HttpsError('failed-precondition', 'Book classification cannot change during publication.');
    if (old && old.isPremium === true && old.premiumTextVersion !== 2) throw new HttpsError('failed-precondition', 'Existing Premium text requires migration before publishing.');
    const sourceChapters = incoming.chapterSummaries?.[language];
    if (!Array.isArray(sourceChapters) || !sourceChapters.length || sourceChapters.some(ch => typeof ch?.content !== 'string')) {
      throw new HttpsError('failed-precondition', 'The selected language needs complete chapter text.');
    }
    const safe = old ? {...old} : {...incoming, title: {}, author: {}, description: {}, coverImageUrl: {}, audioUrl: {}, chapterSummaries: {}, fiveMinuteSummary: {}, fifteenMinuteSummary: {}, keyIdeas: {}, keyQuotes: {}, actionPoints: {}};
    const privateData = privateSnap.exists ? privateSnap.data() : {};
    const privateLanguages = {...(privateData.languages || {})}, privateStudy = {...(privateData.study || {})};
    const chapters = {...(safe.chapterSummaries || {})};
    const hidden = Array.isArray(safe.hiddenLanguages) ? safe.hiddenLanguages.filter(v => v !== language) : [];
    // A public document must not retain hidden language text, even for a free book.
    for (const hiddenLang of hidden) {
      if (chapters[hiddenLang] || ['fiveMinuteSummary', 'fifteenMinuteSummary', 'keyIdeas', 'keyQuotes', 'actionPoints'].some(field => safe[field]?.[hiddenLang] !== undefined)) {
        throw new HttpsError('failed-precondition', 'Existing hidden language requires migration before publishing.');
      }
    }
    const premium = incoming.isPremium === true;
    if (premium) {
      privateLanguages[language] = sourceChapters.map(ch => ({content: ch.content, segmentTexts: Array.isArray(ch.segments) ? ch.segments.map(s => s.text ?? '') : []}));
      chapters[language] = sourceChapters.map(ch => { const item = {...ch}; delete item.content; if (Array.isArray(item.segments)) item.segments = item.segments.map(s => { const part = {...s}; delete part.text; return part; }); return item; });
    } else {
      chapters[language] = sourceChapters;
      delete privateLanguages[language];
    }
    safe.chapterSummaries = chapters;
    for (const field of ['title', 'author', 'description', 'coverImageUrl', 'audioUrl']) {
      if (incoming[field] && typeof incoming[field] === 'object' && incoming[field][language] !== undefined) safe[field] = {...(typeof safe[field] === 'object' ? safe[field] : {}), [language]: incoming[field][language]};
    }
    for (const field of ['fiveMinuteSummary', 'fifteenMinuteSummary', 'keyIdeas', 'keyQuotes', 'actionPoints']) {
      const value = incoming[field]?.[language];
      const publicField = {...(safe[field] || {})};
      if (premium) { if (value !== undefined) (privateStudy[language] ||= {})[field] = value; delete publicField[language]; }
      else if (value !== undefined) publicField[language] = value;
      safe[field] = publicField;
    }
    const incomingCategories = Array.isArray(incoming.categories) && incoming.categories.length ? incoming.categories : (Array.isArray(incoming.categoryIds) && incoming.categoryIds.length ? incoming.categoryIds : (incoming.category ? [incoming.category] : null));
    if (incomingCategories) {
      safe.categoryIds = incomingCategories;
      safe.categories = incomingCategories;
    } else if (!old) {
      safe.categoryIds = [];
      safe.categories = [];
    } else {
      safe.categoryIds = Array.isArray(old.categoryIds) ? old.categoryIds : (Array.isArray(old.categories) ? old.categories : (old.category ? [old.category] : []));
      safe.categories = safe.categoryIds;
    }
    safe.premiumTextVersion = 2;
    if (draftQuizzes.size + draftCards.size + oldQuizzes.size + oldCards.size > 400) {
      throw new HttpsError('resource-exhausted', 'Too many study records to publish atomically.');
    }
    transaction.set(privateRef, {...privateData, languages: privateLanguages, study: privateStudy});
    transaction.set(pubRef, safe);
    if (!draftQuizzes.empty) {
      for (const item of oldQuizzes.docs) transaction.delete(item.ref);
      for (const item of draftQuizzes.docs) transaction.set(db.doc(`quizzes/${item.id}`), item.data());
    }
    if (!draftCards.empty) {
      for (const item of oldCards.docs) transaction.delete(item.ref);
      for (const item of draftCards.docs) transaction.set(db.doc(`flashcards/${item.id}`), item.data());
    }
  });
  return {status: 'published', language};
});

exports.getBookForEditing = onCall(async request => {
  requireUser(request);
  if (!isAdminToken(request)) throw new HttpsError('permission-denied', 'Administrator required.');
  const bookId = String(request.data?.bookId || '');
  if (!/^[A-Za-z0-9_-]{1,150}$/.test(bookId)) throw new HttpsError('invalid-argument', 'Invalid book.');
  const [draft, published, privateSnap, hiddenSnap] = await Promise.all([
    db.doc(`books_draft/${bookId}`).get(), db.doc(`books/${bookId}`).get(),
    db.doc(`premiumBookText/${bookId}`).get(), db.doc(`unpublishedBookLanguages/${bookId}`).get(),
  ]);
  if (draft.exists) return {book: draft.data()};
  if (!published.exists) throw new HttpsError('not-found', 'Book not found.');
  const book = published.data();
  const content = privateSnap.exists ? privateSnap.data() : {};
  for (const [language, texts] of Object.entries(content.languages || {})) {
    const chapters = book.chapterSummaries?.[language];
    if (!Array.isArray(chapters) || !Array.isArray(texts) || chapters.length !== texts.length) continue;
    book.chapterSummaries[language] = chapters.map((chapter, i) => {
      const updated = {...chapter, content: texts[i].content};
      if (Array.isArray(chapter.segments) && Array.isArray(texts[i].segmentTexts) && chapter.segments.length === texts[i].segmentTexts.length) {
        updated.segments = chapter.segments.map((segment, j) => ({...segment, text: texts[i].segmentTexts[j]}));
      }
      return updated;
    });
  }
  for (const [language, fields] of Object.entries(content.study || {})) {
    for (const [field, value] of Object.entries(fields)) book[field] = {...(book[field] || {}), [language]: value};
  }
  if (hiddenSnap.exists) for (const [language, fields] of Object.entries(hiddenSnap.data().languages || {})) {
    for (const [field, value] of Object.entries(fields)) book[field] = {...(book[field] || {}), [language]: value};
  }
  return {book};
});

exports.setBookLanguageVisibility = onCall(async request => {
  requireUser(request);
  if (!isAdminToken(request)) throw new HttpsError('permission-denied', 'Administrator required.');
  const bookId = String(request.data?.bookId || ''), language = String(request.data?.language || '');
  const visible = request.data?.visible;
  if (!/^[A-Za-z0-9_-]{1,150}$/.test(bookId) || !['en', 'ku', 'ar'].includes(language) || typeof visible !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Invalid book, language or visibility.');
  }
  await db.runTransaction(async transaction => {
    const bookRef = db.doc(`books/${bookId}`), hiddenRef = db.doc(`unpublishedBookLanguages/${bookId}`);
    const [bookSnap, hiddenSnap] = await Promise.all([transaction.get(bookRef), transaction.get(hiddenRef)]);
    if (!bookSnap.exists) throw new HttpsError('not-found', 'Book not found.');
    const book = bookSnap.data(), languages = {...(hiddenSnap.exists ? hiddenSnap.data().languages || {} : {})};
    const hidden = Array.isArray(book.hiddenLanguages) ? [...book.hiddenLanguages] : [];
    const fields = ['chapterSummaries', 'fiveMinuteSummary', 'fifteenMinuteSummary', 'keyIdeas', 'keyQuotes', 'actionPoints'];
    if (!visible) {
      if (hidden.includes(language) && !book.chapterSummaries?.[language]) return;
      const saved = {...(languages[language] || {})};
      for (const field of fields) {
        const values = {...(book[field] || {})};
        if (values[language] !== undefined) { saved[field] = values[language]; delete values[language]; }
        book[field] = values;
      }
      languages[language] = saved;
      if (!hidden.includes(language)) hidden.push(language);
    } else {
      const saved = languages[language];
      if (!saved || !Array.isArray(saved.chapterSummaries)) throw new HttpsError('failed-precondition', 'No protected language is available to publish.');
      for (const field of fields) if (saved[field] !== undefined) book[field] = {...(book[field] || {}), [language]: saved[field]};
      delete languages[language];
    }
    book.hiddenLanguages = visible ? hidden.filter(item => item !== language) : hidden;
    transaction.set(hiddenRef, {languages});
    transaction.set(bookRef, book);
  });
  return {status: visible ? 'published' : 'hidden'};
});

// Private chapter text never leaves Firestore through a direct client read.
// A family projection alone is not enough: verify the current owner and link.
exports.getPremiumChapterText = onCall(async request => {
  const uid = requireUser(request);
  const bookId = String(request.data?.bookId || '');
  const language = String(request.data?.language || '');
  if (!/^[A-Za-z0-9_-]{1,150}$/.test(bookId) || !['en', 'ku', 'ar'].includes(language)) {
    throw new HttpsError('invalid-argument', 'Invalid book or language.');
  }
  const [book, textDoc, entitlement] = await Promise.all([
    db.doc(`books/${bookId}`).get(), db.doc(`premiumBookText/${bookId}`).get(),
    db.doc(`entitlements/${uid}`).get(),
  ]);
  if (!book.exists || book.data().isPublished === false || book.data().isPremium !== true ||
      (book.data().hiddenLanguages || []).includes(language) || !textDoc.exists ||
      !Array.isArray(textDoc.data().languages?.[language])) {
    throw new HttpsError('not-found', 'Content unavailable.');
  }
  const access = entitlement.exists ? entitlement.data() : null;
  if (!activeEntitlement(access)) throw new HttpsError('permission-denied', 'Premium access required.');
  if (access.source === 'family') {
    const ownerUid = access.ownerUid;
    if (typeof ownerUid !== 'string' || !ownerUid || ownerUid.includes('/')) throw new HttpsError('permission-denied', 'Family access unavailable.');
    const [owner, family, membership] = await Promise.all([
      db.doc(`entitlements/${ownerUid}`).get(), db.doc(`families/${ownerUid}`).get(),
      db.doc(`familyMemberships/${uid}`).get(),
    ]);
    if (!owner.exists || !activeEntitlement(owner.data()) || owner.data().source === 'family' ||
        !family.exists || family.data().memberUid !== uid || !membership.exists ||
        membership.data().state !== 'active' || membership.data().ownerUid !== ownerUid) {
      throw new HttpsError('permission-denied', 'Family access unavailable.');
    }
  }
  return { chapters: textDoc.data().languages[language], study: textDoc.data().study?.[language] || {} };
});
async function projectMember(transaction, memberUid, ownerUid, expiresAt, state) {
  transaction.set(db.doc(`familyMemberships/${memberUid}`), {
    ownerUid, memberUid, state, expiresAt: expiresAt || null, updatedAt: ts(),
  });
  transaction.set(db.doc(`entitlements/${memberUid}`), {
    status: state === 'active' ? 'active' : 'inactive',
    source: state === 'active' ? 'family' : 'none',
    ownerUid: state === 'active' ? ownerUid : null,
    expiresAt: state === 'active' ? expiresAt || null : null,
    updatedAt: ts(),
  }, { merge: true });
  transaction.set(db.doc(`users/${memberUid}`), {
    hasFamilyPremium: state === 'active',
  }, { merge: true });
}

exports.inviteFamilyMember = onCall({ secrets: [smtpPass] }, async (request) => {
  const ownerUid = requireUser(request);
  const ownerEntPre = (await effectiveEntitlement(ownerUid)).data;
  if (!activeEntitlement(ownerEntPre) || ownerEntPre.source === 'family') {
    throw new HttpsError('failed-precondition', 'Only an active primary Premium subscriber can invite.');
  }
  const email = String(request.data?.email || '').trim().toLowerCase();
  if (!/^\S+@\S+\.\S+$/.test(email)) throw new HttpsError('invalid-argument', 'Enter a valid email address.');

  // Find inviter details
  let ownerName = '';
  let ownerLang = String(request.data?.language || '').trim().toLowerCase();
  try {
    const ownerRecord = await admin.auth().getUser(ownerUid);
    ownerName = ownerRecord.displayName || '';
    const ownerDoc = await db.doc(`users/${ownerUid}`).get();
    if (ownerDoc.exists) {
      if (!ownerName && ownerDoc.data().name) ownerName = ownerDoc.data().name;
      if (!ownerLang && ownerDoc.data().selectedLanguage) ownerLang = ownerDoc.data().selectedLanguage;
    }
  } catch (_) {}

  // Check if recipient has an existing registered auth account
  let recipient = null;
  let recipientLang = '';
  try {
    recipient = await admin.auth().getUserByEmail(email);
    if (recipient) {
      const recipientDoc = await db.doc(`users/${recipient.uid}`).get();
      if (recipientDoc.exists && recipientDoc.data().selectedLanguage) {
        recipientLang = recipientDoc.data().selectedLanguage;
      }
    }
  } catch (_) {
    // Recipient has no account yet; invitation will be stored for subsequent claim
    recipient = null;
  }

  if (recipient && recipient.uid === ownerUid) {
    throw new HttpsError('invalid-argument', 'You cannot invite your own account.');
  }

  // Determine email language preference:
  // 1. Recipient's saved app language
  // 2. Inviter's selected app language
  // 3. Fallback to English
  let targetLang = 'en';
  if (['en', 'ku', 'ar'].includes(recipientLang)) {
    targetLang = recipientLang;
  } else if (['en', 'ku', 'ar'].includes(ownerLang)) {
    targetLang = ownerLang;
  }

  // Atomically reserve the one family slot
  await db.runTransaction(async transaction => {
    const [ownerEnt, ownerFamily] = await Promise.all([
      effectiveEntitlement(ownerUid, transaction),
      transaction.get(db.doc(`families/${ownerUid}`)),
    ]);

    if (!activeEntitlement(ownerEnt.data) || ownerEnt.data.source === 'family') {
      throw new HttpsError('failed-precondition', 'Only an active primary Premium subscriber can invite.');
    }

    const family = ownerFamily.exists ? ownerFamily.data() : {};
    if (family.memberUid || family.invitation) {
      throw new HttpsError('failed-precondition', 'Your one family slot is already reserved or active.');
    }

    if (recipient) {
      const [recipientMember, recipientEnt] = await Promise.all([
        transaction.get(db.doc(`familyMemberships/${recipient.uid}`)),
        effectiveEntitlement(recipient.uid, transaction),
      ]);
      if (recipientMember.exists && ['pending', 'active'].includes(recipientMember.data().state)) {
        throw new HttpsError('failed-precondition', 'That account is already in a family relationship.');
      }
      if (activeEntitlement(recipientEnt.data) && recipientEnt.data.source !== 'family') {
        throw new HttpsError('failed-precondition', 'That account has its own paid access and cannot join a family.');
      }
    }

    transaction.set(db.doc(`families/${ownerUid}`), {
      ownerUid,
      invitation: {
        recipientUid: recipient ? recipient.uid : null,
        recipientEmail: email,
        createdAt: ts(),
      },
      updatedAt: ts(),
    }, { merge: true });

    if (recipient) {
      transaction.set(db.doc(`familyMemberships/${recipient.uid}`), {
        ownerUid,
        memberUid: recipient.uid,
        state: 'pending',
        updatedAt: ts(),
      });
    }
  });

  // Prepare email
  let subject = '';
  if (targetLang === 'ku') {
    subject = `${ownerName || 'بەکارهێنەرێکی پەرتوک'} بانگهێشتی کردوویت بۆ بەشداریکردنی خێزانی لە پەرتوک`;
  } else if (targetLang === 'ar') {
    subject = `${ownerName || 'مستخدم في بارتوك'} دعاك للانضمام إلى بارتوك العائلي`;
  } else {
    subject = `${ownerName || 'A Partwk member'} invited you to Partwk Family Sharing`;
  }

  const htmlContent = getFamilyInvitationEmailHTML(ownerName, email, targetLang);

  // Send invitation email via real SMTP
  try {
    await sendEmail(email, subject, htmlContent);
  } catch (emailErr) {
    console.error("Family invitation email delivery failed, rolling back slot reservation:", emailErr);
    // Roll back slot reservation immediately so database state remains strictly consistent
    await db.runTransaction(async rollbackTx => {
      const familyRef = db.doc(`families/${ownerUid}`);
      const famSnap = await rollbackTx.get(familyRef);
      if (famSnap.exists && famSnap.data().invitation?.recipientEmail === email) {
        rollbackTx.update(familyRef, {
          invitation: FieldValue.delete(),
          updatedAt: ts(),
        });
      }
      if (recipient) {
        rollbackTx.delete(db.doc(`familyMemberships/${recipient.uid}`));
      }
    }).catch(rbErr => console.error("Rollback failed:", rbErr));

    throw new HttpsError('internal', 'Unable to send invitation email at this time. Please check your connection and try again.');
  }

  await writeAudit(ownerUid, 'family_invite_created', {
    recipientUid: recipient ? recipient.uid : null,
    recipientEmail: email,
    language: targetLang,
  });

  return { acceptedForDelivery: true, message: 'Invitation sent successfully. The recipient can accept it in Partwk.' };
});

exports.getFamilyStatus = onCall(async (request) => {
  const uid = requireUser(request);
  let callerEmail = '';
  try {
    const userRecord = await admin.auth().getUser(uid);
    callerEmail = (userRecord.email || '').toLowerCase().trim();
  } catch (_) {}

  let [membershipSnap, familySnap, entitlementSnap] = await Promise.all([
    db.doc(`familyMemberships/${uid}`).get(),
    db.doc(`families/${uid}`).get(),
    db.doc(`entitlements/${uid}`).get(),
  ]);

  // 1. Safe automatic reconciliation of unlinked pending invitations:
  // If the user has no active or pending membership doc, check if an unlinked invitation exists for their verified email.
  if (callerEmail && (!membershipSnap.exists || !['active', 'pending'].includes(membershipSnap.data()?.state))) {
    try {
      const pendingInvites = await db.collection('families')
        .where('invitation.recipientEmail', '==', callerEmail)
        .limit(1)
        .get();

      if (!pendingInvites.empty) {
        const familyDoc = pendingInvites.docs[0];
        const ownerUid = familyDoc.id;
        await db.runTransaction(async (t) => {
          const fam = await t.get(familyDoc.ref);
          if (fam.exists && fam.data().invitation?.recipientEmail === callerEmail && !fam.data().memberUid) {
            t.update(familyDoc.ref, {
              'invitation.recipientUid': uid,
              updatedAt: ts(),
            });
            t.set(db.doc(`familyMemberships/${uid}`), {
              ownerUid,
              memberUid: uid,
              state: 'pending',
              updatedAt: ts(),
            });
          }
        });
        membershipSnap = await db.doc(`familyMemberships/${uid}`).get();
      }
    } catch (e) {
      console.warn("Error reconciling pending family invitation by email:", e);
    }
  }

  // 2. Safe idempotent compatibility repair:
  // If this user is an active primary subscriber, but families/{uid} has no memberUid and no invitation,
  // check if legacy users/{uid}.familyMembers exists and references an existing user.
  if (activeEntitlement(entitlementSnap.exists ? entitlementSnap.data() : null) &&
      entitlementSnap.data()?.source !== 'family' &&
      familySnap.exists &&
      !familySnap.data()?.memberUid &&
      !familySnap.data()?.invitation) {
    try {
      const userDoc = await db.doc(`users/${uid}`).get();
      const legacyMembers = userDoc.data()?.familyMembers;
      if (Array.isArray(legacyMembers) && legacyMembers.length > 0) {
        const legacyEmail = String(legacyMembers[0]).toLowerCase().trim();
        if (legacyEmail) {
          const legacyMemberUser = await admin.auth().getUserByEmail(legacyEmail).catch(() => null);
          if (legacyMemberUser && legacyMemberUser.uid !== uid) {
            const legacyMemberDoc = await db.doc(`users/${legacyMemberUser.uid}`).get();
            const memberMem = await db.doc(`familyMemberships/${legacyMemberUser.uid}`).get();
            if (legacyMemberDoc.data()?.hasFamilyPremium || memberMem.data()?.ownerUid === uid) {
              const ownerEnt = entitlementSnap.data();
              const expiresAt = ownerEnt?.expiresAt || null;
              await db.runTransaction(async (t) => {
                t.set(db.doc(`families/${uid}`), {
                  ownerUid: uid,
                  memberUid: legacyMemberUser.uid,
                  memberEmail: legacyEmail,
                  migratedFromLegacy: true,
                  updatedAt: ts(),
                }, { merge: true });
                await projectMember(t, legacyMemberUser.uid, uid, expiresAt, 'active');
              });
              familySnap = await db.doc(`families/${uid}`).get();
            }
          }
        }
      }
    } catch (e) {
      console.warn("Legacy compatibility check error:", e);
    }
  }

  return {
    membership: membershipSnap.exists ? membershipSnap.data() : null,
    family: familySnap.exists ? familySnap.data() : null,
    entitlement: entitlementSnap.exists ? entitlementSnap.data() : null,
  };
});

exports.acceptFamilyInvitation = onCall(async (request) => {
  const memberUid = requireUser(request);
  let callerEmail = '';
  try {
    const userRec = await admin.auth().getUser(memberUid);
    callerEmail = (userRec.email || '').toLowerCase().trim();
  } catch (_) {}

  await db.runTransaction(async transaction => {
    const member = await transaction.get(db.doc(`familyMemberships/${memberUid}`));
    if (!member.exists || member.data().state !== 'pending') {
      throw new HttpsError('failed-precondition', 'No pending family invitation.');
    }
    const m = member.data();
    const [familySnap, ownerEnt, memberEnt] = await Promise.all([
      transaction.get(db.doc(`families/${m.ownerUid}`)),
      effectiveEntitlement(m.ownerUid, transaction),
      effectiveEntitlement(memberUid, transaction),
    ]);
    if (!familySnap.exists) {
      throw new HttpsError('failed-precondition', 'This invitation is no longer valid.');
    }
    const famData = familySnap.data();
    const isMatchingRecipient = famData.invitation?.recipientUid === memberUid ||
      (callerEmail && famData.invitation?.recipientEmail === callerEmail);

    if (!isMatchingRecipient || famData.memberUid) {
      throw new HttpsError('failed-precondition', 'This invitation is no longer valid.');
    }
    if (!activeEntitlement(ownerEnt.data)) {
      throw new HttpsError('failed-precondition', 'The primary subscription is no longer active.');
    }
    if (activeEntitlement(memberEnt.data) && memberEnt.data.source !== 'family') {
      throw new HttpsError('failed-precondition', 'Keep your independently paid subscription; it cannot be linked to a family plan.');
    }
    const expiresAt = ownerEnt.data.expiresAt || null;
    const recipientEmail = famData.invitation?.recipientEmail || callerEmail || null;

    transaction.set(db.doc(`families/${m.ownerUid}`), {
      memberUid,
      memberEmail: recipientEmail,
      invitation: FieldValue.delete(),
      activatedAt: ts(),
      updatedAt: ts(),
    }, { merge: true });

    await projectMember(transaction, memberUid, m.ownerUid, expiresAt, 'active');
    if (recipientEmail) {
      transaction.set(db.doc(`users/${m.ownerUid}`), { familyMembers: [recipientEmail] }, { merge: true });
    }
  });

  await writeAudit(memberUid, 'family_invitation_accepted', {});
  return { status: 'active' };
});

exports.cancelFamilyInvitation = onCall(async (request) => {
  const ownerUid = requireUser(request);
  await db.runTransaction(async transaction => {
    const familyRef = db.doc(`families/${ownerUid}`);
    const family = await transaction.get(familyRef);
    if (!family.exists || !family.data().invitation) {
      throw new HttpsError('failed-precondition', 'No pending invitation.');
    }
    const recipientUid = family.data().invitation.recipientUid;
    transaction.update(familyRef, { invitation: FieldValue.delete(), updatedAt: ts() });
    if (recipientUid) {
      transaction.delete(db.doc(`familyMemberships/${recipientUid}`));
    }
  });
  await writeAudit(ownerUid, 'family_invitation_cancelled', {});
  return { status: 'cancelled' };
});

async function endFamily(ownerUid, actorUid, action, override = false, auditDetails = {}) {
  let memberUid = null;
  await db.runTransaction(async transaction => {
    const familyRef = db.doc(`families/${ownerUid}`);
    const family = await transaction.get(familyRef);
    if (!family.exists || !family.data().memberUid) {
      throw new HttpsError('failed-precondition', 'No active family member.');
    }
    memberUid = family.data().memberUid;
    if (!override && actorUid !== ownerUid && actorUid !== memberUid) {
      throw new HttpsError('permission-denied', 'Not a participant.');
    }
    transaction.set(familyRef, {
      memberUid: FieldValue.delete(),
      memberEmail: FieldValue.delete(),
      updatedAt: ts(),
    }, { merge: true });
    await projectMember(transaction, memberUid, ownerUid, null, 'removed');
    transaction.set(db.doc(`users/${ownerUid}`), { familyMembers: [] }, { merge: true });
  });
  await writeAudit(actorUid, action, { ownerUid, memberUid, override, ...auditDetails });
  return { status: 'removed' };
}
exports.removeFamilyMember = onCall(async request => endFamily(requireUser(request), requireUser(request), 'family_member_removed'));
exports.leaveFamily = onCall(async request => {
  const uid = requireUser(request);
  const m = await db.doc(`familyMemberships/${uid}`).get();
  if (!m.exists || m.data().state !== 'active') throw new HttpsError('failed-precondition', 'No active family.');
  return endFamily(m.data().ownerUid, uid, 'family_member_left');
});
exports.adminOverrideFamilyRemoval = onCall(async request => {
  const actorUid = requireUser(request);
  if (!isAdminToken(request)) throw new HttpsError('permission-denied', 'Administrator required.');
  const ownerUid = String(request.data?.ownerUid || '');
  const reason = String(request.data?.reason || '').trim();
  if (!ownerUid || !reason) throw new HttpsError('invalid-argument', 'Owner and reason are required.');
  return endFamily(ownerUid, actorUid, 'family_admin_override_removal', true, { reason });
});

// Store verification is fail-closed until App Store Server API / Google Play
// Developer API credentials and product identifiers are configured. A client
// receipt is never itself an entitlement. The verified webhook/reconciler must
// call this internal writer with normalized store state.
exports.verifyStorePurchase = onCall(async request => {
  const uid = requireUser(request);
  const productId = String(request.data?.productId || '');
  const receipt = String(request.data?.serverVerificationData || '');
  if (!productId || !receipt) throw new HttpsError('invalid-argument', 'Missing store purchase data.');
  if (!process.env.APPLE_SERVER_API_KEY || !process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON) {
    throw new HttpsError('failed-precondition', 'Purchases are not configured for verification in this environment.');
  }
  // Deliberately fail closed rather than treating an unverified client receipt
  // as payment. Production must wire platform-specific verification here.
  throw new HttpsError('unimplemented', 'Store verification provider setup is incomplete. No access was granted.');
});

exports.applyVerifiedEntitlementForTest = onCall(async request => {
  const actorUid = requireUser(request);
  if (!isAdminToken(request) || process.env.FUNCTIONS_EMULATOR !== 'true') throw new HttpsError('permission-denied', 'Emulator-only test helper.');
  const { uid, status, expiresAt } = request.data || {};
  if (!uid || !['active', 'expired', 'revoked'].includes(status)) throw new HttpsError('invalid-argument', 'Invalid lifecycle state.');
  await db.doc(`entitlements/${uid}`).set({ status: status === 'active' ? 'active' : 'inactive', source: 'verified_store_test', expiresAt: expiresAt ? Timestamp.fromDate(new Date(expiresAt)) : null, updatedAt: ts() }, { merge: true });
  await writeAudit(actorUid, 'test_entitlement_applied', { uid, status });
  return { ok: true };
});

// Trusted account deletion callable
// Deletes only the requesting authenticated user's data and Firebase Auth account.
// Safely unlinks family relationships, revokes linked member if caller is primary,
// recursively cleans up private subcollections, notes, highlights, and audit logs the action.
exports.deleteAccount = onCall(async (request) => {
  const uid = requireUser(request);

  // 1. Family clean up
  // Case A: User is a family primary (has families/{uid})
  try {
    const familySnap = await db.doc(`families/${uid}`).get();
    if (familySnap.exists) {
      const familyData = familySnap.data() || {};
      if (familyData.memberUid) {
        const memberUid = familyData.memberUid;
        await db.runTransaction(async (t) => {
          t.set(db.doc(`familyMemberships/${memberUid}`), {
            ownerUid: uid,
            memberUid,
            state: 'removed',
            expiresAt: null,
            updatedAt: ts(),
          });
          t.set(db.doc(`entitlements/${memberUid}`), {
            status: 'inactive',
            source: 'none',
            ownerUid: null,
            expiresAt: null,
            updatedAt: ts(),
          }, { merge: true });
        });
        await writeAudit(uid, 'family_primary_deleted_account_revoked_member', { memberUid });
      }
      if (familyData.invitation?.recipientUid) {
        await db.doc(`familyMemberships/${familyData.invitation.recipientUid}`).delete().catch(() => {});
      }
      await db.doc(`families/${uid}`).delete().catch(() => {});
    }
  } catch (err) {
    console.error(`Error resolving primary family on deletion for ${uid}:`, err);
  }

  // Case B: User is a linked family member (has familyMemberships/{uid})
  try {
    const memberSnap = await db.doc(`familyMemberships/${uid}`).get();
    if (memberSnap.exists) {
      const memberData = memberSnap.data() || {};
      const ownerUid = memberData.ownerUid;
      if (ownerUid) {
        const ownerFamilyRef = db.doc(`families/${ownerUid}`);
        const ownerFamilySnap = await ownerFamilyRef.get();
        if (ownerFamilySnap.exists) {
          const oData = ownerFamilySnap.data() || {};
          if (oData.memberUid === uid) {
            await ownerFamilyRef.set({
              memberUid: FieldValue.delete(),
              memberEmail: FieldValue.delete(),
              updatedAt: ts(),
            }, { merge: true }).catch(() => {});
          } else if (oData.invitation?.recipientUid === uid) {
            await ownerFamilyRef.set({
              invitation: FieldValue.delete(),
              updatedAt: ts(),
            }, { merge: true }).catch(() => {});
          }
        }
      }
      await db.doc(`familyMemberships/${uid}`).delete().catch(() => {});
      await writeAudit(uid, 'family_member_deleted_account', { ownerUid });
    }
  } catch (err) {
    console.error(`Error resolving family membership on deletion for ${uid}:`, err);
  }

  // 2. Inactivate/delete caller's entitlement
  try {
    await db.doc(`entitlements/${uid}`).delete().catch(() => {});
  } catch (err) {
    console.error(`Error deleting entitlement for ${uid}:`, err);
  }

  // 3. Delete user's notes and highlights in root collections (if any)
  try {
    const notesQuery = await db.collection('notes').where('userId', '==', uid).get();
    const batch = db.batch();
    notesQuery.forEach(doc => batch.delete(doc.ref));
    const highlightsQuery = await db.collection('highlights').where('userId', '==', uid).get();
    highlightsQuery.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
  } catch (err) {
    console.warn(`Error deleting user notes/highlights for ${uid}:`, err);
  }

  // 3b. Delete user-owned Firebase Storage files (e.g. avatars, custom uploads under users/{uid}/)
  // Strict scope: ONLY files prefixed with users/{uid}/. Books, audio, covers, and other users are untouched.
  try {
    const bucket = admin.storage().bucket();
    await bucket.deleteFiles({ prefix: `users/${uid}/` });
  } catch (err) {
    console.warn(`Storage cleanup for users/${uid}/ skipped or non-fatal:`, err.message || err);
  }

  // 4. Safely and recursively delete the user profile document and any subcollections
  try {
    await db.recursiveDelete(db.doc(`users/${uid}`));
  } catch (err) {
    console.warn(`Fallback single doc delete on users/${uid}:`, err);
    await db.doc(`users/${uid}`).delete().catch(() => {});
  }

  // 5. Write audit record
  try {
    await writeAudit(uid, 'user_account_deleted', { uid });
  } catch (_) {}

  // 6. Delete Firebase Auth user record
  try {
    await admin.auth().deleteUser(uid);
  } catch (err) {
    if (err.code !== 'auth/user-not-found') {
      console.warn(`Error deleting auth user ${uid}:`, err);
    }
  }

  return { success: true, message: 'Account permanently deleted.' };
});


