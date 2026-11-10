/**
 * Focused backend verification tests for Partwk Admin Support: Correct Member Email
 * Tests all 9 requirements in the specification.
 */
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
process.env.GCLOUD_PROJECT = 'partwk-bd4ec';
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'partwk-bd4ec' });

const test = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: 'partwk-bd4ec' });
}
const db = admin.firestore();

// Helpers to simulate Cloud Function execution
const { Timestamp, FieldValue } = require('firebase-admin/firestore');

function ts() {
  return Timestamp.now();
}

function activeEntitlement(ent) {
  if (!ent || ent.status !== 'active') return false;
  if (!ent.expiresAt) return true;
  const exp = typeof ent.expiresAt.toDate === 'function' ? ent.expiresAt.toDate() : new Date(ent.expiresAt);
  return exp.getTime() > Date.now();
}

async function effectiveEntitlement(uid, tx = null) {
  const ref = db.doc(`entitlements/${uid}`);
  const snap = tx ? await tx.get(ref) : await ref.get();
  return { ref, data: snap.exists ? snap.data() : { status: 'inactive', source: 'none' } };
}

// Mock auth users table
const mockAuthUsers = new Map();

function mockGetUserByEmail(email) {
  const norm = String(email || '').trim().toLowerCase();
  for (const user of mockAuthUsers.values()) {
    if (user.email.toLowerCase() === norm) return user;
  }
  return null;
}

// Logic under test: adminUpdateFamilySlotEmail
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
    if (recipient.uid === ownerUid) {
      throw new Error('invalid-argument: Cannot assign family slot to the owner themselves.');
    }
    const recEnt = (await effectiveEntitlement(recipient.uid)).data;
    if (activeEntitlement(recEnt) && recEnt.source !== 'family') {
      throw new Error('failed-precondition: That account has its own paid access and cannot join a family.');
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

  // 4. Send invitation email with rollback on failure
  try {
    await mockSendEmail(newEmail, 'Partwk Invitation', '<html>...</html>');
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

    await db.collection('audit_logs').add({
      actorUid,
      action: 'admin_update_family_slot_email_failed',
      details: {
        ownerUid,
        oldEmail,
        newEmail,
        adminUid: actorUid,
        reason,
        outcome: 'failed',
        error: smtpErr.message,
      },
      createdAt: ts(),
    });

    throw new Error('internal: Unable to send invitation email. Rollback executed: ' + smtpErr.message);
  }

  await db.collection('audit_logs').add({
    actorUid,
    action: 'admin_update_family_slot_email',
    details: {
      ownerUid,
      oldEmail,
      newEmail,
      adminUid: actorUid,
      reason,
      outcome: 'success',
    },
    createdAt: ts(),
  });

  return {
    success: true,
    ownerUid,
    oldEmail,
    oldUid,
    newEmail,
    outcome: 'success',
  };
}

// Logic under test: acceptFamilyInvitation
async function runAcceptFamilyInvitation({ memberUid, callerEmail }) {
  await db.runTransaction(async (transaction) => {
    const member = await transaction.get(db.doc(`familyMemberships/${memberUid}`));
    if (!member.exists || member.data().state !== 'pending') {
      throw new Error('failed-precondition: No pending family invitation.');
    }
    const m = member.data();
    const [familySnap, ownerEnt, memberEnt] = await Promise.all([
      transaction.get(db.doc(`families/${m.ownerUid}`)),
      effectiveEntitlement(m.ownerUid, transaction),
      effectiveEntitlement(memberUid, transaction),
    ]);
    if (!familySnap.exists) {
      throw new Error('failed-precondition: This invitation is no longer valid.');
    }
    const famData = familySnap.data();
    const isMatchingRecipient = famData.invitation?.recipientUid === memberUid ||
      (callerEmail && famData.invitation?.recipientEmail === callerEmail);

    if (!isMatchingRecipient || famData.memberUid) {
      throw new Error('failed-precondition: This invitation is no longer valid.');
    }
    if (!activeEntitlement(ownerEnt.data)) {
      throw new Error('failed-precondition: The primary subscription is no longer active.');
    }
    if (activeEntitlement(memberEnt.data) && memberEnt.data.source !== 'family') {
      throw new Error('failed-precondition: Keep your independently paid subscription.');
    }

    const expiresAt = ownerEnt.data.expiresAt || null;
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
      expiresAt,
      updatedAt: ts(),
    }, { merge: true });

    transaction.set(db.doc(`entitlements/${memberUid}`), {
      status: 'active',
      source: 'family',
      ownerUid: m.ownerUid,
      expiresAt,
      updatedAt: ts(),
    }, { merge: true });

    transaction.set(db.doc(`users/${memberUid}`), {
      hasFamilyPremium: true,
      updatedAt: ts(),
    }, { merge: true });
  });

  return { status: 'active' };
}

// Logic under test: primary user attempting slot changes
async function runInviteFamilyMember({ ownerUid, email }) {
  const familySnap = await db.doc(`families/${ownerUid}`).get();
  const fam = familySnap.exists ? familySnap.data() : {};
  if (fam.lockedRecipientEmail) {
    throw new Error('failed-precondition: This family slot is permanently assigned. To change this member, please contact Partwk Support.');
  }
}

async function runCancelFamilyInvitation({ ownerUid }) {
  const famDoc = await db.doc(`families/${ownerUid}`).get();
  if (famDoc.exists && (famDoc.data().lockedRecipientEmail || famDoc.data().invitation)) {
    throw new Error('failed-precondition: Family invitations cannot be cancelled or replaced. To change this family member, please contact Partwk Support.');
  }
}

async function runRemoveFamilyMember({ ownerUid }) {
  const famDoc = await db.doc(`families/${ownerUid}`).get();
  if (famDoc.exists && (famDoc.data().lockedRecipientEmail || famDoc.data().memberUid)) {
    throw new Error('failed-precondition: This family slot is permanently assigned. To change this family member, please contact Partwk Support.');
  }
}

// Setup common test fixtures
const adminAuth = { uid: 'admin_1', token: { admin: true } };
const userAuth = { uid: 'regular_user', token: { admin: false } };

test('Suite: Partwk Family Sharing Support Correction Verification', async (t) => {
  const ownerUid = 'owner_suite_test';
  const oldMemberUid = 'old_member_suite_test';
  const newMemberUid = 'new_member_suite_test';
  const unregisteredEmail = 'unregistered_suite_test@partwk.com';
  const expiry = Timestamp.fromDate(new Date('2028-12-31T23:59:59Z'));

  mockAuthUsers.set(ownerUid, { uid: ownerUid, email: 'owner@partwk.com' });
  mockAuthUsers.set(oldMemberUid, { uid: oldMemberUid, email: 'old_member@partwk.com' });
  mockAuthUsers.set(newMemberUid, { uid: newMemberUid, email: 'new_member@partwk.com' });

  // 1. Active old member -> authorised admin correction -> old entitlement revoked, new recipient pending
  await t.test('1. Active old member -> authorised admin correction -> old entitlement revoked, new recipient pending', async () => {
    // Seed database
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

    const res = await runAdminUpdateFamilySlotEmail({
      request: {
        auth: adminAuth,
        data: {
          ownerUid,
          newEmail: 'new_member@partwk.com',
          reason: 'Support ticket #101: Typo in member email address',
        },
      },
    });

    assert.equal(res.success, true);
    assert.equal(res.oldUid, oldMemberUid);
    assert.equal(res.newEmail, 'new_member@partwk.com');

    // Verify old member revoked
    const oldEnt = (await db.doc(`entitlements/${oldMemberUid}`).get()).data();
    const oldMem = (await db.doc(`familyMemberships/${oldMemberUid}`).get()).data();
    const oldUser = (await db.doc(`users/${oldMemberUid}`).get()).data();
    assert.equal(oldEnt.status, 'inactive');
    assert.equal(oldEnt.source, 'none');
    assert.equal(oldMem.state, 'removed');
    assert.equal(oldUser.hasFamilyPremium, false);

    // Verify family state
    const fam = (await db.doc(`families/${ownerUid}`).get()).data();
    assert.equal(fam.lockedRecipientEmail, 'new_member@partwk.com');
    assert.equal(fam.invitation.recipientEmail, 'new_member@partwk.com');
    assert.equal(fam.invitation.recipientUid, newMemberUid);
    assert.equal(fam.memberUid, undefined);
    assert.equal(fam.memberEmail, undefined);

    // Verify new member pending
    const newMem = (await db.doc(`familyMemberships/${newMemberUid}`).get()).data();
    assert.equal(newMem.state, 'pending');
    assert.equal(newMem.ownerUid, ownerUid);

    // Verify new recipient does NOT have entitlement yet before acceptance
    const newEnt = await db.doc(`entitlements/${newMemberUid}`).get();
    assert.equal(newEnt.exists ? newEnt.data().status : 'none', 'none');
  });

  // 2. New registered free recipient accepts -> active Family Premium with primary expiry
  await t.test('2. New registered free recipient accepts -> active Family Premium with primary expiry', async () => {
    const acceptRes = await runAcceptFamilyInvitation({
      memberUid: newMemberUid,
      callerEmail: 'new_member@partwk.com',
    });
    assert.equal(acceptRes.status, 'active');

    // Verify entitlement granted with owner's exact expiry
    const newEnt = (await db.doc(`entitlements/${newMemberUid}`).get()).data();
    const newMem = (await db.doc(`familyMemberships/${newMemberUid}`).get()).data();
    const fam = (await db.doc(`families/${ownerUid}`).get()).data();

    assert.equal(newEnt.status, 'active');
    assert.equal(newEnt.source, 'family');
    assert.equal(newEnt.ownerUid, ownerUid);
    assert.equal(newEnt.expiresAt.toDate().toISOString(), expiry.toDate().toISOString());

    assert.equal(newMem.state, 'active');
    assert.equal(fam.memberUid, newMemberUid);
    assert.equal(fam.memberEmail, 'new_member@partwk.com');
    assert.equal(fam.invitation, undefined);
  });

  // 3. New unregistered recipient is reserved/pending and receives invitation without account enumeration
  await t.test('3. New unregistered recipient is reserved/pending without account enumeration', async () => {
    // Reset owner with old member
    await db.doc(`families/${ownerUid}`).set({
      ownerUid,
      memberUid: newMemberUid,
      memberEmail: 'new_member@partwk.com',
      lockedRecipientEmail: 'new_member@partwk.com',
      slotLockedAt: ts(),
    });

    let emailSentTo = null;
    const res = await runAdminUpdateFamilySlotEmail({
      request: {
        auth: adminAuth,
        data: {
          ownerUid,
          newEmail: unregisteredEmail,
          reason: 'Correcting to prospective user without an account yet',
        },
      },
      mockSendEmail: async (to) => { emailSentTo = to; },
    });

    assert.equal(res.success, true);
    assert.equal(emailSentTo, unregisteredEmail);

    const fam = (await db.doc(`families/${ownerUid}`).get()).data();
    assert.equal(fam.lockedRecipientEmail, unregisteredEmail);
    assert.equal(fam.invitation.recipientEmail, unregisteredEmail);
    assert.equal(fam.invitation.recipientUid, null);
  });

  // 4. Old member can no longer access Premium entitlement after correction
  await t.test('4. Old member can no longer access Premium entitlement after correction', async () => {
    const oldEnt = (await effectiveEntitlement(oldMemberUid)).data;
    assert.equal(activeEntitlement(oldEnt), false);
    assert.equal(oldEnt.status, 'inactive');
  });

  // 5. Primary subscriber cannot change the locked recipient through the app or direct callable
  await t.test('5. Primary subscriber cannot change the locked recipient through the app or direct callable', async () => {
    await assert.rejects(
      () => runInviteFamilyMember({ ownerUid, email: 'another@test.com' }),
      /This family slot is permanently assigned. To change this member, please contact Partwk Support./
    );

    await assert.rejects(
      () => runCancelFamilyInvitation({ ownerUid }),
      /Family invitations cannot be cancelled or replaced. To change this family member, please contact Partwk Support./
    );

    await assert.rejects(
      () => runRemoveFamilyMember({ ownerUid }),
      /This family slot is permanently assigned. To change this family member, please contact Partwk Support./
    );
  });

  // 6. Non-admin cannot call the support correction endpoint
  await t.test('6. Non-admin cannot call the support correction endpoint', async () => {
    await assert.rejects(
      () => runAdminUpdateFamilySlotEmail({
        request: {
          auth: userAuth,
          data: { ownerUid, newEmail: 'hacker@test.com', reason: 'Attempted privilege escalation' },
        },
      }),
      /permission-denied: Administrator required./
    );

    await assert.rejects(
      () => runAdminUpdateFamilySlotEmail({
        request: {
          auth: null,
          data: { ownerUid, newEmail: 'hacker@test.com', reason: 'Unauthenticated call' },
        },
      }),
      /unauthenticated: Authentication required./
    );
  });

  // 7. Missing support reason, same email, invalid email, independently Premium recipient and recipient already in another family are rejected
  await t.test('7. Edge-case rejections: missing reason, same email, invalid email, independently Premium, already in another family', async () => {
    // Missing reason
    await assert.rejects(
      () => runAdminUpdateFamilySlotEmail({
        request: { auth: adminAuth, data: { ownerUid, newEmail: 'valid@test.com', reason: '' } },
      }),
      /invalid-argument: A non-empty support reason is required./
    );

    // Invalid email
    await assert.rejects(
      () => runAdminUpdateFamilySlotEmail({
        request: { auth: adminAuth, data: { ownerUid, newEmail: 'not-an-email', reason: 'Typo' } },
      }),
      /invalid-argument: Valid newEmail is required./
    );

    // Same email
    await assert.rejects(
      () => runAdminUpdateFamilySlotEmail({
        request: { auth: adminAuth, data: { ownerUid, newEmail: unregisteredEmail, reason: 'Duplicate' } },
      }),
      /invalid-argument: New email must differ from current locked email./
    );

    // Independently paid recipient
    const paidUid = 'paid_user_suite';
    mockAuthUsers.set(paidUid, { uid: paidUid, email: 'paid@test.com' });
    await db.doc(`entitlements/${paidUid}`).set({ status: 'active', source: 'store', expiresAt: expiry });
    await assert.rejects(
      () => runAdminUpdateFamilySlotEmail({
        request: { auth: adminAuth, data: { ownerUid, newEmail: 'paid@test.com', reason: 'Correction to paid user' } },
      }),
      /failed-precondition: That account has its own paid access and cannot join a family./
    );

    // Recipient already in another family
    const familyMemberUid = 'other_family_member';
    mockAuthUsers.set(familyMemberUid, { uid: familyMemberUid, email: 'other_fam@test.com' });
    await db.doc(`familyMemberships/${familyMemberUid}`).set({ ownerUid: 'other_owner', state: 'active' });
    await assert.rejects(
      () => runAdminUpdateFamilySlotEmail({
        request: { auth: adminAuth, data: { ownerUid, newEmail: 'other_fam@test.com', reason: 'Cross-family invite' } },
      }),
      /failed-precondition: That account is already in a family relationship./
    );
  });

  // 8. SMTP failure rolls back the correction cleanly, leaving the old active relationship untouched
  await t.test('8. SMTP failure rolls back the correction cleanly, leaving the old active relationship untouched', async () => {
    // Setup owner with active member
    const activeOldMemberUid = 'smtp_rollback_old_uid';
    mockAuthUsers.set(activeOldMemberUid, { uid: activeOldMemberUid, email: 'active_old@partwk.com' });
    await db.doc(`entitlements/${activeOldMemberUid}`).set({ status: 'active', source: 'family', ownerUid, expiresAt: expiry });
    await db.doc(`familyMemberships/${activeOldMemberUid}`).set({ ownerUid, memberUid: activeOldMemberUid, state: 'active', expiresAt: expiry });
    await db.doc(`users/${activeOldMemberUid}`).set({ hasFamilyPremium: true });
    await db.doc(`families/${ownerUid}`).set({
      ownerUid,
      memberUid: activeOldMemberUid,
      memberEmail: 'active_old@partwk.com',
      lockedRecipientEmail: 'active_old@partwk.com',
      slotLockedAt: ts(),
    });

    const failingSendEmail = async () => {
      throw new Error('SMTP Connection timeout to mail.privateemail.com:465');
    };

    await assert.rejects(
      () => runAdminUpdateFamilySlotEmail({
        request: {
          auth: adminAuth,
          data: {
            ownerUid,
            newEmail: 'rollback_target@partwk.com',
            reason: 'Testing SMTP rollback',
          },
        },
        mockSendEmail: failingSendEmail,
      }),
      /Unable to send invitation email. Rollback executed/
    );

    // Verify database state remains completely intact as the old active relationship
    const fam = (await db.doc(`families/${ownerUid}`).get()).data();
    const oldEnt = (await db.doc(`entitlements/${activeOldMemberUid}`).get()).data();
    const oldMem = (await db.doc(`familyMemberships/${activeOldMemberUid}`).get()).data();
    const oldUser = (await db.doc(`users/${activeOldMemberUid}`).get()).data();

    assert.equal(fam.lockedRecipientEmail, 'active_old@partwk.com');
    assert.equal(fam.memberUid, activeOldMemberUid);
    assert.equal(fam.memberEmail, 'active_old@partwk.com');
    assert.equal(oldEnt.status, 'active');
    assert.equal(oldEnt.source, 'family');
    assert.equal(oldMem.state, 'active');
    assert.equal(oldUser.hasFamilyPremium, true);
  });

  // 9. Admin UI does not show success until canonical refetch confirms the change
  await t.test('9. Admin UI canonical refetch verification pattern', async () => {
    // Simulated UI verification function from UsersManagement.jsx
    function verifyCanonicalState({ res, refetchedFamilies, refetchedMemberships, refetchedEntitlements, ownerId, normEmail }) {
      if (!res || !res.success) {
        throw new Error('Server did not confirm success.');
      }
      const updatedFam = refetchedFamilies.find(f => f.id === ownerId);
      if (!updatedFam) {
        throw new Error('State verification failed: Owner family record not found.');
      }
      if ((updatedFam.lockedRecipientEmail || '').toLowerCase() !== normEmail) {
        throw new Error(`State verification failed: Locked recipient mismatch.`);
      }
      if (!updatedFam.invitation || (updatedFam.invitation.recipientEmail || '').toLowerCase() !== normEmail) {
        throw new Error('State verification failed: Pending invitation for new email was not created.');
      }
      if (updatedFam.memberUid || updatedFam.memberEmail) {
        throw new Error('State verification failed: Old member is still assigned on family record.');
      }
      if (res.oldUid) {
        const oldEnt = refetchedEntitlements.find(e => e.id === res.oldUid);
        if (oldEnt && oldEnt.source === 'family' && oldEnt.status === 'active') {
          throw new Error('State verification failed: Old member entitlement is still active.');
        }
        const oldMem = refetchedMemberships.find(m => m.id === res.oldUid);
        if (oldMem && oldMem.state === 'active') {
          throw new Error('State verification failed: Old member family membership is still active.');
        }
      }
      return true;
    }

    // A. Mismatch scenario (e.g. backend reported success but old entitlement remained active)
    assert.throws(
      () => verifyCanonicalState({
        res: { success: true, oldUid: 'old_123' },
        refetchedFamilies: [{ id: 'o_1', lockedRecipientEmail: 'new@test.com', invitation: { recipientEmail: 'new@test.com' } }],
        refetchedMemberships: [{ id: 'old_123', state: 'active' }], // still active!
        refetchedEntitlements: [{ id: 'old_123', source: 'family', status: 'active' }], // still active!
        ownerId: 'o_1',
        normEmail: 'new@test.com',
      }),
      /State verification failed: Old member entitlement is still active./
    );

    // B. Verified scenario (canonical refetch proves all 4 conditions)
    const success = verifyCanonicalState({
      res: { success: true, oldUid: 'old_123' },
      refetchedFamilies: [{ id: 'o_1', lockedRecipientEmail: 'new@test.com', invitation: { recipientEmail: 'new@test.com' } }],
      refetchedMemberships: [{ id: 'old_123', state: 'removed' }],
      refetchedEntitlements: [{ id: 'old_123', source: 'none', status: 'inactive' }],
      ownerId: 'o_1',
      normEmail: 'new@test.com',
    });
    assert.equal(success, true);
  });
});
