// Local emulator-only migration. Dry run by default; --apply is intentionally
// rejected unless an explicit loopback Firestore emulator is configured.
const admin = require('../functions/node_modules/firebase-admin');
const projectId = process.env.GCLOUD_PROJECT;
const emulator = process.env.FIRESTORE_EMULATOR_HOST || '';
if (!projectId || !/^demo-[a-z0-9-]+$/.test(projectId) || !/^(127\.0\.0\.1|localhost):\d+$/.test(emulator)) {
  throw new Error('Requires an explicit demo-* project and loopback FIRESTORE_EMULATOR_HOST.');
}
admin.initializeApp({ projectId });
const db = admin.firestore();
const apply = process.argv.includes('--apply');
(async () => {
  const books = await db.collection('books').get();
  const rows = [];
  for (const doc of books.docs) {
    const data = doc.data();
    const isPremium = data.isPremium === true;
    const hiddenLanguages = Array.isArray(data.hiddenLanguages) ? data.hiddenLanguages : [];
    if (!isPremium && !hiddenLanguages.length) continue;
    if (data.contentProtectionVersion === 3) {
      rows.push({ bookId: doc.id, status: 'already_migrated' });
      continue;
    }
    const languages = {}; const sanitized = {}; const study = {}; const hiddenContent = {};
    for (const [lang, chapters] of Object.entries(data.chapterSummaries || {})) {
      if (!Array.isArray(chapters)) throw new Error(`Invalid chapters in ${doc.id}`);
      if (hiddenLanguages.includes(lang)) { hiddenContent[lang] = { chapterSummaries: chapters }; continue; }
      if (!isPremium) { sanitized[lang] = chapters; continue; }
      languages[lang] = chapters.map(chapter => ({ content: chapter.content ?? '', segmentTexts: Array.isArray(chapter.segments) ? chapter.segments.map(segment => segment.text ?? '') : [] }));
      sanitized[lang] = chapters.map(chapter => {
        const copy = { ...chapter }; delete copy.content;
        if (Array.isArray(copy.segments)) copy.segments = copy.segments.map(segment => { const safe = { ...segment }; delete safe.text; return safe; });
        return copy;
      });
    }
    for (const field of ['fiveMinuteSummary', 'fifteenMinuteSummary', 'keyIdeas', 'keyQuotes', 'actionPoints']) {
      const localized = data[field];
      if (localized && typeof localized === 'object' && !Array.isArray(localized)) {
        for (const [lang, value] of Object.entries(localized)) {
          if (hiddenLanguages.includes(lang)) {
            hiddenContent[lang] ||= {};
            hiddenContent[lang][field] = value;
          } else if (isPremium) {
            study[lang] ||= {};
            study[lang][field] = value;
          }
        }
      }
    }
    rows.push({ bookId: doc.id, languages: Object.keys(languages) });
    if (apply) {
      await db.runTransaction(async transaction => {
        const current = await transaction.get(doc.ref);
        if (!current.exists || !current.updateTime.isEqual(doc.updateTime)) throw new Error(`Book changed during migration: ${doc.id}`);
        const privateRef = db.doc(`premiumBookText/${doc.id}`);
        const hiddenRef = db.doc(`unpublishedBookLanguages/${doc.id}`);
        const [existingPrivate, existingHidden] = await Promise.all([transaction.get(privateRef), transaction.get(hiddenRef)]);
        if (existingPrivate.exists && ![1,2].includes(data.premiumTextVersion)) throw new Error(`Private text already exists: ${doc.id}`);
        const previous = existingPrivate.exists ? existingPrivate.data() : {};
        if (isPremium) transaction.set(privateRef, { languages: [1,2].includes(data.premiumTextVersion) ? previous.languages : languages,
          study: { ...(previous.study || {}), ...study } });
        if (Object.keys(hiddenContent).length) transaction.set(hiddenRef, { languages: { ...(existingHidden.exists ? existingHidden.data().languages : {}), ...hiddenContent } });
        const update = { chapterSummaries: sanitized, contentProtectionVersion: 3 };
        if (isPremium) update.premiumTextVersion = 2;
        for (const field of ['fiveMinuteSummary', 'fifteenMinuteSummary', 'keyIdeas', 'keyQuotes', 'actionPoints']) {
          const values = {...(data[field] || {})};
          if (isPremium) { for (const lang of Object.keys(values)) delete values[lang]; }
          else for (const lang of hiddenLanguages) delete values[lang];
          update[field] = values;
        }
        transaction.update(doc.ref, update);
      });
    }
  }
  console.log(JSON.stringify({ dryRun: !apply, records: rows }, null, 2));
  await admin.app().delete();
})().catch(error => { console.error(error); process.exitCode = 1; });
