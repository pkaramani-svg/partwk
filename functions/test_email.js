const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: "mail.privateemail.com", 
  port: 465,
  secure: true, 
  auth: {
    user: "info@partwk.com", 
    pass: "London2026@", 
  },
});

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

async function test() {
  console.log("Sending Free Welcome Email...");
  try {
    await transporter.sendMail({
      from: '"Partwk Team" <info@partwk.com>',
      to: "pkaramani@gmail.com",
      subject: "Welcome to Partwk! (Free Plan)",
      html: getWelcomeFreeEmailHTML("Peshraw"),
    });
    console.log("Free Welcome sent.");

    console.log("Sending Premium Welcome Email...");
    await transporter.sendMail({
      from: '"Partwk Team" <info@partwk.com>',
      to: "pkaramani@gmail.com",
      subject: "Welcome to Partwk Premium! 👑",
      html: getPremiumUpgradeEmailHTML("Peshraw", "annual", new Date().toLocaleDateString(), new Date(new Date().setFullYear(new Date().getFullYear() + 1)).toLocaleDateString()),
    });
    console.log("Premium Welcome sent.");

  } catch (error) {
    console.error("Failed to send:", error.message);
  }
}
test();
