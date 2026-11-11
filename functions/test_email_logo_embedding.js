/*
 * Static contract test for transactional email branding.
 * It deliberately does not initialise Firebase or send email.
 */
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const sourcePath = path.join(__dirname, 'index.js');
const canonicalPath = path.join(root, 'assets', 'images', 'partwk_canonical_logo.png');
const packagedPath = path.join(__dirname, 'assets', 'partwk_canonical_logo.png');
const source = fs.readFileSync(sourcePath, 'utf8');
const sha256 = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');

assert.equal(sha256(packagedPath), sha256(canonicalPath), 'Functions logo must be byte-identical to canonical logo');

assert.match(source, /const EMAIL_LOGO_CID = 'partwk-canonical-logo';/);
assert.match(source, /path\.join\(__dirname, 'assets', 'partwk_canonical_logo\.png'\)/);
assert.match(source, /attachments:\s*\[\s*\{[\s\S]*filename:\s*'partwk-logo\.png',[\s\S]*path:\s*EMAIL_LOGO_PATH,[\s\S]*cid:\s*EMAIL_LOGO_CID,[\s\S]*contentType:\s*'image\/png'/);
assert.match(source, /<img src="cid:partwk-canonical-logo" alt="Partwk"/);

const logoDefinition = source.match(/const logoImg = `([\s\S]*?)`;/)?.[1] || '';

for (const template of [
  'getWelcomeFreeEmailHTML',
  'getPremiumUpgradeEmailHTML',
  'getRenewalReminderEmailHTML',
  'getFamilyInvitationEmailHTML',
  'getPasswordResetEmailHTML',
]) {
  const start = source.indexOf(`const ${template}`);
  assert.notEqual(start, -1, `${template} must exist`);
  const next = source.indexOf('\nconst ', start + 1);
  const body = source.slice(start, next === -1 ? source.length : next);
  assert.match(body, /\$\{logoImg\}/, `${template} must include the shared CID logo`);
}

for (const forbidden of [
  'partwk-web.web.app',
  'partwk-bd4ec.web.app',
  'https://partwk.com',
  'https://www.partwk.com',
]) {
  assert.equal(logoDefinition.includes(forbidden), false, `Email logo HTML must not contain remote URL: ${forbidden}`);
}

console.log('PASS: canonical and packaged logo SHA-256:', sha256(canonicalPath));
console.log('PASS: 5 email template families use the shared CID logo attachment.');
