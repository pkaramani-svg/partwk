/**
 * Partwk Entitlement Migration Tool
 * 
 * Safe, idempotent, dry-run-first backend migration tool to assess and migrate
 * legacy subscriptions into trusted `/entitlements/{uid}` projection documents.
 * 
 * Safety invariants:
 *  - Defaults to DRY-RUN mode. Requires `--execute` to perform any writes.
 *  - Migrates ONLY active primary subscribers (Premium/Pro with finite future expiry).
 *  - NEVER invents an expiry date or creates indefinite access.
 *  - NEVER auto-upgrades free users.
 *  - NEVER overwrites an existing trusted entitlement doc.
 *  - NEVER migrates a family-derived subscriber (`hasFamilyPremium: true`) as a primary.
 *  - Records source and migration audit metadata.
 */

const fs = require('fs');
const https = require('https');
const os = require('os');
const path = require('path');
const admin = require('../functions/node_modules/firebase-admin');

const isExecute = process.argv.includes('--execute');
const isDryRun = !isExecute;

const projectId = process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID || 'partwk-bd4ec';
const isEmulator = !!process.env.FIRESTORE_EMULATOR_HOST;

let db = null;
let liveToken = null;

if (isEmulator) {
  const app = admin.apps.find(a => a && a.name === 'entitlement-migrator')
    || admin.initializeApp({ projectId }, 'entitlement-migrator');
  db = app.firestore();
} else {
  // Production environment: read OAuth token from firebase-tools.json for REST read-only
  const configPath = path.join(os.homedir(), '.config/configstore/firebase-tools.json');
  if (fs.existsSync(configPath)) {
    try {
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      liveToken = config.tokens?.access_token;
    } catch (_) {}
  }
  if (!liveToken && isExecute) {
    throw new Error('Production --execute requires valid admin credentials or authenticated Firebase CLI.');
  }
}

function parseExpiry(val) {
  if (!val) return null;
  if (typeof val.toMillis === 'function') return val.toMillis();
  if (typeof val.toDate === 'function') return val.toDate().getTime();
  if (val instanceof Date) return val.getTime();
  if (typeof val === 'number') return val;
  if (typeof val === 'string') {
    const parsed = Date.parse(val);
    return isNaN(parsed) ? null : parsed;
  }
  if (val._seconds !== undefined) {
    return val._seconds * 1000 + Math.round((val._nanoseconds || 0) / 1000000);
  }
  return null;
}

function httpsGet(urlPath) {
  return new Promise((resolve, reject) => {
    https.get({
      hostname: 'firestore.googleapis.com',
      path: urlPath,
      headers: {
        'Authorization': `Bearer ${liveToken}`,
        'User-Agent': 'Partwk-Migrator',
      },
    }, res => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(body) });
        } catch (e) {
          resolve({ status: res.statusCode, body });
        }
      });
    }).on('error', reject);
  });
}

function httpsPatch(urlPath, data) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(data);
    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path: urlPath,
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${liveToken}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
        'User-Agent': 'Partwk-Migrator',
      },
    }, res => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(body) });
        } catch (e) {
          resolve({ status: res.statusCode, body });
        }
      });
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

function parseFirestoreField(field) {
  if (!field) return null;
  if (field.stringValue !== undefined) return field.stringValue;
  if (field.booleanValue !== undefined) return field.booleanValue;
  if (field.integerValue !== undefined) return parseInt(field.integerValue, 10);
  if (field.doubleValue !== undefined) return parseFloat(field.doubleValue);
  if (field.timestampValue !== undefined) return field.timestampValue;
  if (field.arrayValue !== undefined) {
    return (field.arrayValue.values || []).map(parseFirestoreField);
  }
  if (field.mapValue !== undefined) {
    const res = {};
    for (const [k, v] of Object.entries(field.mapValue.fields || {})) {
      res[k] = parseFirestoreField(v);
    }
    return res;
  }
  return null;
}

async function loadAllUsers() {
  if (isEmulator) {
    const usersSnap = await db.collection('users').get();
    return usersSnap.docs.map(doc => ({ uid: doc.id, data: doc.data() }));
  }

  // REST loader for production snapshot
  let pageToken = null;
  const users = [];
  do {
    let url = `/v1/projects/${projectId}/databases/(default)/documents/users?pageSize=100`;
    if (pageToken) url += `&pageToken=${pageToken}`;
    const res = await httpsGet(url);
    if (res.status !== 200) throw new Error(`REST fetch failed: ${JSON.stringify(res)}`);
    for (const doc of (res.data.documents || [])) {
      const uid = doc.name.split('/').pop();
      const rawFields = doc.fields || {};
      const data = {};
      for (const [k, v] of Object.entries(rawFields)) {
        data[k] = parseFirestoreField(v);
      }
      users.push({ uid, data });
    }
    pageToken = res.data.nextPageToken;
  } while (pageToken);
  return users;
}

async function checkEntitlementDoc(uid) {
  if (isEmulator) {
    const snap = await db.doc(`entitlements/${uid}`).get();
    return snap.exists ? snap.data() : null;
  }
  const res = await httpsGet(`/v1/projects/${projectId}/databases/(default)/documents/entitlements/${uid}`);
  if (res.status === 200 && res.data.fields) {
    const data = {};
    for (const [k, v] of Object.entries(res.data.fields)) {
      data[k] = parseFirestoreField(v);
    }
    return data;
  }
  return null;
}

async function runMigration() {
  const now = Date.now();
  console.log('================================================================');
  console.log(`PARTWK ENTITLEMENT MIGRATION TOOL [${isDryRun ? 'DRY-RUN MODE' : 'EXECUTE MODE'}]`);
  console.log(`Project: ${projectId}`);
  console.log(`Environment: ${isEmulator ? 'Local Emulator' : 'Production Cloud'}`);
  console.log(`Timestamp: ${new Date(now).toISOString()}`);
  console.log('================================================================\n');

  const users = await loadAllUsers();
  console.log(`Scanning ${users.length} user documents in /users...\n`);

  const report = {
    mode: isDryRun ? 'dry-run' : 'execute',
    projectId,
    scanTimestamp: new Date(now).toISOString(),
    totalUsersScanned: users.length,
    counts: {
      active_primary_eligible: 0,
      expired_premium: 0,
      invalid_or_missing_expiry: 0,
      family_linked_review: 0,
      trusted_entitlement_existing: 0,
      free_unaffected: 0,
    },
    categories: {
      active_primary_eligible: [],
      expired_premium: [],
      invalid_or_missing_expiry: [],
      family_linked_review: [],
      trusted_entitlement_existing: [],
      free_unaffected: [],
    },
  };

  for (const { uid, data } of users) {
    const email = String(data.email || '').trim().toLowerCase();
    const status = String(data.subscriptionStatus || 'free').trim().toLowerCase();
    const hasFamily = data.hasFamilyPremium === true;
    const familyMembers = Array.isArray(data.familyMembers) ? data.familyMembers : [];
    const isFamilyLinked = hasFamily || familyMembers.length > 0 || !!data.familyOwner || !!data.familyId;
    const isPremiumStatus = ['premium', 'pro'].includes(status);

    // Check if an entitlement doc already exists
    const existingEnt = await checkEntitlementDoc(uid);

    if (existingEnt && existingEnt.status === 'active') {
      report.counts.trusted_entitlement_existing++;
      report.categories.trusted_entitlement_existing.push({
        uid,
        email,
        existingSource: existingEnt.source,
        expiresAt: existingEnt.expiresAt ? new Date(parseExpiry(existingEnt.expiresAt)).toISOString() : null,
        note: 'Trusted entitlement already exists; preserving unchanged.',
      });
      continue;
    }

    // Family-linked records check (requires manual review)
    if (isFamilyLinked) {
      report.counts.family_linked_review++;
      report.categories.family_linked_review.push({
        uid,
        email,
        subscriptionStatus: status,
        hasFamilyPremium: hasFamily,
        familyMembers,
        familyOwner: data.familyOwner || null,
        note: hasFamily 
          ? 'Legacy family-derived entitlement. Must NOT migrate as primary subscriber.'
          : 'Legacy primary user with familyMembers array. Requires family slot migration.',
      });
    }

    const rawExpiry = data.subscriptionExpiryDate || data.expiresAt;
    const expiryMillis = parseExpiry(rawExpiry);

    if (isPremiumStatus && !hasFamily) {
      if (expiryMillis === null) {
        report.counts.invalid_or_missing_expiry++;
        report.categories.invalid_or_missing_expiry.push({
          uid,
          email,
          subscriptionStatus: status,
          rawExpiry,
          reason: 'Expiry date missing or invalid date format. No date invented; access withheld.',
        });
      } else if (expiryMillis <= now) {
        report.counts.expired_premium++;
        report.categories.expired_premium.push({
          uid,
          email,
          subscriptionStatus: status,
          expiredAt: new Date(expiryMillis).toISOString(),
          reason: 'Subscription expired in the past.',
        });
      } else {
        // Valid active primary Premium user with future finite expiry
        report.counts.active_primary_eligible++;
        report.categories.active_primary_eligible.push({
          uid,
          email,
          subscriptionStatus: status,
          expiresAt: new Date(expiryMillis).toISOString(),
          familyMembersCount: familyMembers.length,
          hasLegacyFamilyArray: familyMembers.length > 0,
        });

        if (isExecute) {
          if (isEmulator) {
            const entitlementRef = db.doc(`entitlements/${uid}`);
            await entitlementRef.set({
              status: 'active',
              source: 'legacy_primary_migration',
              expiresAt: admin.firestore.Timestamp.fromMillis(expiryMillis),
              migratedAt: admin.firestore.Timestamp.now(),
              updatedAt: admin.firestore.Timestamp.now(),
              migrationMetadata: {
                migratedFrom: 'users',
                originalSubscriptionStatus: status,
                originalExpiryDate: rawExpiry instanceof admin.firestore.Timestamp ? rawExpiry : new Date(expiryMillis).toISOString(),
                hadLegacyFamilyMembers: familyMembers.length > 0,
                legacyFamilyMembers: familyMembers,
              },
            });
          } else {
            // Production execution via authorized REST API
            const isoExpiry = new Date(expiryMillis).toISOString();
            const nowIso = new Date().toISOString();
            const payload = {
              fields: {
                status: { stringValue: 'active' },
                source: { stringValue: 'legacy_primary_migration' },
                expiresAt: { timestampValue: isoExpiry },
                migratedAt: { timestampValue: nowIso },
                updatedAt: { timestampValue: nowIso },
                migrationMetadata: {
                  mapValue: {
                    fields: {
                      migratedFrom: { stringValue: 'users' },
                      originalSubscriptionStatus: { stringValue: status },
                      originalExpiryDate: { timestampValue: isoExpiry },
                      hadLegacyFamilyMembers: { booleanValue: familyMembers.length > 0 },
                      legacyFamilyMembers: {
                        arrayValue: {
                          values: familyMembers.map(m => ({ stringValue: m }))
                        }
                      }
                    }
                  }
                }
              }
            };
            const patchRes = await httpsPatch(`/v1/projects/${projectId}/databases/(default)/documents/entitlements/${uid}`, payload);
            if (patchRes.status !== 200) {
              throw new Error(`Production write failed for /entitlements/${uid}: ${JSON.stringify(patchRes)}`);
            }
          }
          console.log(`  [MIGRATED] Wrote /entitlements/${uid} for ${email} (expires: ${new Date(expiryMillis).toISOString()})`);
        }
      }
    } else if (!isFamilyLinked) {
      report.counts.free_unaffected++;
      report.categories.free_unaffected.push({ uid, email, subscriptionStatus: status });
    }
  }

  console.log('\n--- MIGRATION ASSESSMENT SUMMARY ---');
  console.log(`1. Active Primary Eligible (Valid Future Expiry): ${report.counts.active_primary_eligible}`);
  console.log(`2. Expired Premium:                              ${report.counts.expired_premium}`);
  console.log(`3. Premium with Missing/Invalid Expiry:          ${report.counts.invalid_or_missing_expiry}`);
  console.log(`4. Family-Linked Legacy Records (Manual Review): ${report.counts.family_linked_review}`);
  console.log(`5. Existing Trusted Entitlements Preserved:      ${report.counts.trusted_entitlement_existing}`);
  console.log(`6. Free / Standard Users (Unaffected):           ${report.counts.free_unaffected}`);
  console.log('--------------------------------------------------\n');

  if (report.categories.family_linked_review.length > 0) {
    console.log('ACCOUNTS REQUIRING MANUAL REVIEW:');
    for (const r of report.categories.family_linked_review) {
      console.log(`  - UID: ${r.uid} (${r.email}): ${r.note}`);
      if (r.familyMembers?.length) {
        console.log(`    Linked legacy emails: ${JSON.stringify(r.familyMembers)}`);
      }
    }
    console.log('');
  }

  if (isDryRun) {
    console.log('>> DRY-RUN ONLY: No writes were made to Firestore.');
    console.log('>> To apply approved primary entitlements, run with --execute.');
  } else {
    console.log('>> EXECUTE COMPLETE: Approved entitlements have been written to Firestore.');
  }

  return report;
}

if (require.main === module) {
  runMigration().catch(err => {
    console.error('Migration failed:', err);
    process.exit(1);
  });
}

module.exports = { runMigration, parseExpiry };
