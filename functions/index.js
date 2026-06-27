const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// ============================================================================
// SMTP CONFIGURATION (NAMECHEAP PRIVATE EMAIL)
// ============================================================================
const transporter = nodemailer.createTransport({
  host: "mail.privateemail.com", 
  port: 465,
  secure: true, // true for 465
  auth: {
    user: "info@partwk.com", 
    pass: "London2026@", 
  },
});

// Helper function to send emails
async function sendEmail(to, subject, html) {
  try {
    const info = await transporter.sendMail({
      from: '"Partwk Team" <info@partwk.com>',
      to: to,
      subject: subject,
      html: html,
    });
    console.log("Message sent: %s", info.messageId);
  } catch (error) {
    console.error("Error sending email:", error);
  }
}

// ============================================================================
// EMAIL TEMPLATES
// ============================================================================

const logoImg = `<div style="text-align: center; margin-bottom: 20px;"><img src="https://partwk-bd4ec.web.app/email_logo.png" alt="Partwk Logo" style="height: 60px;" /></div>`;

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

// ============================================================================
// CLOUD FUNCTIONS
// ============================================================================

// Trigger: When a new user registers (document created in 'users' collection)
exports.onUserCreated = onDocumentCreated('users/{userId}', async (event) => {
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
exports.onUserUpdated = onDocumentUpdated('users/{userId}', async (event) => {
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
        sentExpiryReminder3Days: admin.firestore.FieldValue.delete()
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

exports.sendCustomPasswordReset = onCall(async (request) => {
    const email = request.data.email;
    if (!email) {
        throw new HttpsError('invalid-argument', 'The function must be called with an "email" argument.');
    }

    try {
        const link = await admin.auth().generatePasswordResetLink(email);
        const htmlContent = getPasswordResetEmailHTML(link);
        await sendEmail(email, "Reset Your Partwk Password", htmlContent);
        
        return { success: true, message: "Custom password reset email sent successfully." };
    } catch (error) {
        console.error("Error sending custom password reset:", error);
        throw new HttpsError('internal', 'Unable to send password reset email.', error.message);
    }
});

// Scheduled job running daily to check premium expirations and send reminders
exports.checkPremiumExpirations = onSchedule('every day 00:00', async (event) => {
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
