import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  collectionGroup,
  deleteField,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-gubify';
const code = 'K7M4P9Q2';
const otherCode = 'R8T5W3X6';
const ids = {
  owner: 'owner',
  member: 'member',
  second: 'second',
  outsider: 'outsider',
  otherOwner: 'otherOwner',
  communityOwner: 'communityOwner',
  communityMember: 'communityMember',
};
const now = () => new Date('2026-01-01T00:00:00Z');

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
const anonymousDb = () => env.unauthenticatedContext().firestore();
const profile = (uid) => ({
  displayName: uid,
  createdAt: now(),
  updatedAt: now(),
  activeHub: null,
  avatar: null,
});
const root = (overrides = {}) => ({
  gubId: 'g1',
  name: 'Token Gub',
  ownerId: ids.owner,
  inviteTokenId: code,
  memberCount: 1,
  createdAt: now(),
  ...overrides,
});
const token = (overrides = {}) => ({
  gubId: 'g1',
  ownerId: ids.owner,
  gubName: 'Token Gub',
  active: true,
  createdAt: now(),
  ...overrides,
});
const member = (uid, role = 'member', overrides = {}) => ({
  uid,
  displayName: uid,
  photoUrl: null,
  role,
  joinedAt: now(),
  ...(role === 'member' ? { joinedViaInviteToken: code } : {}),
  ...overrides,
});
const copy = (uid, role = 'member', overrides = {}) => ({
  gubId: 'g1',
  name: 'Token Gub',
  ownerId: ids.owner,
  role,
  joinedAt: now(),
  ...overrides,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});
after(async () => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const batch = writeBatch(context.firestore());
    for (const uid of Object.values(ids)) {
      batch.set(doc(context.firestore(), 'users', uid), profile(uid));
    }
    await batch.commit();
  });
});

async function seedGub({
  active = true,
  deleting = false,
  includeRoot = true,
  includeToken = true,
} = {}) {
  await env.withSecurityRulesDisabled(async (context) => {
    const seedDb = context.firestore();
    const batch = writeBatch(seedDb);
    if (includeToken) batch.set(doc(seedDb, 'inviteTokens', code), token({ active }));
    if (includeRoot) {
      batch.set(doc(seedDb, 'gubs', 'g1'), root(deleting ? {
        deletionStatus: 'deleting',
        deletionRequestedBy: ids.owner,
        deletionStartedAt: now(),
        deletionUpdatedAt: now(),
        deletionPhase: 'preparing',
      } : {}));
      batch.set(doc(seedDb, 'gubs', 'g1', 'members', ids.owner), member(ids.owner, 'owner'));
      batch.set(doc(seedDb, 'users', ids.owner, 'gubs', 'g1'), copy(ids.owner, 'owner'));
    }
    await batch.commit();
  });
}

function createGub({
  actor = ids.owner,
  includeRoot = true,
  includeToken = true,
  includeMember = true,
  includeCopy = true,
  rootOverrides = {},
  tokenOverrides = {},
  memberUid = actor,
  copyUid = actor,
  memberRole = 'owner',
  copyOverrides = {},
} = {}) {
  const clientDb = db(actor);
  const batch = writeBatch(clientDb);
  const rootData = root({ ownerId: actor, ...rootOverrides });
  if (includeToken) batch.set(doc(clientDb, 'inviteTokens', rootData.inviteTokenId), {
    ...token({ ownerId: actor, gubName: rootData.name, ...tokenOverrides }),
    createdAt: serverTimestamp(),
  });
  if (includeRoot) batch.set(doc(clientDb, 'gubs', 'g1'), { ...rootData, createdAt: serverTimestamp() });
  if (includeMember) batch.set(doc(clientDb, 'gubs', 'g1', 'members', memberUid), {
    ...member(memberUid, memberRole),
    joinedAt: serverTimestamp(),
  });
  if (includeCopy) batch.set(doc(clientDb, 'users', copyUid, 'gubs', 'g1'), {
    ...copy(copyUid, memberRole, { ownerId: actor, name: rootData.name, ...copyOverrides }),
    joinedAt: serverTimestamp(),
  });
  return batch.commit();
}

function joinGub({
  actor = ids.outsider,
  beforeCount = 1,
  increment = 1,
  proof = code,
  memberUid = actor,
  memberRole = 'member',
  copyUid = actor,
  includeRoot = true,
  includeMember = true,
  includeCopy = true,
  rootUpdates = {},
  memberOverrides = {},
  copyOverrides = {},
} = {}) {
  const clientDb = db(actor);
  const batch = writeBatch(clientDb);
  if (includeRoot) batch.update(doc(clientDb, 'gubs', 'g1'), {
    memberCount: beforeCount + increment,
    ...rootUpdates,
  });
  if (includeMember) batch.set(doc(clientDb, 'gubs', 'g1', 'members', memberUid), {
    ...member(memberUid, memberRole, {
      ...(memberRole === 'member' && proof != null ? { joinedViaInviteToken: proof } : {}),
      ...memberOverrides,
    }),
    joinedAt: serverTimestamp(),
  });
  if (includeCopy) batch.set(doc(clientDb, 'users', copyUid, 'gubs', 'g1'), {
    ...copy(copyUid, memberRole, copyOverrides),
    joinedAt: serverTimestamp(),
  });
  return batch.commit();
}

function startDeletion({ actor = ids.owner, revoke = true } = {}) {
  const clientDb = db(actor);
  const batch = writeBatch(clientDb);
  batch.update(doc(clientDb, 'gubs', 'g1'), {
    deletionStatus: 'deleting',
    deletionRequestedBy: actor,
    deletionStartedAt: serverTimestamp(),
    deletionUpdatedAt: serverTimestamp(),
    deletionPhase: 'preparing',
  });
  if (revoke) batch.update(doc(clientDb, 'inviteTokens', code), { active: false });
  return batch.commit();
}

function regenerateInvite(actor = ids.owner, newCode = otherCode) {
  const clientDb = db(actor);
  const batch = writeBatch(clientDb);
  batch.update(doc(clientDb, 'gubs', 'g1'), {
    inviteTokenId: newCode,
    inviteRegeneratedAt: serverTimestamp(),
  });
  batch.update(doc(clientDb, 'inviteTokens', code), { active: false });
  batch.set(doc(clientDb, 'inviteTokens', newCode), {
    gubId: 'g1', ownerId: ids.owner, gubName: 'Token Gub', active: true,
    createdAt: serverTimestamp(),
  });
  return batch.commit();
}

function regenerateInviteTransaction(actor = ids.owner, newCode = otherCode) {
  const clientDb = db(actor);
  const gubReference = doc(clientDb, 'gubs', 'g1');
  const newTokenReference = doc(clientDb, 'inviteTokens', newCode);
  const oldTokenReference = doc(clientDb, 'inviteTokens', code);

  return runTransaction(clientDb, async (transaction) => {
    await transaction.get(gubReference);
    await transaction.get(newTokenReference);
    await transaction.get(oldTokenReference);
    transaction.set(newTokenReference, {
      gubId: 'g1', ownerId: ids.owner, gubName: 'Token Gub', active: true,
      createdAt: serverTimestamp(),
    });
    transaction.update(oldTokenReference, { active: false });
    transaction.update(gubReference, {
      inviteTokenId: newCode,
      inviteRegeneratedAt: serverTimestamp(),
    });
  });
}

async function seedPrivateMembership() {
  await seedGub();
  await env.withSecurityRulesDisabled(async (context) => {
    const batch = writeBatch(context.firestore());
    batch.update(doc(context.firestore(), 'gubs', 'g1'), { memberCount: 2 });
    batch.set(doc(context.firestore(), 'gubs', 'g1', 'members', ids.member), member(ids.member));
    batch.set(doc(context.firestore(), 'users', ids.member, 'gubs', 'g1'), copy(ids.member));
    await batch.commit();
  });
}

async function seedCommunityMembership() {
  await env.withSecurityRulesDisabled(async (context) => {
    const seedDb = context.firestore();
    const batch = writeBatch(seedDb);
    batch.set(doc(seedDb, 'communities', 'c1'), {
      communityId: 'c1', name: 'Community', ownerId: ids.communityOwner,
      memberCount: 2, visibility: 'public', createdAt: now(),
      type: 'General', language: 'English', description: '', accessMode: 'open',
      nameKey: 'community', slug: 'community', slugAssignedAt: now(),
    });
    batch.set(doc(seedDb, 'communityPublic', 'community'), {
      communityId: 'c1', slug: 'community', name: 'Community', description: '',
      type: 'General', language: 'English', accessMode: 'open', memberCount: 2,
      createdAt: now(), updatedAt: now(),
    });
    batch.set(doc(seedDb, 'communities', 'c1', 'members', ids.communityOwner), {
      uid: ids.communityOwner, displayName: ids.communityOwner, photoUrl: null,
      role: 'owner', joinedAt: now(),
    });
    batch.set(doc(seedDb, 'communities', 'c1', 'members', ids.communityMember), {
      uid: ids.communityMember, displayName: ids.communityMember, photoUrl: null,
      role: 'member', joinedAt: now(),
    });
    batch.set(doc(seedDb, 'users', ids.communityOwner, 'communities', 'c1'), {
      communityId: 'c1', name: 'Community', ownerId: ids.communityOwner,
      memberCount: 2, visibility: 'public', role: 'owner', joinedAt: now(),
    });
    batch.set(doc(seedDb, 'users', ids.communityMember, 'communities', 'c1'), {
      communityId: 'c1', name: 'Community', ownerId: ids.communityOwner,
      memberCount: 2, visibility: 'public', role: 'member', joinedAt: now(),
    });
    batch.set(doc(seedDb, 'communityUserProgress', ids.communityOwner), {
      xp: 0, communityIds: ['c1'],
    });
    batch.set(doc(seedDb, 'communityUserProgress', ids.communityMember), {
      xp: 0, communityIds: ['c1'],
    });
    await batch.commit();
  });
}

function leavePrivateGub(actor, target = actor) {
  const clientDb = db(actor);
  const batch = writeBatch(clientDb);
  batch.update(doc(clientDb, 'gubs', 'g1'), { memberCount: 1 });
  batch.delete(doc(clientDb, 'gubs', 'g1', 'members', target));
  batch.delete(doc(clientDb, 'users', target, 'gubs', 'g1'));
  return batch.commit();
}

async function seedLeaveCleanupData() {
  await seedPrivateMembership();
  await env.withSecurityRulesDisabled(async (context) => {
    const seedDb = context.firestore();
    const batch = writeBatch(seedDb);
    batch.set(doc(seedDb, 'gubs', 'g1', 'tasks', 't1'), {
      gubId: 'g1', taskId: 't1', title: 'Task', description: '',
      creatorId: ids.owner, creatorName: ids.owner,
      assignedUserId: ids.member, assignedUserName: ids.member,
      status: 'active', priority: 'normal', createdAt: now(), dueDate: null,
      completedAt: null, completedBy: null, notificationsEnabled: true,
      archived: false, sourceType: null, sourceId: null, sourcePreview: null,
      originUserId: null, sourceAuthorName: null, additionalDetails: null,
    });
    batch.set(doc(seedDb, 'gubs', 'g1', 'goals', 'b1'), {
      goalId: 'b1', title: 'Budget', description: '', targetAmount: 100,
      currentAmount: 0, ownerId: ids.owner, completedMembers: 0,
      totalMembers: 2, status: 'active', archived: false, createdAt: now(),
      deadline: null, completedAt: null, sourceType: null, sourceId: null,
      sourcePreview: null, originUserId: null, sourceAuthorName: null,
    });
    batch.set(doc(seedDb, 'gubs', 'g1', 'goals', 'b1', 'members', ids.member), {
      uid: ids.member, displayName: ids.member, photoUrl: null, amount: 0,
      confirmed: false, updatedAt: now(), confirmedAt: null,
    });
    batch.set(doc(seedDb, 'gubs', 'g1', 'goals', 'b1', 'members', ids.owner), {
      uid: ids.owner, displayName: ids.owner, photoUrl: null, amount: 0,
      confirmed: false, updatedAt: now(), confirmedAt: null,
    });
    await batch.commit();
  });
}

async function leavePrivateGubClientFlow(actor = ids.member) {
  const clientDb = db(actor);
  await updateDoc(doc(clientDb, 'gubs', 'g1', 'tasks', 't1'), {
    assignedUserId: null,
    assignedUserName: null,
  });
  await deleteDoc(doc(clientDb, 'gubs', 'g1', 'goals', 'b1', 'members', actor));
  await runTransaction(clientDb, async (transaction) => {
    transaction.update(doc(clientDb, 'gubs', 'g1', 'goals', 'b1'), {
      currentAmount: 0,
      completedMembers: 0,
      totalMembers: 1,
    });
  });
  return leavePrivateGub(actor);
}

function leaveCommunity(actor, target = actor) {
  const clientDb = db(actor);
  const batch = writeBatch(clientDb);
  batch.update(doc(clientDb, 'communities', 'c1'), { memberCount: 1 });
  batch.update(doc(clientDb, 'communityPublic', 'community'), {
    memberCount: 1, updatedAt: serverTimestamp(),
  });
  batch.delete(doc(clientDb, 'communities', 'c1', 'members', target));
  batch.delete(doc(clientDb, 'users', target, 'communities', 'c1'));
  batch.set(doc(clientDb, 'communityUserProgress', target), {
    communityIds: [], membershipProjectionCommunityId: 'c1',
    membershipProjectionAction: 'leave',
    membershipProjectionUpdatedAt: serverTimestamp(),
  }, { merge: true });
  return batch.commit();
}

function banPrivateGub(actor, target = ids.member) {
  const clientDb = db(actor);
  const batch = writeBatch(clientDb);
  batch.update(doc(clientDb, 'gubs', 'g1'), { memberCount: 1 });
  batch.set(doc(clientDb, 'gubs', 'g1', 'bans', target), {
    userId: target, displayName: target, photoUrl: null, bannedBy: actor, bannedAt: serverTimestamp(),
  });
  batch.delete(doc(clientDb, 'gubs', 'g1', 'members', target));
  batch.delete(doc(clientDb, 'users', target, 'gubs', 'g1'));
  return batch.commit();
}

function banCommunity(actor, target = ids.communityMember) {
  const clientDb = db(actor);
  const batch = writeBatch(clientDb);
  batch.update(doc(clientDb, 'communities', 'c1'), { memberCount: 1 });
  batch.update(doc(clientDb, 'communityPublic', 'community'), {
    memberCount: 1, updatedAt: serverTimestamp(),
  });
  batch.set(doc(clientDb, 'communities', 'c1', 'bans', target), {
    userId: target, displayName: target, photoUrl: null, bannedBy: actor, bannedAt: serverTimestamp(),
  });
  batch.delete(doc(clientDb, 'communities', 'c1', 'members', target));
  batch.delete(doc(clientDb, 'users', target, 'communities', 'c1'));
  batch.set(doc(clientDb, 'communityUserProgress', target), {
    communityIds: [], membershipProjectionCommunityId: 'c1',
    membershipProjectionAction: 'ban',
    membershipProjectionUpdatedAt: serverTimestamp(),
  }, { merge: true });
  return batch.commit();
}

function joinOpenCommunity(actor = ids.communityMember, memberCount = 2) {
  const clientDb = db(actor);
  const batch = writeBatch(clientDb);
  batch.update(doc(clientDb, 'communities', 'c1'), { memberCount });
  batch.update(doc(clientDb, 'communityPublic', 'community'), {
    memberCount, updatedAt: serverTimestamp(),
  });
  batch.set(doc(clientDb, 'communities', 'c1', 'members', actor), {
    uid: actor, displayName: actor, photoUrl: null, role: 'member',
    joinedAt: serverTimestamp(),
  });
  batch.set(doc(clientDb, 'users', actor, 'communities', 'c1'), {
    communityId: 'c1', name: 'Community', ownerId: ids.communityOwner,
    memberCount, visibility: 'public', role: 'member',
    joinedAt: serverTimestamp(),
  });
  batch.set(doc(clientDb, 'communityUserProgress', actor), {
    xp: 0, communityIds: ['c1'], membershipProjectionCommunityId: 'c1',
    membershipProjectionAction: 'join',
    membershipProjectionUpdatedAt: serverTimestamp(),
  }, { merge: true });
  return batch.commit();
}

async function assertCommunityPublicMemberCount(memberCount) {
  await env.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    const [root, projection] = await Promise.all([
      getDoc(doc(firestore, 'communities', 'c1')),
      getDoc(doc(firestore, 'communityPublic', 'community')),
    ]);
    assert.equal(root.data().memberCount, memberCount);
    assert.equal(projection.data().memberCount, memberCount);
  });
}

function createCommunityRequest(actor = ids.communityMember) {
  return setDoc(doc(db(actor), 'communities', 'c1', 'joinRequests', actor), {
    userId: actor, displayName: actor, status: 'pending',
    createdAt: serverTimestamp(),
  });
}

function approveCommunityRequest(target = ids.communityMember) {
  const clientDb = db(ids.communityOwner);
  const batch = writeBatch(clientDb);
  batch.update(doc(clientDb, 'communities', 'c1'), { memberCount: 2 });
  batch.update(doc(clientDb, 'communityPublic', 'community'), {
    memberCount: 2, updatedAt: serverTimestamp(),
  });
  batch.update(doc(clientDb, 'communities', 'c1', 'joinRequests', target), {
    status: 'approved',
    resolvedAt: serverTimestamp(),
    resolvedBy: ids.communityOwner,
  });
  batch.set(doc(clientDb, 'communities', 'c1', 'members', target), {
    uid: target, displayName: target, photoUrl: null, role: 'member',
    joinedAt: serverTimestamp(),
  });
  batch.set(doc(clientDb, 'users', target, 'communities', 'c1'), {
    communityId: 'c1', name: 'Community', ownerId: ids.communityOwner,
    memberCount: 2, visibility: 'public', role: 'member',
    joinedAt: serverTimestamp(),
  });
  batch.set(doc(clientDb, 'communities', 'c1', 'membershipMutations', 'current'), {
    action: 'approve', userId: target, ownerId: ids.communityOwner,
    createdAt: serverTimestamp(),
  });
  batch.set(doc(clientDb, 'communityUserProgress', target), {
    xp: 0, communityIds: ['c1'], membershipProjectionCommunityId: 'c1',
    membershipProjectionAction: 'join',
    membershipProjectionUpdatedAt: serverTimestamp(),
  }, { merge: true });
  return batch.commit();
}

function approveCommunityRequestTransaction(target = ids.communityMember) {
  const clientDb = db(ids.communityOwner);
  const communityReference = doc(clientDb, 'communities', 'c1');
  const requestReference = doc(clientDb, 'communities', 'c1', 'joinRequests', target);
  const memberReference = doc(clientDb, 'communities', 'c1', 'members', target);
  const copyReference = doc(clientDb, 'users', target, 'communities', 'c1');
  const mutationReference = doc(clientDb, 'communities', 'c1', 'membershipMutations', 'current');
  const progressReference = doc(clientDb, 'communityUserProgress', target);
  return runTransaction(clientDb, async (transaction) => {
    await transaction.get(communityReference);
    await transaction.get(requestReference);
    await transaction.get(memberReference);
    await transaction.get(progressReference);
    transaction.update(communityReference, { memberCount: 3 });
    transaction.update(doc(clientDb, 'communityPublic', 'community'), {
      memberCount: 3, updatedAt: serverTimestamp(),
    });
    transaction.set(memberReference, {
      uid: target, displayName: target, photoUrl: null, role: 'member',
      joinedAt: serverTimestamp(),
    });
    transaction.set(copyReference, {
      communityId: 'c1', name: 'Community', ownerId: ids.communityOwner,
      memberCount: 3, visibility: 'public', role: 'member',
      joinedAt: serverTimestamp(),
    });
    transaction.update(requestReference, {
      status: 'approved', resolvedAt: serverTimestamp(), resolvedBy: ids.communityOwner,
    });
    transaction.set(mutationReference, {
      action: 'approve', userId: target, ownerId: ids.communityOwner,
      createdAt: serverTimestamp(),
    });
    transaction.set(progressReference, {
      xp: 0, communityIds: ['c1'], membershipProjectionCommunityId: 'c1',
      membershipProjectionAction: 'join',
      membershipProjectionUpdatedAt: serverTimestamp(),
    }, { merge: true });
  });
}

describe('invite token reads and isolation', () => {
  beforeEach(() => seedGub());
  test('1 unauthenticated user cannot get a token', () => assertFails(getDoc(doc(anonymousDb(), 'inviteTokens', code))));
  test('2 authenticated user can get the exact token', () => assertSucceeds(getDoc(doc(db(ids.outsider), 'inviteTokens', code))));
  test('3 invite token list is denied', () => assertFails(getDocs(collection(db(ids.outsider), 'inviteTokens'))));
  test('4 filtered invite token query is denied', () => assertFails(getDocs(query(collection(db(ids.outsider), 'inviteTokens'), where('active', '==', true)))));
  test('5 missing token grants no private root read', async () => {
    await assertSucceeds(getDoc(doc(db(ids.outsider), 'inviteTokens', otherCode)));
    await assertFails(getDoc(doc(db(ids.outsider), 'gubs', 'g1')));
  });
  test('6 non-member cannot get the private root', () => assertFails(getDoc(doc(db(ids.outsider), 'gubs', 'g1'))));
  test('7 non-member cannot list private Gubs', () => assertFails(getDocs(collection(db(ids.outsider), 'gubs'))));
  test('8 non-member can inspect only their own membership document', () => assertSucceeds(getDoc(doc(db(ids.outsider), 'gubs', 'g1', 'members', ids.outsider))));
  test('9 non-member cannot read another membership', () => assertFails(getDoc(doc(db(ids.outsider), 'gubs', 'g1', 'members', ids.owner))));
});

describe('atomic private Gub creation', () => {
  test('10 owner creates root, token, owner membership and copy atomically', () => assertSucceeds(createGub()));
  test('11 root without token is denied', () => assertFails(createGub({ includeToken: false })));
  test('12 token without root is denied', () => assertFails(createGub({ includeRoot: false, includeMember: false, includeCopy: false })));
  test('13 another user cannot create a token for a foreign owner', () => assertFails(createGub({ actor: ids.outsider, rootOverrides: { ownerId: ids.owner }, tokenOverrides: { ownerId: ids.owner } })));
  test('14 forged token gubId is denied', () => assertFails(createGub({ tokenOverrides: { gubId: 'other' } })));
  test('15 forged token ownerId is denied', () => assertFails(createGub({ tokenOverrides: { ownerId: ids.otherOwner } })));
  test('16 forged token gubName is denied', () => assertFails(createGub({ tokenOverrides: { gubName: 'Forged' } })));
  test('17 inactive token creation is denied', () => assertFails(createGub({ tokenOverrides: { active: false } })));
  test('18 extra token fields are denied', () => assertFails(createGub({ tokenOverrides: { secret: true } })));
  test('19 root without owner membership is denied', () => assertFails(createGub({ includeMember: false })));
  test('20 root without owner copy is denied', () => assertFails(createGub({ includeCopy: false })));
  test('21 token overwrite is denied', async () => {
    await seedGub();
    await assertFails(setDoc(doc(db(ids.owner), 'inviteTokens', code), token()));
  });
});

describe('token-proven atomic join', () => {
  beforeEach(() => seedGub());
  test('22 valid token join succeeds', () => assertSucceeds(joinGub()));
  test('23 knowing only gubId without proof is denied', () => assertFails(joinGub({ includeMember: false })));
  test('24 omitted membership proof is denied', () => assertFails(joinGub({ memberOverrides: { joinedViaInviteToken: null } })));
  test('25 forged membership proof is denied', () => assertFails(joinGub({ proof: otherCode })));
  test('26 token belonging to another Gub is denied', async () => {
    await env.withSecurityRulesDisabled((context) => updateDoc(doc(context.firestore(), 'inviteTokens', code), { gubId: 'other' }));
    await assertFails(joinGub());
  });
  test('27 missing token is denied', async () => {
    await env.withSecurityRulesDisabled((context) => deleteDoc(doc(context.firestore(), 'inviteTokens', code)));
    await assertFails(joinGub());
  });
  test('28 inactive token is denied', async () => {
    await env.withSecurityRulesDisabled((context) => updateDoc(doc(context.firestore(), 'inviteTokens', code), { active: false }));
    await assertFails(joinGub());
  });
  test('29 token with missing root cannot join', async () => {
    await env.withSecurityRulesDisabled((context) => deleteDoc(doc(context.firestore(), 'gubs', 'g1')));
    await assertFails(joinGub());
  });
  test('30 deleting Gub cannot be joined', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'inviteTokens', code), { active: false });
      await updateDoc(doc(context.firestore(), 'gubs', 'g1'), { deletionStatus: 'deleting', deletionRequestedBy: ids.owner, deletionStartedAt: now(), deletionUpdatedAt: now(), deletionPhase: 'preparing' });
    });
    await assertFails(joinGub());
  });
  test('31 membership under another UID is denied', () => assertFails(joinGub({ memberUid: ids.second })));
  test('32 owner role is denied to a joining user', () => assertFails(joinGub({ memberRole: 'owner' })));
  test('33 admin role is denied to a joining user', () => assertFails(joinGub({ memberRole: 'admin' })));
  test('34 copy under another user is denied', () => assertFails(joinGub({ copyUid: ids.second })));
  test('35 copy with different gubId is denied', () => assertFails(joinGub({ copyOverrides: { gubId: 'other' } })));
  test('36 forged copy name is denied', () => assertFails(joinGub({ copyOverrides: { name: 'Forged' } })));
  test('37 forged copy ownerId is denied', () => assertFails(joinGub({ copyOverrides: { ownerId: ids.otherOwner } })));
  test('38 forged copy role is denied', () => assertFails(joinGub({ copyOverrides: { role: 'owner' } })));
  test('39 increment without membership is denied', () => assertFails(joinGub({ includeMember: false })));
  test('40 membership without increment is denied', () => assertFails(joinGub({ includeRoot: false })));
  test('41 copy alone is denied', () => assertFails(joinGub({ includeRoot: false, includeMember: false })));
  test('42 increment greater than one is denied', () => assertFails(joinGub({ increment: 2 })));
  test('43 simultaneous root field modification is denied', () => assertFails(joinGub({ rootUpdates: { name: 'Changed' } })));
  test('44 second join is denied', async () => {
    await joinGub();
    await assertFails(joinGub({ beforeCount: 2 }));
  });
  test('45 second increment is denied', async () => {
    await joinGub();
    await assertFails(updateDoc(doc(db(ids.outsider), 'gubs', 'g1'), { memberCount: 3 }));
  });
  test('46 separated membership write is denied', () => assertFails(setDoc(doc(db(ids.outsider), 'gubs', 'g1', 'members', ids.outsider), member(ids.outsider))));
  test('47 two different users can join exactly once', async () => {
    await assertSucceeds(joinGub());
    await assertSucceeds(joinGub({ actor: ids.second, beforeCount: 2 }));
  });
});

describe('revocation, deletion, retry, and Community isolation', () => {
  beforeEach(() => seedGub());
  test('48 non-owner cannot revoke token', () => assertFails(updateDoc(doc(db(ids.outsider), 'inviteTokens', code), { active: false })));
  test('49 owner starts deletion and revokes token atomically', () => assertSucceeds(startDeletion()));
  test('50 root cannot become deleting while token stays active', () => assertFails(startDeletion({ revoke: false })));
  test('51 inactive token cannot be reactivated', async () => {
    await startDeletion();
    await assertFails(updateDoc(doc(db(ids.owner), 'inviteTokens', code), { active: true }));
  });
  test('52 deletion owner removes token and then root', async () => {
    await startDeletion();
    await assertSucceeds(deleteDoc(doc(db(ids.owner), 'inviteTokens', code)));
    await assertSucceeds(deleteDoc(doc(db(ids.owner), 'gubs', 'g1')));
  });
  test('53 retry remains possible when token is already absent', async () => {
    await startDeletion();
    await deleteDoc(doc(db(ids.owner), 'inviteTokens', code));
    await assertSucceeds(updateDoc(doc(db(ids.owner), 'gubs', 'g1'), { deletionUpdatedAt: serverTimestamp() }));
  });
  test('54 no join is possible after deletion starts', async () => {
    await startDeletion();
    await assertFails(joinGub());
  });
  test('55 existing member retains expected read access while deleting', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'gubs', 'g1', 'members', ids.member), member(ids.member));
      await setDoc(doc(context.firestore(), 'users', ids.member, 'gubs', 'g1'), copy(ids.member));
    });
    await startDeletion();
    await assertSucceeds(getDoc(doc(db(ids.member), 'gubs', 'g1')));
  });
  test('56 Community creation remains valid', async () => {
    const clientDb = db(ids.communityOwner);
    const batch = writeBatch(clientDb);
    batch.set(doc(clientDb, 'communities', 'c1'), { communityId: 'c1', name: 'Community', ownerId: ids.communityOwner, memberCount: 1, visibility: 'public', createdAt: serverTimestamp(), type: 'General', language: 'English', description: '', accessMode: 'open', nameKey: 'community', slug: 'community', slugAssignedAt: serverTimestamp() });
    batch.set(doc(clientDb, 'communityNames', 'community'), { nameKey: 'community', communityId: 'c1', ownerId: ids.communityOwner, createdAt: serverTimestamp() });
    batch.set(doc(clientDb, 'communitySlugs', 'community'), { slug: 'community', communityId: 'c1', ownerId: ids.communityOwner, createdAt: serverTimestamp() });
    batch.set(doc(clientDb, 'communityPublic', 'community'), { communityId: 'c1', slug: 'community', name: 'Community', description: '', type: 'General', language: 'English', accessMode: 'open', memberCount: 1, createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
    batch.set(doc(clientDb, 'communities', 'c1', 'members', ids.communityOwner), { uid: ids.communityOwner, displayName: ids.communityOwner, photoUrl: null, role: 'owner', joinedAt: serverTimestamp() });
    batch.set(doc(clientDb, 'users', ids.communityOwner, 'communities', 'c1'), { communityId: 'c1', name: 'Community', ownerId: ids.communityOwner, memberCount: 1, visibility: 'public', role: 'owner', joinedAt: serverTimestamp() });
    batch.set(doc(clientDb, 'communityOwnership', ids.communityOwner), { ownerId: ids.communityOwner, communityId: 'c1', createdAt: serverTimestamp() });
    batch.set(doc(clientDb, 'communityUserProgress', ids.communityOwner), {
      xp: 0, communityIds: ['c1'], membershipProjectionCommunityId: 'c1',
      membershipProjectionAction: 'join',
      membershipProjectionUpdatedAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());
  });
});

describe('Step 1A membership leave and removal', () => {
  test('Community membership projection cannot add an unrelated Community', async () => {
    await seedCommunityMembership();
    await assertFails(updateDoc(
      doc(db(ids.communityMember), 'communityUserProgress', ids.communityMember),
      {
        communityIds: ['c1', 'forged'],
        membershipProjectionCommunityId: 'forged',
        membershipProjectionAction: 'backfill',
        membershipProjectionUpdatedAt: serverTimestamp(),
      },
    ));
  });

  test('Community member can backfill only an authoritative current membership', async () => {
    await seedCommunityMembership();
    await env.withSecurityRulesDisabled((context) => updateDoc(
      doc(context.firestore(), 'communityUserProgress', ids.communityMember),
      { communityIds: [] },
    ));
    await assertSucceeds(updateDoc(
      doc(db(ids.communityMember), 'communityUserProgress', ids.communityMember),
      {
        communityIds: ['c1'],
        membershipProjectionCommunityId: 'c1',
        membershipProjectionAction: 'backfill',
        membershipProjectionUpdatedAt: serverTimestamp(),
      },
    ));
  });

  test('57 private member can execute the real leave cleanup flow', async () => {
    await seedLeaveCleanupData();
    await assertSucceeds(leavePrivateGubClientFlow());
  });
  test('58 private member can leave atomically', async () => {
    await seedPrivateMembership();
    await assertSucceeds(leavePrivateGub(ids.member));
  });
  test('leave cleanup cannot change unrelated task fields', async () => {
    await seedLeaveCleanupData();
    await assertFails(updateDoc(
      doc(db(ids.member), 'gubs', 'g1', 'tasks', 't1'),
      { title: 'Changed while leaving' },
    ));
  });
  test('leave cleanup cannot remove a confirmed Shared Budget member', async () => {
    await seedLeaveCleanupData();
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(context.firestore(), 'gubs', 'g1', 'goals', 'b1', 'members', ids.member),
        { confirmed: true, amount: 10, confirmedAt: now() },
      );
    });
    await assertFails(deleteDoc(
      doc(db(ids.member), 'gubs', 'g1', 'goals', 'b1', 'members', ids.member),
    ));
  });
  test('leave cleanup cannot alter Shared Budget amounts or confirmations', async () => {
    await seedLeaveCleanupData();
    await deleteDoc(doc(db(ids.member), 'gubs', 'g1', 'goals', 'b1', 'members', ids.member));
    await assertFails(updateDoc(doc(db(ids.member), 'gubs', 'g1', 'goals', 'b1'), {
      currentAmount: 10,
      completedMembers: 1,
      totalMembers: 1,
    }));
  });
  test('59 private owner cannot self-leave', async () => {
    await seedPrivateMembership();
    await assertFails(leavePrivateGub(ids.owner));
  });
  test('60 private owner can remove a member', async () => {
    await seedPrivateMembership();
    await assertSucceeds(leavePrivateGub(ids.owner, ids.member));
  });
  test('61 private member cannot remove another member', async () => {
    await seedPrivateMembership();
    await assertFails(leavePrivateGub(ids.member, ids.second));
  });
  test('62 community member can leave atomically', async () => {
    await seedCommunityMembership();
    await assertSucceeds(leaveCommunity(ids.communityMember));
    await assertCommunityPublicMemberCount(1);
  });
  test('63 community owner cannot self-leave', async () => {
    await seedCommunityMembership();
    await assertFails(leaveCommunity(ids.communityOwner));
  });
  test('64 community owner can remove a member', async () => {
    await seedCommunityMembership();
    await assertSucceeds(leaveCommunity(ids.communityOwner, ids.communityMember));
    await assertCommunityPublicMemberCount(1);
  });
  test('open Community join keeps the root and public member counts synchronized', async () => {
    await seedCommunityMembership();
    await assertSucceeds(joinOpenCommunity(ids.outsider, 3));
    await assertCommunityPublicMemberCount(3);
  });
  test('65 outsider cannot change private or community membership', async () => {
    await seedPrivateMembership();
    await seedCommunityMembership();
    await assertFails(leavePrivateGub(ids.outsider, ids.member));
    await assertFails(leaveCommunity(ids.outsider, ids.communityMember));
  });
});

describe('Step 1B persistent bans', () => {
  test('65 private owner can ban a normal member atomically', async () => {
    await seedPrivateMembership();
    await assertSucceeds(banPrivateGub(ids.owner));
  });
  test('66 private member cannot ban another member', async () => {
    await seedPrivateMembership();
    await assertFails(banPrivateGub(ids.member, ids.owner));
  });
  test('67 private owner cannot ban themselves', async () => {
    await seedPrivateMembership();
    await assertFails(banPrivateGub(ids.owner, ids.owner));
  });
  test('68 private outsider cannot ban a member', async () => {
    await seedPrivateMembership();
    await assertFails(banPrivateGub(ids.outsider));
  });
  test('69 a banned private member cannot rejoin with a valid invite', async () => {
    await seedPrivateMembership();
    await banPrivateGub(ids.owner);
    await assertFails(joinGub({ actor: ids.member }));
  });
  test('70 Community owner can ban a normal member atomically', async () => {
    await seedCommunityMembership();
    await assertSucceeds(banCommunity(ids.communityOwner));
    await assertCommunityPublicMemberCount(1);
  });
  test('71 Community member cannot ban another member', async () => {
    await seedCommunityMembership();
    await assertFails(banCommunity(ids.communityMember, ids.communityOwner));
  });
  test('72 Community owner cannot ban themselves', async () => {
    await seedCommunityMembership();
    await assertFails(banCommunity(ids.communityOwner, ids.communityOwner));
  });
  test('73 Community outsider cannot ban a member', async () => {
    await seedCommunityMembership();
    await assertFails(banCommunity(ids.outsider));
  });
  test('74 a banned Community member cannot use open access to rejoin', async () => {
    await seedCommunityMembership();
    await banCommunity(ids.communityOwner);
    await assertFails(joinOpenCommunity());
  });
  test('75 a banned Community member cannot create an approval request', async () => {
    await seedCommunityMembership();
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'communities', 'c1'), {
        accessMode: 'approval',
      });
    });
    await banCommunity(ids.communityOwner);
    await assertFails(createCommunityRequest());
  });
  test('76 a pending request for a banned user cannot be approved', async () => {
    await seedCommunityMembership();
    await env.withSecurityRulesDisabled(async (context) => {
      const seedDb = context.firestore();
      await updateDoc(doc(seedDb, 'communities', 'c1'), { accessMode: 'approval' });
      await setDoc(doc(seedDb, 'communities', 'c1', 'joinRequests', ids.outsider), {
        userId: ids.outsider, displayName: ids.outsider, status: 'pending',
        createdAt: now(),
      });
      await setDoc(doc(seedDb, 'communities', 'c1', 'bans', ids.outsider), {
        userId: ids.outsider, displayName: ids.outsider, photoUrl: null, bannedBy: ids.communityOwner, bannedAt: now(),
      });
    });
    await assertFails(approveCommunityRequest(ids.outsider));
  });
  test('Community owner can approve with the repository transaction and grant access', async () => {
    await seedCommunityMembership();
    await env.withSecurityRulesDisabled(async (context) => {
      const seedDb = context.firestore();
      await updateDoc(doc(seedDb, 'communities', 'c1'), { accessMode: 'approval' });
      await setDoc(doc(seedDb, 'communities', 'c1', 'joinRequests', ids.outsider), {
        userId: ids.outsider, displayName: ids.outsider, status: 'pending',
        createdAt: now(),
      });
    });
    await assertSucceeds(approveCommunityRequestTransaction(ids.outsider));
    await assertCommunityPublicMemberCount(3);
    await assertSucceeds(getDoc(doc(db(ids.outsider), 'communities', 'c1')));
    await assertSucceeds(getDoc(
      doc(db(ids.outsider), 'users', ids.outsider, 'communities', 'c1'),
    ));
  });
  test('77 rejecting a request does not create a ban', async () => {
    await seedCommunityMembership();
    await env.withSecurityRulesDisabled(async (context) => {
      const seedDb = context.firestore();
      await updateDoc(doc(seedDb, 'communities', 'c1'), { accessMode: 'approval' });
      await setDoc(doc(seedDb, 'communities', 'c1', 'joinRequests', ids.outsider), {
        userId: ids.outsider, displayName: ids.outsider, status: 'pending',
        createdAt: now(),
      });
    });
    await assertSucceeds(updateDoc(
      doc(db(ids.communityOwner), 'communities', 'c1', 'joinRequests', ids.outsider),
      {
        status: 'rejected',
        resolvedAt: serverTimestamp(),
        resolvedBy: ids.communityOwner,
      },
    ));
    const snapshot = await getDoc(
      doc(db(ids.communityOwner), 'communities', 'c1', 'bans', ids.outsider),
    );
    if (snapshot.exists()) throw new Error('A rejection must not create a ban.');
  });
  test('78 a rejected Community request can be submitted again', async () => {
    await seedCommunityMembership();
    await env.withSecurityRulesDisabled(async (context) => {
      const seedDb = context.firestore();
      await updateDoc(doc(seedDb, 'communities', 'c1'), { accessMode: 'approval' });
      await setDoc(doc(seedDb, 'communities', 'c1', 'joinRequests', ids.outsider), {
        userId: ids.outsider, displayName: ids.outsider, status: 'rejected',
        createdAt: now(), resolvedAt: now(), resolvedBy: ids.communityOwner,
      });
    });
    await assertSucceeds(updateDoc(
      doc(db(ids.outsider), 'communities', 'c1', 'joinRequests', ids.outsider),
      { status: 'pending', resolvedAt: deleteField(), resolvedBy: deleteField() },
    ));
  });
  test('79 an unbanned former member can reset an approved request and be approved again', async () => {
    await seedCommunityMembership();
    await env.withSecurityRulesDisabled(async (context) => {
      const seedDb = context.firestore();
      await updateDoc(doc(seedDb, 'communities', 'c1'), {
        accessMode: 'approval',
      });
      await setDoc(
        doc(
          seedDb,
          'communities',
          'c1',
          'joinRequests',
          ids.communityMember,
        ),
        {
          userId: ids.communityMember,
          displayName: ids.communityMember,
          status: 'approved',
          createdAt: now(),
          resolvedAt: now(),
          resolvedBy: ids.communityOwner,
        },
      );
    });

    await assertSucceeds(banCommunity(ids.communityOwner));
    await assertFails(updateDoc(
      doc(
        db(ids.communityMember),
        'communities',
        'c1',
        'joinRequests',
        ids.communityMember,
      ),
      { status: 'pending', resolvedAt: deleteField(), resolvedBy: deleteField() },
    ));
    await assertSucceeds(deleteDoc(
      doc(
        db(ids.communityOwner),
        'communities',
        'c1',
        'bans',
        ids.communityMember,
      ),
    ));
    await assertSucceeds(updateDoc(
      doc(
        db(ids.communityMember),
        'communities',
        'c1',
        'joinRequests',
        ids.communityMember,
      ),
      { status: 'pending', resolvedAt: deleteField(), resolvedBy: deleteField() },
    ));
    await assertSucceeds(approveCommunityRequest(ids.communityMember));
    await assertSucceeds(getDoc(
      doc(db(ids.communityMember), 'communities', 'c1'),
    ));
  });
});

describe('Step 1D invite regeneration', () => {
  beforeEach(() => seedGub());
  test('80 owner can regenerate an invite through the repository transaction', () =>
    assertSucceeds(regenerateInviteTransaction()));
  test('81 owner can regenerate an invite atomically', () =>
    assertSucceeds(regenerateInvite()));
  test('80 a normal member cannot regenerate an invite', async () => {
    await seedPrivateMembership();
    await assertFails(regenerateInvite(ids.member));
  });
  test('81 an outsider cannot regenerate an invite', () =>
    assertFails(regenerateInvite(ids.outsider)));
  test('82 the old invite cannot join after regeneration', async () => {
    await regenerateInvite();
    await assertFails(joinGub());
  });
  test('83 the new invite joins a non-banned user', async () => {
    await regenerateInvite();
    await assertSucceeds(joinGub({ proof: otherCode }));
  });
  test('84 regeneration preserves existing members and memberCount', async () => {
    await seedPrivateMembership();
    await regenerateInvite();
    const ownerView = db(ids.owner);
    const rootSnapshot = await getDoc(doc(ownerView, 'gubs', 'g1'));
    const memberSnapshot = await getDoc(doc(db(ids.member), 'gubs', 'g1', 'members', ids.member));
    if (rootSnapshot.data()?.memberCount !== 2 || !memberSnapshot.exists()) {
      throw new Error('Regeneration must not alter memberships or memberCount.');
    }
  });
  test('85 a banned user cannot use the new invite', async () => {
    await seedPrivateMembership();
    await banPrivateGub(ids.owner);
    await regenerateInvite();
    await assertFails(joinGub({ actor: ids.member, proof: otherCode }));
  });
});

describe('Phase E display name cooldown', () => {
  for (const [provider, uid] of [
    ['anonymous', 'rename-anonymous'],
    ['google.com', 'rename-google'],
    ['password', 'rename-password'],
  ]) {
    test(`first rename succeeds for ${provider} authenticated owner`, async () => {
      await env.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'users', uid), profile(uid));
      });
      const providerDb = env.authenticatedContext(uid, {
        firebase: { sign_in_provider: provider },
      }).firestore();
      await assertSucceeds(updateDoc(doc(providerDb, 'users', uid), {
        displayName: `${provider} renamed`,
        displayNameChangedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }));
      await assertFails(updateDoc(doc(providerDb, 'users', uid), {
        displayName: `${provider} too soon`,
        displayNameChangedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }));
    });
  }

  test('onboarding profile creation remains valid and cannot seed a cooldown', async () => {
    const newUid = 'new-profile';
    await assertSucceeds(setDoc(doc(db(newUid), 'users', newUid), profile(newUid)));
    await assertFails(setDoc(doc(db('forged-profile'), 'users', 'forged-profile'), {
      ...profile('forged-profile'),
      displayNameChangedAt: serverTimestamp(),
    }));
  });

  test('owner can perform the first post-onboarding name change', async () => {
    await assertSucceeds(updateDoc(doc(db(ids.member), 'users', ids.member), {
      displayName: 'New name',
      displayNameChangedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));
  });

  test('a second name change inside 30 days is denied', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'users', ids.member), {
        displayNameChangedAt: new Date(),
      });
    });
    await assertFails(updateDoc(doc(db(ids.member), 'users', ids.member), {
      displayName: 'Too soon',
      displayNameChangedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));
  });

  test('name change after 30 days is allowed', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'users', ids.member), {
        displayNameChangedAt: new Date('2020-01-01T00:00:00Z'),
      });
    });
    await assertSucceeds(updateDoc(doc(db(ids.member), 'users', ids.member), {
      displayName: 'Allowed again',
      displayNameChangedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));
  });

  test('normal profile updates need no cooldown metadata and cannot alter it', async () => {
    await assertSucceeds(updateDoc(doc(db(ids.member), 'users', ids.member), {
      photoUrl: 'https://example.test/photo.png',
      updatedAt: serverTimestamp(),
    }));

    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'users', ids.member), {
        displayNameChangedAt: new Date('2020-01-01T00:00:00Z'),
      });
    });
    await assertSucceeds(updateDoc(doc(db(ids.member), 'users', ids.member), {
      photoUrl: 'https://example.test/second.png',
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db(ids.member), 'users', ids.member), {
      photoUrl: 'https://example.test/forged.png',
      displayNameChangedAt: deleteField(),
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db(ids.member), 'users', ids.member), {
      photoUrl: 'https://example.test/forged.png',
      displayNameChangedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));
  });

  test('timestamp backdating and unrelated field changes are denied', async () => {
    await assertFails(updateDoc(doc(db(ids.member), 'users', ids.member), {
      displayName: 'Backdated',
      displayNameChangedAt: new Date('2020-01-01T00:00:00Z'),
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db(ids.member), 'users', ids.member), {
      displayName: 'Extra change',
      displayNameChangedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      activeHub: 'forged',
    }));
  });

  test('another user cannot change a profile name', () =>
    assertFails(updateDoc(doc(db(ids.outsider), 'users', ids.member), {
      displayName: 'Forged',
      displayNameChangedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    })));

  test('private rename keeps membership coherent and future writes authorized', async () => {
    await seedPrivateMembership();
    const clientDb = db(ids.member);
    const batch = writeBatch(clientDb);
    batch.update(doc(clientDb, 'users', ids.member), {
      displayName: 'New Name',
      displayNameChangedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    batch.update(doc(clientDb, 'gubs', 'g1', 'members', ids.member), {
      displayName: 'New Name',
    });
    await assertSucceeds(batch.commit());

    const ownerBefore = (await getDoc(
      doc(db(ids.owner), 'gubs', 'g1', 'members', ids.owner),
    )).data();
    const renamed = (await getDoc(
      doc(clientDb, 'gubs', 'g1', 'members', ids.member),
    )).data();
    assert.equal(renamed.displayName, 'New Name');
    assert.equal(renamed.role, 'member');
    assert.equal(ownerBefore.displayName, ids.owner);
    assert.equal(ownerBefore.role, 'owner');

    await assertSucceeds(setDoc(
      doc(clientDb, 'gubs', 'g1', 'messages', 'after-rename'),
      {
        messageId: 'after-rename', gubId: 'g1', senderId: ids.member,
        senderName: 'New Name', text: 'Message', createdAt: now(),
      },
    ));
    await assertSucceeds(setDoc(
      doc(clientDb, 'gubs', 'g1', 'tasks', 'after-rename'),
      {
        gubId: 'g1', taskId: 'after-rename', title: 'Task', description: '',
        creatorId: ids.member, creatorName: 'New Name',
        assignedUserId: ids.member, assignedUserName: 'New Name',
        sourceType: 'manual', sourceId: null, sourcePreview: null,
        originUserId: null, sourceAuthorName: null, additionalDetails: null,
        status: 'active', priority: 'normal', createdAt: now(), dueDate: null,
        completedAt: null, completedBy: null, notificationsEnabled: true,
        archived: false,
      },
    ));
  });

  test('Community rename keeps membership coherent and chat authorized', async () => {
    await seedCommunityMembership();
    const clientDb = db(ids.communityMember);
    const batch = writeBatch(clientDb);
    batch.update(doc(clientDb, 'users', ids.communityMember), {
      displayName: 'Community New Name',
      displayNameChangedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    batch.update(
      doc(clientDb, 'communities', 'c1', 'members', ids.communityMember),
      { displayName: 'Community New Name' },
    );
    await assertSucceeds(batch.commit());

    await assertSucceeds(setDoc(
      doc(clientDb, 'communities', 'c1', 'messages', 'after-rename'),
      {
        messageId: 'after-rename', communityId: 'c1',
        senderId: ids.communityMember, senderName: 'Community New Name',
        text: 'Message', createdAt: serverTimestamp(),
      },
    ));
    const owner = (await getDoc(
      doc(db(ids.communityOwner), 'communities', 'c1', 'members', ids.communityOwner),
    )).data();
    assert.equal(owner.displayName, ids.communityOwner);
    assert.equal(owner.role, 'owner');
  });

  test('membership-only repair uses canonical name without resetting cooldown', async () => {
    await seedPrivateMembership();
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'users', ids.member), {
        displayName: 'Already Canonical',
        displayNameChangedAt: new Date(),
      });
    });
    await assertSucceeds(updateDoc(
      doc(db(ids.member), 'gubs', 'g1', 'members', ids.member),
      { displayName: 'Already Canonical' },
    ));
    const profileData = (await getDoc(doc(db(ids.member), 'users', ids.member))).data();
    assert.equal(profileData.displayName, 'Already Canonical');
    assert.ok(profileData.displayNameChangedAt);
  });

  test('a user cannot rename another current membership', async () => {
    await seedPrivateMembership();
    await assertFails(updateDoc(
      doc(db(ids.owner), 'gubs', 'g1', 'members', ids.member),
      { displayName: 'Forged' },
    ));
  });

  test('owner rename preserves Private Gub and Community ownership', async () => {
    await seedGub();
    await seedCommunityMembership();

    const privateDb = db(ids.owner);
    const privateBatch = writeBatch(privateDb);
    privateBatch.update(doc(privateDb, 'users', ids.owner), {
      displayName: 'Private Owner New',
      displayNameChangedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    privateBatch.update(doc(privateDb, 'gubs', 'g1', 'members', ids.owner), {
      displayName: 'Private Owner New',
    });
    await assertSucceeds(privateBatch.commit());

    const communityDb = db(ids.communityOwner);
    const communityBatch = writeBatch(communityDb);
    communityBatch.update(doc(communityDb, 'users', ids.communityOwner), {
      displayName: 'Community Owner New',
      displayNameChangedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    communityBatch.update(
      doc(communityDb, 'communities', 'c1', 'members', ids.communityOwner),
      { displayName: 'Community Owner New' },
    );
    await assertSucceeds(communityBatch.commit());

    const privateRoot = (await getDoc(doc(privateDb, 'gubs', 'g1'))).data();
    const privateOwner = (await getDoc(
      doc(privateDb, 'gubs', 'g1', 'members', ids.owner),
    )).data();
    const communityRoot = (await getDoc(
      doc(communityDb, 'communities', 'c1'),
    )).data();
    const communityOwner = (await getDoc(
      doc(communityDb, 'communities', 'c1', 'members', ids.communityOwner),
    )).data();
    assert.equal(privateRoot.ownerId, ids.owner);
    assert.equal(privateOwner.role, 'owner');
    assert.equal(communityRoot.ownerId, ids.communityOwner);
    assert.equal(communityOwner.role, 'owner');
  });
});

describe('Phase F account self-cleanup permissions', () => {
  test('a user may delete only their own profile', async () => {
    await assertSucceeds(deleteDoc(doc(db(ids.member), 'users', ids.member)));
    await assertFails(deleteDoc(doc(db(ids.outsider), 'users', ids.member)));
  });

  test('a current member may remove only their own private read state', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const admin = context.firestore();
      await setDoc(doc(admin, 'gubs', 'g1'), root({ memberCount: 2 }));
      await setDoc(doc(admin, 'gubs', 'g1', 'members', ids.member), member(ids.member));
      await setDoc(doc(admin, 'gubs', 'g1', 'chatReads', ids.member), {
        userId: ids.member,
        gubId: 'g1',
        lastReadAt: now(),
      });
      await setDoc(doc(admin, 'gubs', 'g1', 'boardReads', ids.member), {
        lastReadAt: now(),
      });
    });

    await assertFails(
      deleteDoc(doc(db(ids.outsider), 'gubs', 'g1', 'chatReads', ids.member)),
    );
    await assertSucceeds(
      deleteDoc(doc(db(ids.member), 'gubs', 'g1', 'chatReads', ids.member)),
    );
    await assertSucceeds(
      deleteDoc(doc(db(ids.member), 'gubs', 'g1', 'boardReads', ids.member)),
    );
  });

  test('a resolved Community request remains historical account data', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const admin = context.firestore();
      await setDoc(doc(admin, 'communities', 'c1'), {
        communityId: 'c1',
        name: 'Community',
        ownerId: ids.communityOwner,
        memberCount: 2,
        visibility: 'public',
        accessMode: 'approval',
        status: 'active',
        createdAt: now(),
      });
      await setDoc(
        doc(admin, 'communities', 'c1', 'members', ids.communityMember),
        member(ids.communityMember),
      );
      await setDoc(
        doc(admin, 'communities', 'c1', 'joinRequests', ids.communityMember),
        {
          userId: ids.communityMember,
          displayName: ids.communityMember,
          status: 'approved',
          createdAt: now(),
          resolvedAt: now(),
          resolvedBy: ids.communityOwner,
        },
      );
    });

    await assertFails(
      deleteDoc(
        doc(
          db(ids.outsider),
          'communities',
          'c1',
          'joinRequests',
          ids.communityMember,
        ),
      ),
    );
    await assertFails(
      deleteDoc(
        doc(
          db(ids.communityMember),
          'communities',
          'c1',
          'joinRequests',
          ids.communityMember,
        ),
      ),
    );
  });
});

describe('Phase F irreversible shared identity anonymization', () => {
  async function seedIdentityDocuments() {
    await seedGub();
    await env.withSecurityRulesDisabled(async (context) => {
      const seedDb = context.firestore();
      await setDoc(doc(seedDb, 'gubs', 'g1', 'members', ids.member), member(ids.member));
      await setDoc(doc(seedDb, 'users', ids.member, 'gubs', 'g1'), copy(ids.member));
      await setDoc(doc(seedDb, 'gubs', 'g1', 'messages', 'm1'), {
        messageId: 'm1', gubId: 'g1', senderId: ids.member,
        senderName: 'Original Name', text: 'Shared content', createdAt: now(),
      });
      await setDoc(doc(seedDb, 'gubs', 'g1', 'tasks', 't1'), {
        gubId: 'g1', taskId: 't1', title: 'Keep title', description: 'Keep description',
        creatorId: ids.member, creatorName: 'Original Name', assignedUserId: ids.second,
        assignedUserName: ids.second, sourceType: 'manual', sourceId: null,
        sourcePreview: null, originUserId: null, sourceAuthorName: null,
        additionalDetails: null, status: 'active', priority: 'normal', createdAt: now(),
        dueDate: null, completedAt: null, completedBy: null,
        notificationsEnabled: true, archived: false,
      });
    });
  }

  test('user anonymizes only their own message identity with exact sentinel', async () => {
    await seedIdentityDocuments();
    const reference = doc(db(ids.member), 'gubs', 'g1', 'messages', 'm1');
    await assertSucceeds(updateDoc(reference, {
      senderId: '__deleted_user__', senderName: 'Deleted user',
    }));
    const data = (await getDoc(reference)).data();
    assert.equal(data.text, 'Shared content');
    assert.equal(data.senderId, '__deleted_user__');
    assert.equal(data.senderName, 'Deleted user');
  });

  test('anonymization cannot alter shared message content', async () => {
    await seedIdentityDocuments();
    await assertFails(updateDoc(doc(db(ids.member), 'gubs', 'g1', 'messages', 'm1'), {
      senderId: '__deleted_user__', senderName: 'Deleted user', text: 'Changed',
    }));
  });

  test('sentinel and visible name must be exact', async () => {
    await seedIdentityDocuments();
    const reference = doc(db(ids.member), 'gubs', 'g1', 'messages', 'm1');
    await assertFails(updateDoc(reference, { senderId: 'deleted_member', senderName: 'Deleted user' }));
    await assertFails(updateDoc(reference, { senderId: '__deleted_user__', senderName: 'Someone' }));
    await assertFails(updateDoc(reference, { senderId: ids.second, senderName: ids.second }));
  });

  test('another member and outsider cannot anonymize the author', async () => {
    await seedIdentityDocuments();
    const update = { senderId: '__deleted_user__', senderName: 'Deleted user' };
    await assertFails(updateDoc(doc(db(ids.second), 'gubs', 'g1', 'messages', 'm1'), update));
    await assertFails(updateDoc(doc(db(ids.outsider), 'gubs', 'g1', 'messages', 'm1'), update));
  });

  test('task identity can change without changing content or status', async () => {
    await seedIdentityDocuments();
    const reference = doc(db(ids.member), 'gubs', 'g1', 'tasks', 't1');
    await assertSucceeds(updateDoc(reference, {
      creatorId: '__deleted_user__', creatorName: 'Deleted user',
    }));
    const data = (await getDoc(reference)).data();
    assert.equal(data.title, 'Keep title');
    assert.equal(data.description, 'Keep description');
    assert.equal(data.status, 'active');
    assert.equal(data.assignedUserId, ids.second);
    assert.equal(data.assignedUserName, ids.second);
    await assertFails(updateDoc(reference, { status: 'completed' }));
  });

  test('mixed-user resources preserve every surviving identity', async () => {
    await seedIdentityDocuments();
    await env.withSecurityRulesDisabled(async (context) => {
      const seedDb = context.firestore();
      await setDoc(doc(seedDb, 'gubs', 'g1', 'organizedEvents', 'e1'), {
        eventId: 'e1', gubId: 'g1', title: 'Event', createdBy: ids.member,
        createdByName: 'Original Name', originUserId: null,
        sourceAuthorName: null, assignments: [{
          userId: ids.second, userName: 'Surviving User', taskText: 'Keep task',
          isCompleted: false, completedAt: null,
        }], status: 'active', createdAt: now(),
      });
      await setDoc(doc(seedDb, 'gubs', 'g1', 'goals', 'goal1'), {
        goalId: 'goal1', gubId: 'g1', title: 'Budget', ownerId: ids.second,
        originUserId: ids.member, sourceAuthorName: 'Original Name',
        status: 'active', archived: false, createdAt: now(),
      });
    });

    const eventReference = doc(db(ids.member), 'gubs', 'g1', 'organizedEvents', 'e1');
    await assertSucceeds(updateDoc(eventReference, {
      createdBy: '__deleted_user__', createdByName: 'Deleted user',
    }));
    const event = (await getDoc(eventReference)).data();
    assert.deepEqual(event.assignments, [{
      userId: ids.second, userName: 'Surviving User', taskText: 'Keep task',
      isCompleted: false, completedAt: null,
    }]);

    const budgetReference = doc(db(ids.member), 'gubs', 'g1', 'goals', 'goal1');
    await assertSucceeds(updateDoc(budgetReference, {
      originUserId: '__deleted_user__', sourceAuthorName: 'Deleted user',
    }));
    const budget = (await getDoc(budgetReference)).data();
    assert.equal(budget.ownerId, ids.second);
    assert.equal(budget.title, 'Budget');
  });

  test('deleting user anonymizes only their organized event assignments', async () => {
    await seedIdentityDocuments();
    await env.withSecurityRulesDisabled(async (context) => {
      const seedDb = context.firestore();
      await setDoc(doc(seedDb, 'gubs', 'g1', 'members', ids.second), member(ids.second));
      await setDoc(doc(seedDb, 'users', ids.second, 'gubs', 'g1'), copy(ids.second));
      await setDoc(doc(seedDb, 'gubs', 'g1', 'organizedEvents', 'assignment-event'), {
        eventId: 'assignment-event', gubId: 'g1', title: 'Keep event',
        description: 'Keep details', createdBy: ids.second,
        createdByName: 'Surviving User', originUserId: null,
        sourceAuthorName: null, assignments: [
          {
            userId: ids.member, userName: 'Deleting User', taskText: 'Keep task',
            isCompleted: true, completedAt: now(),
          },
          {
            userId: ids.second, userName: 'Surviving User', taskText: 'Keep other task',
            isCompleted: false, completedAt: null,
          },
        ], status: 'active', createdAt: now(),
      });
    });

    const reference = doc(
      db(ids.member), 'gubs', 'g1', 'organizedEvents', 'assignment-event',
    );
    await assertSucceeds(updateDoc(reference, {
      assignments: [
        {
          userId: '__deleted_user__', userName: 'Deleted user', taskText: 'Keep task',
          isCompleted: true, completedAt: now(),
        },
        {
          userId: ids.second, userName: 'Surviving User', taskText: 'Keep other task',
          isCompleted: false, completedAt: null,
        },
      ],
    }));
    const event = (await getDoc(reference)).data();
    assert.equal(event.title, 'Keep event');
    assert.equal(event.description, 'Keep details');
    assert.equal(event.createdBy, ids.second);
    assert.equal(event.assignments[0].userId, '__deleted_user__');
    assert.equal(event.assignments[0].userName, 'Deleted user');
    assert.equal(event.assignments[0].taskText, 'Keep task');
    assert.equal(event.assignments[1].userId, ids.second);
    assert.equal(event.assignments[1].userName, 'Surviving User');
  });

  test('organized event assignment anonymization cannot target another user', async () => {
    await seedIdentityDocuments();
    await env.withSecurityRulesDisabled(async (context) => {
      const seedDb = context.firestore();
      await setDoc(doc(seedDb, 'gubs', 'g1', 'members', ids.second), member(ids.second));
      await setDoc(doc(seedDb, 'users', ids.second, 'gubs', 'g1'), copy(ids.second));
      await setDoc(doc(seedDb, 'gubs', 'g1', 'organizedEvents', 'other-assignment'), {
        eventId: 'other-assignment', gubId: 'g1', title: 'Event',
        createdBy: ids.owner, createdByName: ids.owner, originUserId: null,
        sourceAuthorName: null, assignments: [{
          userId: ids.second, userName: 'Surviving User', taskText: 'Keep task',
          isCompleted: false, completedAt: null,
        }], status: 'active', createdAt: now(),
      });
    });

    await assertFails(updateDoc(
      doc(db(ids.member), 'gubs', 'g1', 'organizedEvents', 'other-assignment'),
      { assignments: [{
        userId: '__deleted_user__', userName: 'Deleted user', taskText: 'Keep task',
        isCompleted: false, completedAt: null,
      }] },
    ));
  });

  test('organized assignment cleanup cannot rewrite retained assignment data', async () => {
    await seedIdentityDocuments();
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'gubs', 'g1', 'organizedEvents', 'protected-assignment'),
        {
          eventId: 'protected-assignment', gubId: 'g1', title: 'Event',
          createdBy: ids.owner, createdByName: ids.owner, originUserId: null,
          sourceAuthorName: null, assignments: [{
            userId: ids.member, userName: 'Deleting User', taskText: 'Original task',
            isCompleted: false, completedAt: null,
          }], status: 'active', createdAt: now(),
        },
      );
    });

    await assertFails(updateDoc(
      doc(db(ids.member), 'gubs', 'g1', 'organizedEvents', 'protected-assignment'),
      { assignments: [{
        userId: '__deleted_user__', userName: 'Deleted user', taskText: 'Changed task',
        isCompleted: false, completedAt: null,
      }] },
    ));
  });

  test('deleting member cannot delete owner profile and owner keeps normal writes', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const seedDb = context.firestore();
      await setDoc(doc(seedDb, 'gubs', 'g1'), root({
        ownerId: ids.second, memberCount: 2,
      }));
      await setDoc(
        doc(seedDb, 'gubs', 'g1', 'members', ids.second),
        member(ids.second, 'owner', { displayName: 'Surviving User' }),
      );
      await setDoc(
        doc(seedDb, 'gubs', 'g1', 'members', ids.member),
        member(ids.member, 'member', { displayName: 'Deleting User' }),
      );
      await setDoc(doc(seedDb, 'users', ids.member, 'gubs', 'g1'), copy(ids.member, 'member', {
        ownerId: ids.second,
      }));
      await updateDoc(doc(seedDb, 'users', ids.second), {
        displayName: 'Surviving User',
      });
    });

    await assertFails(deleteDoc(doc(db(ids.member), 'users', ids.second)));
    await assertSucceeds(deleteDoc(doc(db(ids.member), 'users', ids.member)));

    const leavingDb = db(ids.member);
    await assertSucceeds(runTransaction(leavingDb, async (transaction) => {
      transaction.update(doc(leavingDb, 'gubs', 'g1'), { memberCount: 1 });
      transaction.delete(doc(leavingDb, 'gubs', 'g1', 'members', ids.member));
      transaction.delete(doc(leavingDb, 'users', ids.member, 'gubs', 'g1'));
    }));

    const ownerProfile = await getDoc(doc(db(ids.second), 'users', ids.second));
    const ownerMembership = await getDoc(
      doc(db(ids.second), 'gubs', 'g1', 'members', ids.second),
    );
    const gub = await getDoc(doc(db(ids.second), 'gubs', 'g1'));
    assert.equal(ownerProfile.data().displayName, 'Surviving User');
    assert.equal(ownerMembership.data().displayName, 'Surviving User');
    assert.equal(ownerMembership.data().role, 'owner');
    assert.equal(gub.data().ownerId, ids.second);
    assert.equal(gub.data().memberCount, 1);

    await assertSucceeds(setDoc(
      doc(db(ids.second), 'gubs', 'g1', 'messages', 'surviving-message'),
      {
        messageId: 'surviving-message', gubId: 'g1', senderId: ids.second,
        senderName: 'Surviving User', text: 'Still allowed', createdAt: now(),
      },
    ));
    await assertSucceeds(setDoc(
      doc(db(ids.second), 'gubs', 'g1', 'tasks', 'surviving-task'),
      {
        gubId: 'g1', taskId: 'surviving-task', title: 'Still works',
        description: '', creatorId: ids.second, creatorName: 'Surviving User',
        assignedUserId: ids.second, assignedUserName: 'Surviving User',
        sourceType: 'manual', sourceId: null, sourcePreview: null,
        originUserId: null, sourceAuthorName: null, additionalDetails: null,
        status: 'active', priority: 'normal', createdAt: now(), dueDate: null,
        completedAt: null, completedBy: null, notificationsEnabled: true,
        archived: false,
      },
    ));
  });

  test('production Private Chat anonymization query proves joinedAt boundary', async () => {
    await seedIdentityDocuments();
    const productionQuery = query(
      collection(db(ids.member), 'gubs', 'g1', 'messages'),
      where('senderId', '==', ids.member),
      where('createdAt', '>=', now()),
    );
    const snapshot = await assertSucceeds(getDocs(productionQuery));
    assert.equal(snapshot.size, 1);

    const unbounded = query(
      collection(db(ids.member), 'gubs', 'g1', 'messages'),
      where('senderId', '==', ids.member),
    );
    await assertFails(getDocs(unbounded));
    await assertFails(getDocs(query(
      collection(db(ids.outsider), 'gubs', 'g1', 'messages'),
      where('senderId', '==', ids.member),
      where('createdAt', '>=', now()),
    )));
  });

  test('production Community Chat anonymization query preserves boundary', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const seedDb = context.firestore();
      await setDoc(doc(seedDb, 'communities', 'c1'), {
        communityId: 'c1', name: 'Community', ownerId: ids.communityOwner,
        visibility: 'public', accessMode: 'open', memberCount: 2, createdAt: now(),
      });
      await setDoc(doc(seedDb, 'communities', 'c1', 'members', ids.communityMember),
        member(ids.communityMember));
      await setDoc(doc(seedDb, 'communities', 'c1', 'messages', 'm1'), {
        messageId: 'm1', communityId: 'c1', senderId: ids.communityMember,
        senderName: 'Original Name', text: 'Community content', createdAt: now(),
      });
    });
    const productionQuery = query(
      collection(db(ids.communityMember), 'communities', 'c1', 'messages'),
      where('senderId', '==', ids.communityMember),
      where('createdAt', '>=', now()),
    );
    const snapshot = await assertSucceeds(getDocs(productionQuery));
    assert.equal(snapshot.size, 1);
    await assertFails(getDocs(query(
      collection(db(ids.communityMember), 'communities', 'c1', 'messages'),
      where('senderId', '==', ids.communityMember),
    )));
  });

  test('notification removes only deleted identity and own read state', async () => {
    await seedIdentityDocuments();
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'gubs', 'g1', 'notifications', 'n1'), {
        notificationId: 'n1', title: 'New task',
        body: 'Original Name assigned a new task: Keep title', type: 'task_created',
        senderId: ids.member, senderName: 'Original Name', createdAt: now(),
        readBy: [ids.member, ids.second],
        data: { module: 'tasks', gubId: 'g1', taskId: 't1' },
      });
    });
    const reference = doc(db(ids.member), 'gubs', 'g1', 'notifications', 'n1');
    await assertSucceeds(updateDoc(reference, {
      senderId: '__deleted_user__', senderName: 'Deleted user',
      body: 'Deleted user assigned a new task: Keep title', readBy: [ids.second],
    }));
    const data = (await getDoc(reference)).data();
    assert.equal(data.title, 'New task');
    assert.equal(data.type, 'task_created');
    assert.deepEqual(data.data, { module: 'tasks', gubId: 'g1', taskId: 't1' });
    assert.deepEqual(data.readBy, [ids.second]);
  });

  test('notification anonymization cannot change content or another read state', async () => {
    await seedIdentityDocuments();
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'gubs', 'g1', 'notifications', 'n1'), {
        notificationId: 'n1', title: 'New task',
        body: 'Original Name assigned a new task: Keep title', type: 'task_created',
        senderId: ids.member, senderName: 'Original Name', createdAt: now(),
        readBy: [ids.member, ids.second],
        data: { module: 'tasks', gubId: 'g1', taskId: 't1' },
      });
    });
    const reference = doc(db(ids.member), 'gubs', 'g1', 'notifications', 'n1');
    await assertFails(updateDoc(reference, {
      senderId: '__deleted_user__', senderName: 'Deleted user',
      body: 'Deleted user assigned a new task: Changed title', readBy: [],
    }));
    await assertFails(updateDoc(doc(db(ids.second), 'gubs', 'g1', 'notifications', 'n1'), {
      senderId: '__deleted_user__', senderName: 'Deleted user',
      body: 'Deleted user assigned a new task: Keep title',
    }));
  });

  test('notification identity can be anonymized when readBy is absent or unrelated', async () => {
    await seedIdentityDocuments();
    await env.withSecurityRulesDisabled(async (context) => {
      const seedDb = context.firestore();
      for (const [notificationId, readBy] of [
        ['absent', undefined],
        ['empty', []],
        ['other-reader', [ids.second]],
      ]) {
        const notification = {
          notificationId, title: 'New proposal',
          body: 'Original Name created a new proposal.', type: 'proposal_created',
          senderId: ids.member, senderName: 'Original Name', createdAt: now(),
          data: { module: 'proposals', gubId: 'g1', proposalId: 'p1' },
        };
        if (readBy !== undefined) notification.readBy = readBy;
        await setDoc(
          doc(seedDb, 'gubs', 'g1', 'notifications', notificationId),
          notification,
        );
      }
    });

    for (const notificationId of ['absent', 'empty', 'other-reader']) {
      await assertSucceeds(updateDoc(
        doc(db(ids.member), 'gubs', 'g1', 'notifications', notificationId),
        {
          senderId: '__deleted_user__', senderName: 'Deleted user',
          body: 'Deleted user created a new proposal.',
        },
      ));
    }
  });

  test('notification read state cleanup is idempotent and preserves other readers', async () => {
    await seedIdentityDocuments();
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'gubs', 'g1', 'notifications', 'n1'), {
        notificationId: 'n1', title: 'Task completed',
        body: 'Keep title has been completed.', type: 'task_completed',
        senderId: ids.second, senderName: ids.second, createdAt: now(),
        readBy: [ids.member, ids.second],
        data: { module: 'tasks', gubId: 'g1', taskId: 't1' },
      });
    });
    const reference = doc(db(ids.member), 'gubs', 'g1', 'notifications', 'n1');
    await assertSucceeds(updateDoc(reference, { readBy: [ids.second] }));
    const data = (await getDoc(reference)).data();
    assert.deepEqual(data.readBy, [ids.second]);
    assert.equal(data.senderId, ids.second);
    assert.equal(data.body, 'Keep title has been completed.');
  });
});

describe('Delete Account canonical membership discovery', () => {
  test('user can discover canonical private and Community memberships without copies', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const seedDb = context.firestore();
      await setDoc(doc(seedDb, 'gubs', 'canonical-gub'), root({
        gubId: 'canonical-gub', memberCount: 2,
      }));
      await setDoc(
        doc(seedDb, 'gubs', 'canonical-gub', 'members', ids.member),
        member(ids.member),
      );
      await setDoc(doc(seedDb, 'communities', 'canonical-community'), {
        communityId: 'canonical-community', name: 'Community',
        ownerId: ids.communityOwner, memberCount: 2, visibility: 'public',
        accessMode: 'open', status: 'active', createdAt: now(),
      });
      await setDoc(
        doc(seedDb, 'communities', 'canonical-community', 'members', ids.member),
        member(ids.member),
      );
    });

    const result = await assertSucceeds(getDocs(query(
      collectionGroup(db(ids.member), 'members'),
      where('uid', '==', ids.member),
    )));
    const paths = result.docs.map((document) => document.ref.path).sort();
    assert.deepEqual(paths, [
      `communities/canonical-community/members/${ids.member}`,
      `gubs/canonical-gub/members/${ids.member}`,
    ]);
  });

  test('membership discovery cannot list another user or all memberships', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'gubs', 'g1', 'members', ids.second),
        member(ids.second),
      );
    });

    await assertFails(getDocs(query(
      collectionGroup(db(ids.member), 'members'),
      where('uid', '==', ids.second),
    )));
    await assertFails(getDocs(collectionGroup(db(ids.member), 'members')));
  });
});
