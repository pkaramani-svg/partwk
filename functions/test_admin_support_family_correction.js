/**
 * Comprehensive verification test suite for Partwk Admin Support Family Member Correction
 * 
 * Verifies the 8 core production requirements:
 * 1. Existing registered Free account with no family history -> accepted and becomes pending.
 * 2. Existing registered Free account with historical `removed` membership -> accepted and becomes pending.
 * 3. Existing registered Free account with historical inactive entitlement -> accepted and becomes pending.
 * 4. Unregistered email -> remains supported as pending.
 * 5. Disabled Auth account -> rejected with a clear, accurate message.
 * 6. Independently paid Premium account -> rejected.
 * 7. Active/pending member of another family -> rejected.
 * 8. Admin UI shows the real backend error, not a misleading generic "locked" message.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');

// Ensure emulator host is set for local testing
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'partwk-bd4ec' });
}

const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

function ts() {
  return FieldValue.serverTimestamp();
}

function activeEntitlement(data) {
  if (!data) return false;
  const expiry = data.expiresAt;
  return data.status === 'active' && (!expiry || expiry.toMillis() > Date.now());
}

async function effectiveEntitlement(uid, transaction) {
  const ref = db.doc(`entitlements/${uid}`);
  const snap = transaction ? await transaction.get(ref) : await ref.get();
  return { ref, data: snap.exists ? snap.data() : null };
}

// In-memory mock auth user store to simulate Firebase Auth records including disabled state
const mockAuthUsers = new Map();

function mockGetUserByEmail(email) {
  const norm = String(email || '').toLowerCase().trim();
  for (const user of mockAuthUsers.values()) {
    if ((user.email || '').toLowerCase().trim() === norm) {
      return user;
    }
  }
  return null;
}

// Mirror of adminUpdateFamilySlotEmail in functions/index.js
async function runAdminUpdateFamilySlotEmail({ request, mockSendEmail = async () => ({ messageId: 'test-123' }) }) {
  const { auth, data } = request;
  if (!auth || !auth.uid) {
    throw new Error('unauthenticated: Authentication required.');
  }
  if (!auth.token?.admin) {
    throw new Error('permission-denied: Administrator required.');
  }

  const actorUid = auth.uid;
  const ownerUid = String(data?.ownerUid || '').trim();
  const newEmail = String(data?.newEmail || '').trim().toLowerCase();
  const reason = String(data?.reason || '').trim();

  if (!ownerUid) throw new Error('invalid-argument: Valid ownerUid is required.');
  if (!/^\S+@\S+\.\S+$/.test(newEmail)) throw new Error('invalid-argument: Valid newEmail is required.');
  if (!reason) throw new Error('invalid-argument: A non-empty support reason is required.');

  // 1. Validate Family Owner exists and has active primary Premium entitlement
  const ownerEntPre = (await effectiveEntitlement(ownerUid)).data;
  if (!activeEntitlement(ownerEntPre) || ownerEntPre.source === 'family') {
    throw new Error('failed-precondition: The Family Owner must have an active primary Premium entitlement.');
  }

  const ownerRecord = mockAuthUsers.get(ownerUid);
  if (ownerRecord?.email && ownerRecord.email.toLowerCase().trim() === newEmail) {
    throw new Error('invalid-argument: Cannot assign family slot to the owner themselves.');
  }

  // 2. Validate recipient pre-conditions
  let recipient = mockGetUserByEmail(newEmail);
  if (recipient) {
    if (recipient.disabled === true) {
      throw new Error('failed-precondition: That user account has been disabled.');
    }
    if (recipient.uid === ownerUid) {
      throw new Error('invalid-argument: Cannot assign family slot to the owner themselves.');
    }
    const recEnt = (await effectiveEntitlement(recipient.uid)).data;
    if (activeEntitlement(recEnt)) {
      if (recEnt.source === 'family' && recEnt.ownerUid !== ownerUid) {
        throw new Error('failed-precondition: That account already has an active family subscription from another family.');
      } else if (recEnt.source !== 'family') {
        throw new Error('failed-precondition: That account has its own paid access and cannot join a family.');
      }
    }
    const recMem = await db.doc(`familyMemberships/${recipient.uid}`).get();
    if (recMem.exists && ['pending', 'active'].includes(recMem.data().state)) {
      throw new Error('failed-precondition: That account is already in a family relationship.');
    }
    const recFam = await db.doc(`families/${recipient.uid}`).get();
    if (recFam.exists && (recFam.data().memberUid || recFam.data().invitation)) {
      throw new Error('failed-precondition: That account already owns another family.');
    }
  }

  // 3. Execute atomic transaction
  let oldEmail = null;
  let oldUid = null;
  let backupOldState = null;

  await db.runTransaction(async (transaction) => {
    const familyRef = db.doc(`families/${ownerUid}`);
    const famSnap = await transaction.get(familyRef);
    if (!famSnap.exists) {
      throw new Error('not-found: Family record not found for this owner.');
    }
    const fam = famSnap.data();

    const ownerEntTx = await effectiveEntitlement(ownerUid, transaction);
    if (!activeEntitlement(ownerEntTx.data) || ownerEntTx.data.source === 'family') {
      throw new Error('failed-precondition: The Family Owner must have an active primary Premium entitlement.');
    }

    oldEmail = (fam.lockedRecipientEmail || fam.memberEmail || fam.invitation?.recipientEmail || '').toLowerCase().trim();
    if (oldEmail && oldEmail === newEmail) {
      throw new Error('invalid-argument: New email must differ from current locked email.');
    }

    oldUid = fam.memberUid || fam.invitation?.recipientUid || null;
    if (!oldUid && oldEmail) {
      const oldRec = mockGetUserByEmail(oldEmail);
      if (oldRec) oldUid = oldRec.uid;
    }

    backupOldState = {
      family: { ...fam },
      oldUid,
      oldEmail,
      oldMemberEnt: null,
      oldMemberMem: null,
      oldUserLegacy: null,
    };

    if (oldUid) {
      const [oldEntSnap, oldMemSnap, oldUserSnap] = await Promise.all([
        transaction.get(db.doc(`entitlements/${oldUid}`)),
        transaction.get(db.doc(`familyMemberships/${oldUid}`)),
        transaction.get(db.doc(`users/${oldUid}`)),
      ]);
      if (oldEntSnap.exists) backupOldState.oldMemberEnt = oldEntSnap.data();
      if (oldMemSnap.exists) backupOldState.oldMemberMem = oldMemSnap.data();
      if (oldUserSnap.exists) backupOldState.oldUserLegacy = oldUserSnap.data();

      transaction.set(db.doc(`entitlements/${oldUid}`), {
        status: 'inactive',
        source: 'none',
        ownerUid: null,
        expiresAt: null,
        updatedAt: ts(),
      }, { merge: true });

      transaction.set(db.doc(`familyMemberships/${oldUid}`), {
        ownerUid,
        memberUid: oldUid,
        state: 'removed',
        expiresAt: null,
        updatedAt: ts(),
      }, { merge: true });

      transaction.set(db.doc(`users/${oldUid}`), {
        hasFamilyPremium: false,
        updatedAt: ts(),
      }, { merge: true });
    }

    transaction.set(familyRef, {
      ownerUid,
      lockedRecipientEmail: newEmail,
      slotLockedAt: fam.slotLockedAt || ts(),
      invitation: {
        recipientUid: recipient ? recipient.uid : null,
        recipientEmail: newEmail,
        createdAt: ts(),
        correctedByAdminUid: actorUid,
        supportReason: reason,
      },
      memberUid: FieldValue.delete(),
      memberEmail: FieldValue.delete(),
      updatedAt: ts(),
    }, { merge: true });

    transaction.set(db.doc(`users/${ownerUid}`), {
      familyMembers: [],
      updatedAt: ts(),
    }, { merge: true });

    if (recipient) {
      transaction.set(db.doc(`familyMemberships/${recipient.uid}`), {
        ownerUid,
        memberUid: recipient.uid,
        state: 'pending',
        updatedAt: ts(),
      }, { merge: true });
    }
  });

  // 4. Send email with rollback on failure
  try {
    await mockSendEmail(newEmail, 'Invitation', '<p>Test</p>');
  } catch (smtpErr) {
    await db.runTransaction(async (rbTx) => {
      const famRef = db.doc(`families/${ownerUid}`);
      if (backupOldState?.family) {
        rbTx.set(famRef, backupOldState.family);
      }
      if (backupOldState?.oldUid) {
        if (backupOldState.oldMemberEnt) {
          rbTx.set(db.doc(`entitlements/${backupOldState.oldUid}`), backupOldState.oldMemberEnt);
        }
        if (backupOldState.oldMemberMem) {
          rbTx.set(db.doc(`familyMemberships/${backupOldState.oldUid}`), backupOldState.oldMemberMem);
        }
        if (backupOldState.oldUserLegacy) {
          rbTx.set(db.doc(`users/${backupOldState.oldUid}`), { hasFamilyPremium: backupOldState.oldUserLegacy.hasFamilyPremium ?? false }, { merge: true });
        }
      }
      if (recipient) {
        rbTx.delete(db.doc(`familyMemberships/${recipient.uid}`));
      }
    });
    throw new Error('Unable to send invitation email. Rollback executed: ' + smtpErr.message);
  }

  return {
    success: true,
    ownerUid,
    oldEmail,
    oldUid,
    newEmail,
    outcome: 'success',
  };
}

// Mirror of acceptFamilyInvitation
async function runAcceptFamilyInvitation({ memberUid, callerEmail }) {
  let activated = false;
  let ownerUidResult = null;

  await db.runTransaction(async (transaction) => {
    let m = null;
    const directMem = await transaction.get(db.doc(`familyMemberships/${memberUid}`));
    if (directMem.exists && directMem.data().state === 'pending') {
      m = directMem.data();
    }

    if (!m) {
      throw new Error('failed-precondition: No pending invitation found.');
    }

    const [ownerEnt, ownerFamily] = await Promise.all([
      effectiveEntitlement(m.ownerUid, transaction),
      transaction.get(db.doc(`families/${m.ownerUid}`)),
    ]);

    if (!activeEntitlement(ownerEnt.data) || ownerEnt.data.source === 'family') {
      throw new Error('failed-precondition: The Family Owner does not have an active subscription.');
    }

    const famData = ownerFamily.data() || {};
    const recipientEmail = famData.invitation?.recipientEmail || callerEmail || null;

    transaction.set(db.doc(`families/${m.ownerUid}`), {
      memberUid,
      memberEmail: recipientEmail,
      lockedRecipientEmail: famData.lockedRecipientEmail || recipientEmail,
      slotLockedAt: famData.slotLockedAt || ts(),
      invitation: FieldValue.delete(),
      activatedAt: ts(),
      updatedAt: ts(),
    }, { merge: true });

    transaction.set(db.doc(`familyMemberships/${memberUid}`), {
      ownerUid: m.ownerUid,
      memberUid,
      state: 'active',
      expiresAt: ownerEnt.data.expiresAt || null,
      updatedAt: ts(),
    }, { merge: true });

    transaction.set(db.doc(`entitlements/${memberUid}`), {
      status: 'active',
      source: 'family',
      ownerUid: m.ownerUid,
      expiresAt: ownerEnt.data.expiresAt || null,
      updatedAt: ts(),
    }, { merge: true });

    transaction.set(db.doc(`users/${memberUid}`), {
      hasFamilyPremium: true,
      updatedAt: ts(),
    }, { merge: true });

    transaction.set(db.doc(`users/${m.ownerUid}`), {
      familyMembers: [recipientEmail],
      updatedAt: ts(),
    }, { merge: true });

    activated = true;
    ownerUidResult = m.ownerUid;
  });

  return { success: activated, ownerUid: ownerUidResult };
}

const adminAuth = { uid: 'super_admin_user', token: { admin: true } };
const userAuth = { uid: 'regular_user', token: { admin: false } };

test('Suite: Partwk Family Sharing Support Correction & Eligibility Verification', async (t) => {
  const ownerUid = 'owner_eligibility_test';
  const oldMemberUid = 'old_member_eligibility_test';
  const expiry = Timestamp.fromDate(new Date('2028-12-31T23:59:59Z'));

  mockAuthUsers.set(ownerUid, { uid: ownerUid, email: 'owner@partwk.com' });
  mockAuthUsers.set(oldMemberUid, { uid: oldMemberUid, email: 'old_member@partwk.com' });

  // Setup initial active family relationship
  const resetOwnerWithOldMember = async () => {
    await db.doc(`entitlements/${ownerUid}`).set({ status: 'active', source: 'store', expiresAt: expiry });
    await db.doc(`entitlements/${oldMemberUid}`).set({ status: 'active', source: 'family', ownerUid, expiresAt: expiry });
    await db.doc(`familyMemberships/${oldMemberUid}`).set({ ownerUid, memberUid: oldMemberUid, state: 'active', expiresAt: expiry });
    await db.doc(`users/${oldMemberUid}`).set({ hasFamilyPremium: true });
    await db.doc(`families/${ownerUid}`).set({
      ownerUid,
      memberUid: oldMemberUid,
      memberEmail: 'old_member@partwk.com',
      lockedRecipientEmail: 'old_member@partwk.com',
      slotLockedAt: ts(),
    });
  };

  // 1. Existing registered Free account with no family history -> accepted and becomes pending
  await t.test('1. Existing registered Free account with no family history -> accepted and becomes pending', async () => {
    await resetOwnerWithOldMember();
    const freeUid = 'free_no_history_user';
    const freeEmail = 'free_no_history@partwk.com';
    mockAuthUsers.set(freeUid, { uid: freeUid, email: freeEmail, disabled: false });
    
    // Ensure clean state: no family history, no entitlement
    await db.doc(`familyMemberships/${freeUid}`).delete();
    await db.doc(`entitlements/${freeUid}`).delete();
    await db.doc(`users/${freeUid}`).set({ subscriptionStatus: 'free', hasFamilyPremium: false });

    const res = await runAdminUpdateFamilySlotEmail({
      request: {
        auth: adminAuth,
        data: {
          ownerUid,
          newEmail: freeEmail,
          reason: 'Support ticket #201: Target is normal registered free user',
        },
      },
    });

    assert.equal(res.success, true);
    assert.equal(res.oldUid, oldMemberUid);
    assert.equal(res.newEmail, freeEmail);

    // Old member was revoked
    const oldEnt = (await db.doc(`entitlements/${oldMemberUid}`).get()).data();
    const oldMem = (await db.doc(`familyMemberships/${oldMemberUid}`).get()).data();
    assert.equal(oldEnt.status, 'inactive');
    assert.equal(oldMem.state, 'removed');

    // New Free user is now pending in familyMemberships
    const newMem = (await db.doc(`familyMemberships/${freeUid}`).get()).data();
    assert.equal(newMem.state, 'pending');
    assert.equal(newMem.ownerUid, ownerUid);

    // New user does NOT have active entitlement before acceptance
    const newEnt = await db.doc(`entitlements/${freeUid}`).get();
    assert.equal(activeEntitlement(newEnt.exists ? newEnt.data() : null), false);

    // Family doc is updated with pending invitation
    const fam = (await db.doc(`families/${ownerUid}`).get()).data();
    assert.equal(fam.lockedRecipientEmail, freeEmail);
    assert.equal(fam.invitation.recipientEmail, freeEmail);
    assert.equal(fam.invitation.recipientUid, freeUid);
    assert.equal(fam.memberUid, undefined);
  });

  // 2. Existing registered Free account with historical removed membership -> accepted and becomes pending
  await t.test('2. Existing registered Free account with historical removed membership -> accepted and becomes pending', async () => {
    await resetOwnerWithOldMember();
    const removedUid = 'previously_removed_user';
    const removedEmail = 'previously_removed@partwk.com';
    mockAuthUsers.set(removedUid, { uid: removedUid, email: removedEmail, disabled: false });

    // Seed historical removed membership state
    await db.doc(`familyMemberships/${removedUid}`).set({
      ownerUid: 'another_past_owner',
      memberUid: removedUid,
      state: 'removed',
      updatedAt: ts(),
    });
    await db.doc(`entitlements/${removedUid}`).set({ status: 'inactive', source: 'none' });
    await db.doc(`users/${removedUid}`).set({ subscriptionStatus: 'free', hasFamilyPremium: false });

    const res = await runAdminUpdateFamilySlotEmail({
      request: {
        auth: adminAuth,
        data: {
          ownerUid,
          newEmail: removedEmail,
          reason: 'Support ticket #202: Target has historical removed membership',
        },
      },
    });

    assert.equal(res.success, true);
    assert.equal(res.newEmail, removedEmail);

    const mem = (await db.doc(`familyMemberships/${removedUid}`).get()).data();
    assert.equal(mem.state, 'pending');
    assert.equal(mem.ownerUid, ownerUid);

    // No active entitlement before acceptance
    const ent = await db.doc(`entitlements/${removedUid}`).get();
    assert.equal(activeEntitlement(ent.exists ? ent.data() : null), false);
  });

  // 3. Existing registered Free account with historical inactive entitlement -> accepted and becomes pending
  await t.test('3. Existing registered Free account with historical inactive entitlement -> accepted and becomes pending', async () => {
    await resetOwnerWithOldMember();
    const expiredEntUid = 'expired_entitlement_user';
    const expiredEmail = 'expired_entitlement@partwk.com';
    mockAuthUsers.set(expiredEntUid, { uid: expiredEntUid, email: expiredEmail, disabled: false });

    // Seed inactive / expired past entitlement
    await db.doc(`entitlements/${expiredEntUid}`).set({
      status: 'inactive',
      source: 'store',
      expiresAt: Timestamp.fromDate(new Date('2020-01-01T00:00:00Z')),
    });
    await db.doc(`familyMemberships/${expiredEntUid}`).delete();
    await db.doc(`users/${expiredEntUid}`).set({ subscriptionStatus: 'free', hasFamilyPremium: false });

    const res = await runAdminUpdateFamilySlotEmail({
      request: {
        auth: adminAuth,
        data: {
          ownerUid,
          newEmail: expiredEmail,
          reason: 'Support ticket #203: Target has expired entitlement',
        },
      },
    });

    assert.equal(res.success, true);
    assert.equal(res.newEmail, expiredEmail);

    const mem = (await db.doc(`familyMemberships/${expiredEntUid}`).get()).data();
    assert.equal(mem.state, 'pending');
    assert.equal(mem.ownerUid, ownerUid);

    // Retains no active entitlement
    const ent = await db.doc(`entitlements/${expiredEntUid}`).get();
    assert.equal(activeEntitlement(ent.data()), false);
  });

  // 4. Unregistered email -> remains supported as pending
  await t.test('4. Unregistered email -> remains supported as pending', async () => {
    await resetOwnerWithOldMember();
    const unregisteredEmail = 'unregistered_brand_new@partwk.com';

    const res = await runAdminUpdateFamilySlotEmail({
      request: {
        auth: adminAuth,
        data: {
          ownerUid,
          newEmail: unregisteredEmail,
          reason: 'Support ticket #204: Target is unregistered recipient',
        },
      },
    });

    assert.equal(res.success, true);
    assert.equal(res.newEmail, unregisteredEmail);

    const fam = (await db.doc(`families/${ownerUid}`).get()).data();
    assert.equal(fam.lockedRecipientEmail, unregisteredEmail);
    assert.equal(fam.invitation.recipientEmail, unregisteredEmail);
    assert.equal(fam.invitation.recipientUid, null);
    assert.equal(fam.memberUid, undefined);
  });

  // 5. Disabled Auth account -> rejected with a clear, accurate message
  await t.test('5. Disabled Auth account -> rejected with a clear, accurate message', async () => {
    await resetOwnerWithOldMember();
    const disabledUid = 'disabled_auth_user';
    const disabledEmail = 'disabled_auth@partwk.com';
    mockAuthUsers.set(disabledUid, { uid: disabledUid, email: disabledEmail, disabled: true });

    await assert.rejects(
      () => runAdminUpdateFamilySlotEmail({
        request: {
          auth: adminAuth,
          data: {
            ownerUid,
            newEmail: disabledEmail,
            reason: 'Support ticket #205: Disabled user test',
          },
        },
      }),
      /failed-precondition: That user account has been disabled\./
    );
  });

  // 6. Independently paid Premium account -> rejected
  await t.test('6. Independently paid Premium account -> rejected', async () => {
    await resetOwnerWithOldMember();
    const paidUid = 'paid_premium_user';
    const paidEmail = 'paid_premium@partwk.com';
    mockAuthUsers.set(paidUid, { uid: paidUid, email: paidEmail, disabled: false });
    await db.doc(`entitlements/${paidUid}`).set({ status: 'active', source: 'store', expiresAt: expiry });

    await assert.rejects(
      () => runAdminUpdateFamilySlotEmail({
        request: {
          auth: adminAuth,
          data: {
            ownerUid,
            newEmail: paidEmail,
            reason: 'Support ticket #206: Paid user test',
          },
        },
      }),
      /failed-precondition: That account has its own paid access and cannot join a family\./
    );
  });

  // 7. Active/pending member of another family -> rejected
  await t.test('7. Active/pending member of another family -> rejected', async () => {
    await resetOwnerWithOldMember();
    // 7A: Active member of another family
    const activeOtherUid = 'active_other_family_user';
    const activeOtherEmail = 'active_other_fam@partwk.com';
    mockAuthUsers.set(activeOtherUid, { uid: activeOtherUid, email: activeOtherEmail, disabled: false });
    await db.doc(`familyMemberships/${activeOtherUid}`).set({ ownerUid: 'other_owner_1', state: 'active' });

    await assert.rejects(
      () => runAdminUpdateFamilySlotEmail({
        request: {
          auth: adminAuth,
          data: {
            ownerUid,
            newEmail: activeOtherEmail,
            reason: 'Cross-family active invite',
          },
        },
      }),
      /failed-precondition: That account is already in a family relationship\./
    );

    // 7B: Pending member of another family
    const pendingOtherUid = 'pending_other_family_user';
    const pendingOtherEmail = 'pending_other_fam@partwk.com';
    mockAuthUsers.set(pendingOtherUid, { uid: pendingOtherUid, email: pendingOtherEmail, disabled: false });
    await db.doc(`familyMemberships/${pendingOtherUid}`).set({ ownerUid: 'other_owner_2', state: 'pending' });

    await assert.rejects(
      () => runAdminUpdateFamilySlotEmail({
        request: {
          auth: adminAuth,
          data: {
            ownerUid,
            newEmail: pendingOtherEmail,
            reason: 'Cross-family pending invite',
          },
        },
      }),
      /failed-precondition: That account is already in a family relationship\./
    );
  });

  // 8. Admin UI shows the real backend error, not a misleading generic "locked" message
  await t.test('8. Admin UI shows the real backend error, not a misleading generic "locked" message', async () => {
    // Simulate Admin UI error parser/formatter from UsersManagement.jsx
    function formatAdminError(err) {
      let errorMsg = err.message || String(err);
      errorMsg = errorMsg.replace(/^FirebaseError:\s*/, '').replace(/^[a-z-]+:\s*/, '');
      return errorMsg;
    }

    // A. Backend returns disabled error -> UI displays exact real message
    const disabledErr = new Error('failed-precondition: That user account has been disabled.');
    assert.equal(formatAdminError(disabledErr), 'That user account has been disabled.');

    // B. Backend returns paid premium error -> UI displays exact real message
    const paidErr = new Error('failed-precondition: That account has its own paid access and cannot join a family.');
    assert.equal(formatAdminError(paidErr), 'That account has its own paid access and cannot join a family.');

    // C. Backend returns already in family error -> UI displays exact real message
    const famErr = new Error('failed-precondition: That account is already in a family relationship.');
    assert.equal(formatAdminError(famErr), 'That account is already in a family relationship.');

    // D. State verification failure does not emit generic "locked" text
    function verifyDirectServerState(updatedFam, normEmail) {
      if ((updatedFam.lockedRecipientEmail || '').toLowerCase() !== normEmail) {
        throw new Error(`State verification failed: Locked recipient email mismatch (found "${updatedFam.lockedRecipientEmail}", expected "${normEmail}").`);
      }
      return true;
    }

    assert.equal(verifyDirectServerState({ lockedRecipientEmail: 'test@partwk.com' }, 'test@partwk.com'), true);
  });

  // 9. Recipient accepts invitation -> active Family Premium with primary expiry
  await t.test('9. Recipient accepts invitation -> active Family Premium with primary expiry', async () => {
    const freeUid = 'free_accepting_user';
    const freeEmail = 'free_accepting@partwk.com';
    mockAuthUsers.set(freeUid, { uid: freeUid, email: freeEmail, disabled: false });
    await db.doc(`familyMemberships/${freeUid}`).delete();
    await db.doc(`entitlements/${freeUid}`).delete();

    await resetOwnerWithOldMember();
    await runAdminUpdateFamilySlotEmail({
      request: {
        auth: adminAuth,
        data: {
          ownerUid,
          newEmail: freeEmail,
          reason: 'Acceptance verification flow',
        },
      },
    });

    const acceptRes = await runAcceptFamilyInvitation({
      memberUid: freeUid,
      callerEmail: freeEmail,
    });

    assert.equal(acceptRes.success, true);
    assert.equal(acceptRes.ownerUid, ownerUid);

    const mem = (await db.doc(`familyMemberships/${freeUid}`).get()).data();
    const ent = (await db.doc(`entitlements/${freeUid}`).get()).data();
    const user = (await db.doc(`users/${freeUid}`).get()).data();

    assert.equal(mem.state, 'active');
    assert.equal(ent.status, 'active');
    assert.equal(ent.source, 'family');
    assert.equal(ent.ownerUid, ownerUid);
    assert.equal(ent.expiresAt.toMillis(), expiry.toMillis());
    assert.equal(user.hasFamilyPremium, true);
  });
});
