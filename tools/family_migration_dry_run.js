// Read-only migration assessor. Run with an Admin SDK pointed at an emulator or
// explicitly configured export; it never writes and never auto-accepts links.
// Functions owns the Admin SDK dependency; resolve it explicitly so this tool
// can run from the repository root without an unrelated root node_modules.
const admin = require('../functions/node_modules/firebase-admin');
const projectId = process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID;
if (!projectId) throw new Error('Set GCLOUD_PROJECT (or FIREBASE_PROJECT_ID) to the explicit emulator/export project.');
admin.initializeApp({ projectId });
(async () => {
  const users = await admin.firestore().collection('users').get();
  const byEmail = new Map(users.docs.map(d => [String(d.data().email || '').trim().toLowerCase(), {uid: d.id, ...d.data()}]));
  const rows = [];
  for (const ownerDoc of users.docs) {
    const owner = ownerDoc.data();
    for (const raw of owner.familyMembers || []) {
      const email = String(raw).trim().toLowerCase(); const member = byEmail.get(email);
      const flags = [];
      if (!email || email === String(owner.email || '').toLowerCase()) flags.push('self_or_invalid_link');
      if (!member) flags.push('missing_account');
      if (member && ['premium', 'pro'].includes(member.subscriptionStatus)) flags.push('independently_paid_member');
      if (!['premium', 'pro'].includes(owner.subscriptionStatus)) flags.push('unverified_or_expired_primary');
      rows.push({ownerUid: ownerDoc.id, memberEmail: email, memberUid: member?.uid || null, flags, action: 'manual_review_only'});
    }
  }
  const counts = new Map(); for (const r of rows) if (r.memberUid) counts.set(r.memberUid, (counts.get(r.memberUid) || 0) + 1);
  for (const r of rows) if (r.memberUid && counts.get(r.memberUid) > 1) r.flags.push('multiple_owners');
  console.log(JSON.stringify({dryRun: true, records: rows}, null, 2));
})().catch(e => { console.error(e); process.exit(1); });
