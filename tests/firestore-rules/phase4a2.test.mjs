import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
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
    batch.set(doc(clientDb, 'communities', 'c1'), { communityId: 'c1', name: 'Community', ownerId: ids.communityOwner, memberCount: 1, visibility: 'public', createdAt: serverTimestamp(), type: 'General', language: 'English', description: '', accessMode: 'open' });
    batch.set(doc(clientDb, 'communities', 'c1', 'members', ids.communityOwner), { uid: ids.communityOwner, displayName: ids.communityOwner, photoUrl: null, role: 'owner', joinedAt: serverTimestamp() });
    batch.set(doc(clientDb, 'users', ids.communityOwner, 'communities', 'c1'), { communityId: 'c1', name: 'Community', ownerId: ids.communityOwner, memberCount: 1, visibility: 'public', role: 'owner', joinedAt: serverTimestamp() });
    batch.set(doc(clientDb, 'communityOwnership', ids.communityOwner), { ownerId: ids.communityOwner, communityId: 'c1', createdAt: serverTimestamp() });
    await assertSucceeds(batch.commit());
  });
});
