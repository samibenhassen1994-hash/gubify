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
const ids = {
  ownerGub: 'ownerGub',
  memberGub: 'memberGub',
  secondMember: 'secondMember',
  outsider: 'outsider',
  ownerCommunity: 'ownerCommunity',
  memberCommunity: 'memberCommunity',
  communityOutsider: 'communityOutsider',
};

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
const anonymousDb = () => env.unauthenticatedContext().firestore();
const inviteTokenId = 'TES3A2Q7';

const profile = (uid) => ({
  displayName: uid,
  createdAt: new Date('2026-01-01T00:00:00Z'),
  updatedAt: new Date('2026-01-01T00:00:00Z'),
  activeHub: null,
  avatar: null,
});
const gubRoot = (id = 'g1', ownerId = ids.ownerGub, overrides = {}) => ({
  gubId: id,
  name: 'Test Gub',
  ownerId,
  inviteTokenId,
  memberCount: 1,
  createdAt: new Date('2026-01-01T00:00:00Z'),
  ...overrides,
});
const gubMember = (uid, role = 'member', overrides = {}) => ({
  uid,
  displayName: uid,
  photoUrl: null,
  role,
  joinedAt: new Date('2026-01-01T00:00:00Z'),
  ...overrides,
});
const gubCopy = (id, uid, role = 'member', overrides = {}) => ({
  gubId: id,
  name: 'Test Gub',
  ownerId: ids.ownerGub,
  role,
  joinedAt: new Date('2026-01-01T00:00:00Z'),
  ...overrides,
});
const inviteToken = (id = 'g1', ownerId = ids.ownerGub, overrides = {}) => ({
  gubId: id,
  ownerId,
  gubName: 'Test Gub',
  active: true,
  createdAt: new Date('2026-01-01T00:00:00Z'),
  ...overrides,
});
const communityRoot = (
  id = 'c1',
  ownerId = ids.ownerCommunity,
  overrides = {},
) => ({
  communityId: id,
  name: 'Test Community',
  ownerId,
  memberCount: 1,
  visibility: 'public',
  createdAt: new Date('2026-01-01T00:00:00Z'),
  type: 'General',
  language: 'English',
  description: '',
  accessMode: 'open',
  ...overrides,
});
const communityCopy = (id, uid, role = 'member', overrides = {}) => ({
  communityId: id,
  name: 'Test Community',
  ownerId: ids.ownerCommunity,
  memberCount: role === 'owner' ? 1 : 2,
  visibility: 'public',
  role,
  joinedAt: new Date('2026-01-01T00:00:00Z'),
  ...overrides,
});
const gubMessage = (messageId, uid, overrides = {}) => ({
  messageId,
  gubId: 'g1',
  senderId: uid,
  senderName: uid,
  text: 'Hello from chat',
  createdAt: serverTimestamp(),
  ...overrides,
});
const communityMessage = (messageId, uid, overrides = {}) => ({
  messageId,
  communityId: 'c1',
  senderId: uid,
  senderName: uid,
  text: 'Hello Community',
  createdAt: serverTimestamp(),
  ...overrides,
});
const boardPost = (uid, overrides = {}) => ({
  gubId: 'g1',
  authorId: uid,
  authorName: uid,
  authorPhoto: null,
  message: 'Board message',
  likes: 0,
  comments: 0,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...overrides,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});
after(async () => env.cleanup());
beforeEach(async () => env.clearFirestore());

async function seedProfiles(uids = Object.values(ids)) {
  await env.withSecurityRulesDisabled(async (context) => {
    const seedDb = context.firestore();
    const batch = writeBatch(seedDb);
    for (const uid of uids) batch.set(doc(seedDb, 'users', uid), profile(uid));
    await batch.commit();
  });
}

async function seedGub({
  id = 'g1',
  status = 'active',
  members = [ids.ownerGub, ids.memberGub, ids.secondMember],
} = {}) {
  await env.withSecurityRulesDisabled(async (context) => {
    const seedDb = context.firestore();
    const batch = writeBatch(seedDb);
    batch.set(
      doc(seedDb, 'gubs', id),
      gubRoot(id, ids.ownerGub, {
        memberCount: members.length,
        ...(status === 'deleting'
          ? {
              deletionStatus: 'deleting',
              deletionRequestedBy: ids.ownerGub,
              deletionStartedAt: new Date('2026-01-02T00:00:00Z'),
              deletionUpdatedAt: new Date('2026-01-02T00:00:00Z'),
              deletionPhase: 'preparing',
            }
          : {}),
      }),
    );
    batch.set(
      doc(seedDb, 'inviteTokens', inviteTokenId),
      inviteToken(id, ids.ownerGub, { active: status != 'deleting' }),
    );
    for (const uid of members) {
      const role = uid === ids.ownerGub ? 'owner' : 'member';
      batch.set(doc(seedDb, 'gubs', id, 'members', uid), gubMember(uid, role));
      batch.set(
        doc(seedDb, 'users', uid, 'gubs', id),
        gubCopy(id, uid, role),
      );
    }
    await batch.commit();
  });
}

async function seedCommunity({
  id = 'c1',
  visibility = 'public',
  status = 'active',
  members = [ids.ownerCommunity, ids.memberCommunity],
} = {}) {
  await env.withSecurityRulesDisabled(async (context) => {
    const seedDb = context.firestore();
    const batch = writeBatch(seedDb);
    batch.set(
      doc(seedDb, 'communities', id),
      communityRoot(id, ids.ownerCommunity, {
        memberCount: members.length,
        visibility,
        ...(status === 'deleting'
          ? {
              deletionStatus: 'deleting',
              deletionRequestedBy: ids.ownerCommunity,
              deletionStartedBy: ids.ownerCommunity,
              deletionStartedAt: new Date('2026-01-02T00:00:00Z'),
            }
          : {}),
      }),
    );
    for (const uid of members) {
      const role = uid === ids.ownerCommunity ? 'owner' : 'member';
      batch.set(
        doc(seedDb, 'communities', id, 'members', uid),
        gubMember(uid, role),
      );
      batch.set(
        doc(seedDb, 'users', uid, 'communities', id),
        communityCopy(id, uid, role, {
          memberCount: members.length,
          visibility,
        }),
      );
    }
    batch.set(doc(seedDb, 'communityOwnership', ids.ownerCommunity), {
      ownerId: ids.ownerCommunity,
      communityId: id,
      createdAt: new Date('2026-01-01T00:00:00Z'),
    });
    await batch.commit();
  });
}

function createGubBatch({
  actor = ids.ownerGub,
  id = 'new-gub',
  ownerId = actor,
  rootOverrides = {},
  tokenOverrides = {},
  memberUid = actor,
  memberOverrides = {},
  copyUid = actor,
  copyOverrides = {},
  includeRoot = true,
  includeMember = true,
  includeCopy = true,
  includeToken = true,
  extraWrite = false,
} = {}) {
  const clientDb = db(actor);
  const batch = writeBatch(clientDb);
  const rootData = gubRoot(id, ownerId, rootOverrides);
  if (includeToken) {
    batch.set(
      doc(clientDb, 'inviteTokens', rootData.inviteTokenId),
      inviteToken(id, ownerId, {
        gubName: rootData.name,
        createdAt: serverTimestamp(),
        ...tokenOverrides,
      }),
    );
  }
  if (includeRoot) batch.set(doc(clientDb, 'gubs', id), rootData);
  if (includeMember) {
    batch.set(
      doc(clientDb, 'gubs', id, 'members', memberUid),
      gubMember(memberUid, 'owner', memberOverrides),
    );
  }
  if (includeCopy) {
    batch.set(
      doc(clientDb, 'users', copyUid, 'gubs', id),
      gubCopy(id, copyUid, 'owner', {
        ownerId,
        name: rootData.name,
        ...copyOverrides,
      }),
    );
  }
  if (extraWrite) batch.set(doc(clientDb, 'gubs', id, 'unknown', 'x'), { ok: true });
  return batch.commit();
}

function joinGubBatch({
  actor = ids.outsider,
  id = 'g1',
  increment = 1,
  rootUpdates = {},
  memberUid = actor,
  memberRole = 'member',
  memberOverrides = {},
  copyUid = actor,
  copyOverrides = {},
  includeRoot = true,
  includeMember = true,
  includeCopy = true,
} = {}) {
  const clientDb = db(actor);
  const batch = writeBatch(clientDb);
  if (includeRoot) {
    batch.update(doc(clientDb, 'gubs', id), {
      memberCount: 3 + increment,
      ...rootUpdates,
    });
  }
  if (includeMember) {
    batch.set(
      doc(clientDb, 'gubs', id, 'members', memberUid),
      gubMember(memberUid, memberRole, {
        joinedViaInviteToken: inviteTokenId,
        ...memberOverrides,
      }),
    );
  }
  if (includeCopy) {
    batch.set(
      doc(clientDb, 'users', copyUid, 'gubs', id),
      gubCopy(id, copyUid, memberRole, copyOverrides),
    );
  }
  return batch.commit();
}

function createCommunityBatch({
  actor = ids.ownerCommunity,
  id = 'new-community',
  ownerId = actor,
  rootOverrides = {},
  memberUid = actor,
  memberOverrides = {},
  copyUid = actor,
  copyOverrides = {},
  markerUid = actor,
  markerOverrides = {},
  includeMember = true,
  includeCopy = true,
  includeMarker = true,
} = {}) {
  const clientDb = db(actor);
  const batch = writeBatch(clientDb);
  const rootData = communityRoot(id, ownerId, {
    createdAt: serverTimestamp(),
    ...rootOverrides,
  });
  batch.set(doc(clientDb, 'communities', id), rootData);
  if (includeMember) {
    batch.set(
      doc(clientDb, 'communities', id, 'members', memberUid),
      gubMember(memberUid, 'owner', {
        joinedAt: serverTimestamp(),
        ...memberOverrides,
      }),
    );
  }
  if (includeCopy) {
    batch.set(
      doc(clientDb, 'users', copyUid, 'communities', id),
      communityCopy(id, copyUid, 'owner', {
        ownerId,
        name: rootData.name,
        joinedAt: serverTimestamp(),
        ...copyOverrides,
      }),
    );
  }
  if (includeMarker) {
    batch.set(doc(clientDb, 'communityOwnership', markerUid), {
      ownerId: actor,
      communityId: id,
      createdAt: serverTimestamp(),
      ...markerOverrides,
    });
  }
  return batch.commit();
}

function joinCommunityBatch({
  actor = ids.communityOutsider,
  id = 'c1',
  increment = 1,
  memberUid = actor,
  memberRole = 'member',
  copyUid = actor,
  copyOverrides = {},
  includeRoot = true,
  includeMember = true,
  includeCopy = true,
} = {}) {
  const clientDb = db(actor);
  const batch = writeBatch(clientDb);
  if (includeRoot) {
    batch.update(doc(clientDb, 'communities', id), { memberCount: 2 + increment });
  }
  if (includeMember) {
    batch.set(
      doc(clientDb, 'communities', id, 'members', memberUid),
      gubMember(memberUid, memberRole, { joinedAt: serverTimestamp() }),
    );
  }
  if (includeCopy) {
    batch.set(
      doc(clientDb, 'users', copyUid, 'communities', id),
      communityCopy(id, copyUid, memberRole, {
        memberCount: 2 + increment,
        joinedAt: serverTimestamp(),
        ...copyOverrides,
      }),
    );
  }
  return batch.commit();
}

describe('users and profiles', () => {
  test('creates own profile with the Flutter payload', async () => {
    const clientDb = db(ids.outsider);
    await assertSucceeds(
      setDoc(doc(clientDb, 'users', ids.outsider), {
        displayName: 'Outsider',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        activeHub: null,
        avatar: null,
      }),
    );
  });
  test('cannot create a profile under another UID', async () => {
    await assertFails(setDoc(doc(db(ids.outsider), 'users', ids.memberGub), profile(ids.memberGub)));
  });
  test('authenticated users can read their own and other profiles', async () => {
    await seedProfiles();
    await assertSucceeds(getDoc(doc(db(ids.memberGub), 'users', ids.memberGub)));
    await assertSucceeds(getDoc(doc(db(ids.memberGub), 'users', ids.ownerGub)));
  });
  test('unauthenticated users cannot read profiles', async () => {
    await seedProfiles();
    await assertFails(getDoc(doc(anonymousDb(), 'users', ids.ownerGub)));
  });
  test('owner can update client-supported profile fields', async () => {
    await seedProfiles([ids.outsider]);
    await assertSucceeds(updateDoc(doc(db(ids.outsider), 'users', ids.outsider), {
      displayName: 'Updated',
      photoUrl: 'https://example.test/photo.png',
      updatedAt: serverTimestamp(),
    }));
  });
  test('cannot add sensitive or arbitrary profile fields', async () => {
    await seedProfiles([ids.outsider]);
    await assertFails(updateDoc(doc(db(ids.outsider), 'users', ids.outsider), { isAdmin: true }));
  });
  test('cannot modify another profile', async () => {
    await seedProfiles();
    await assertFails(updateDoc(doc(db(ids.outsider), 'users', ids.ownerGub), { displayName: 'Forged' }));
  });
  test('cannot delete a profile through current client policy', async () => {
    await seedProfiles([ids.outsider]);
    await assertFails(deleteDoc(doc(db(ids.outsider), 'users', ids.outsider)));
  });
  test('cannot add arbitrary fields when creating a profile', async () => {
    await assertFails(setDoc(doc(db(ids.outsider), 'users', ids.outsider), {
      ...profile(ids.outsider),
      isAdmin: true,
    }));
  });
  test('unauthenticated user cannot create a profile', async () => {
    await assertFails(setDoc(doc(anonymousDb(), 'users', 'anonymous'), profile('anonymous')));
  });
});

describe('create Gub batch', () => {
  test('accepts the complete Flutter batch', () => assertSucceeds(createGubBatch()));
  test('rejects root without owner membership', () => assertFails(createGubBatch({ includeMember: false })));
  test('rejects root without personal copy', () => assertFails(createGubBatch({ includeCopy: false })));
  test('rejects membership without a coherent root', () => assertFails(createGubBatch({ includeRoot: false, includeCopy: false })));
  test('rejects personal copy without membership', () => assertFails(createGubBatch({ includeRoot: false, includeMember: false })));
  test('rejects a false ownerId', () => assertFails(createGubBatch({ ownerId: ids.outsider })));
  test('rejects membership stored under a false UID', () => assertFails(createGubBatch({ memberUid: ids.outsider })));
  test('rejects owner role assigned to another UID', () => assertFails(createGubBatch({ memberUid: ids.secondMember, copyUid: ids.secondMember })));
  test('rejects an incoherent gubId in the root', () => assertFails(createGubBatch({ rootOverrides: { gubId: 'other' } })));
  test('rejects an incoherent ownerId in the copy', () => assertFails(createGubBatch({ copyOverrides: { ownerId: ids.outsider } })));
  test('rejects invite token data in the personal copy', () => assertFails(createGubBatch({ copyOverrides: { inviteTokenId } })));
  test('rejects an incorrect initial memberCount', () => assertFails(createGubBatch({ rootOverrides: { memberCount: 2 }, copyOverrides: { memberCount: 2 } })));
  test('rejects an arbitrary root field', () => assertFails(createGubBatch({ rootOverrides: { isAdmin: true } })));
  test('rejects unauthenticated creation', async () => {
    const clientDb = anonymousDb();
    await assertFails(setDoc(doc(clientDb, 'gubs', 'anonymous'), gubRoot('anonymous', 'anonymous')));
  });
  test('rejects a valid batch combined with an unknown write', () => assertFails(createGubBatch({ extraWrite: true })));
});

describe('join Gub batch and membership', () => {
  beforeEach(async () => {
    await seedProfiles();
    await seedGub();
  });
  test('accepts a complete coherent join batch', () => assertSucceeds(joinGubBatch()));
  test('private inviteTokenId discovery query remains denied to non-members', async () => {
    const q = query(collection(db(ids.outsider), 'gubs'), where('inviteTokenId', '==', inviteTokenId));
    await assertFails(getDocs(q));
  });
  test('rejects join without membership', () => assertFails(joinGubBatch({ includeMember: false })));
  test('rejects join without personal copy', () => assertFails(joinGubBatch({ includeCopy: false })));
  test('rejects membership and copy without root count update', () => assertFails(joinGubBatch({ includeRoot: false })));
  test('rejects copy without membership and count update', () => assertFails(joinGubBatch({ includeRoot: false, includeMember: false })));
  test('rejects unchanged memberCount', () => assertFails(joinGubBatch({ increment: 0 })));
  test('rejects memberCount increment greater than one', () => assertFails(joinGubBatch({ increment: 2 })));
  test('rejects changing name during join', () => assertFails(joinGubBatch({ rootUpdates: { name: 'Changed' } })));
  test('rejects changing ownerId during join', () => assertFails(joinGubBatch({ rootUpdates: { ownerId: ids.outsider } })));
  test('rejects invite token data in the joined copy', () => assertFails(joinGubBatch({ copyOverrides: { inviteTokenId } })));
  test('rejects auto-promotion to owner', () => assertFails(joinGubBatch({ memberRole: 'owner' })));
  test('rejects membership under another UID', () => assertFails(joinGubBatch({ memberUid: ids.secondMember })));
  test('rejects personal copy under another UID', () => assertFails(joinGubBatch({ copyUid: ids.secondMember })));
  test('rejects duplicate join', () => assertFails(joinGubBatch({ actor: ids.memberGub })));
  test('rejects join while deleting', async () => {
    await env.clearFirestore();
    await seedProfiles();
    await seedGub({ status: 'deleting' });
    await assertFails(joinGubBatch());
  });
  test('rejects unauthenticated join', async () => {
    const clientDb = anonymousDb();
    await assertFails(setDoc(doc(clientDb, 'gubs', 'g1', 'members', 'anonymous'), gubMember('anonymous')));
  });
  test('rejects join to missing Gub', () => assertFails(joinGubBatch({ id: 'missing' })));
  test('rejects incoherent membership and copy roles', () => assertFails(joinGubBatch({ copyOverrides: { role: 'owner' } })));
  test('owner and members can read root and member list', async () => {
    await assertSucceeds(getDoc(doc(db(ids.ownerGub), 'gubs', 'g1')));
    await assertSucceeds(getDoc(doc(db(ids.memberGub), 'gubs', 'g1')));
    await assertSucceeds(getDocs(collection(db(ids.memberGub), 'gubs', 'g1', 'members')));
  });
  test('outsider and unauthenticated users cannot read private Gub data', async () => {
    await assertFails(getDoc(doc(db(ids.outsider), 'gubs', 'g1')));
    await assertFails(getDoc(doc(anonymousDb(), 'gubs', 'g1')));
    await assertFails(getDocs(collection(db(ids.outsider), 'gubs', 'g1', 'members')));
  });
  test('a stale personal copy alone does not grant access', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', ids.outsider, 'gubs', 'g1'), gubCopy('g1', ids.outsider));
    });
    await assertFails(getDoc(doc(db(ids.outsider), 'gubs', 'g1')));
  });
  test('cannot create an arbitrary copy to obtain access', () => assertFails(setDoc(doc(db(ids.outsider), 'users', ids.outsider, 'gubs', 'g1'), gubCopy('g1', ids.outsider))));
  test('legacy Gub copy can backfill only its authoritative role despite stale count', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const ref = doc(context.firestore(), 'users', ids.memberGub, 'gubs', 'g1');
      const data = gubCopy('g1', ids.memberGub, 'member', { memberCount: 1 });
      delete data.role;
      await setDoc(ref, data);
    });
    await assertSucceeds(setDoc(doc(db(ids.memberGub), 'users', ids.memberGub, 'gubs', 'g1'), { role: 'member' }, { merge: true }));
  });
  test('member cannot change role or identity fields', async () => {
    const memberRef = doc(db(ids.memberGub), 'gubs', 'g1', 'members', ids.memberGub);
    await assertFails(updateDoc(memberRef, { role: 'owner' }));
    await assertFails(updateDoc(memberRef, { uid: ids.ownerGub }));
  });
  test('member cannot modify another membership', () => assertFails(updateDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'members', ids.secondMember), { displayName: 'Forged' })));
  test('owner can remove another member and their copy atomically', async () => {
    const clientDb = db(ids.ownerGub);
    const batch = writeBatch(clientDb);
    batch.delete(doc(clientDb, 'gubs', 'g1', 'members', ids.secondMember));
    batch.delete(doc(clientDb, 'users', ids.secondMember, 'gubs', 'g1'));
    await assertSucceeds(batch.commit());
  });
  test('member cannot remove another member', () => assertFails(deleteDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'members', ids.secondMember))));
  test('normal membership writes are denied while deleting', async () => {
    await env.clearFirestore();
    await seedProfiles();
    await seedGub({ status: 'deleting' });
    await assertFails(updateDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'members', ids.memberGub), { antiSpamRulesAccepted: true }));
  });
});

describe('Community creation, join, reads, and membership', () => {
  test('accepts the complete Flutter creation transaction', () => assertSucceeds(createCommunityBatch()));
  test('accepts Approval Community creation', () => assertSucceeds(createCommunityBatch({ rootOverrides: { accessMode: 'approval' } })));
  test('rejects false Community ownerId', () => assertFails(createCommunityBatch({ ownerId: ids.communityOutsider })));
  test('rejects creation without owner membership', () => assertFails(createCommunityBatch({ includeMember: false })));
  test('rejects creation without personal copy', () => assertFails(createCommunityBatch({ includeCopy: false })));
  test('rejects creation without communityOwnership marker', () => assertFails(createCommunityBatch({ includeMarker: false })));
  test('rejects arbitrary ownership marker', async () => {
    await assertFails(setDoc(doc(db(ids.ownerCommunity), 'communityOwnership', ids.ownerCommunity), { ownerId: ids.ownerCommunity, communityId: 'missing', createdAt: serverTimestamp() }));
  });
  test('rejects marker under a different UID', () => assertFails(createCommunityBatch({ markerUid: ids.communityOutsider })));
  test('rejects incoherent communityId in marker', () => assertFails(createCommunityBatch({ markerOverrides: { communityId: 'other' } })));
  test('rejects owner role for a different member', () => assertFails(createCommunityBatch({ memberUid: ids.memberCommunity, copyUid: ids.memberCommunity })));
  test('rejects incoherent root and copy', () => assertFails(createCommunityBatch({ copyOverrides: { name: 'Other' } })));
  test('rejects unauthenticated Community creation', () => assertFails(setDoc(doc(anonymousDb(), 'communities', 'c-anon'), communityRoot('c-anon', 'anonymous'))));
  test('rejects client-controlled Community creation timestamps', async () => {
    const fixed = new Date('2026-01-01T00:00:00Z');
    await assertFails(createCommunityBatch({ rootOverrides: { createdAt: fixed } }));
    await assertFails(createCommunityBatch({ memberOverrides: { joinedAt: fixed } }));
    await assertFails(createCommunityBatch({ copyOverrides: { joinedAt: fixed } }));
    await assertFails(createCommunityBatch({ markerOverrides: { createdAt: fixed } }));
  });
  test('rejects invalid Community text and unsupported metadata', async () => {
    await assertFails(createCommunityBatch({ rootOverrides: { name: '   ' } }));
    await assertFails(createCommunityBatch({ rootOverrides: { name: 'x'.repeat(31) } }));
    await assertFails(createCommunityBatch({ rootOverrides: { description: 'x'.repeat(281) } }));
    await assertFails(createCommunityBatch({ rootOverrides: { type: 'Forged' } }));
    await assertFails(createCommunityBatch({ rootOverrides: { language: 'Forged' } }));
    await assertFails(createCommunityBatch({ rootOverrides: { accessMode: 'private' } }));
  });

  describe('existing Community', () => {
    beforeEach(async () => {
      await seedProfiles();
      await seedCommunity();
    });
    test('authenticated outsider can read public root but not private root', async () => {
      await assertSucceeds(getDoc(doc(db(ids.communityOutsider), 'communities', 'c1')));
      await env.clearFirestore();
      await seedProfiles();
      await seedCommunity({ visibility: 'private' });
      await assertFails(getDoc(doc(db(ids.communityOutsider), 'communities', 'c1')));
    });
    test('public discovery query works for authenticated users', async () => {
      const q = query(collection(db(ids.communityOutsider), 'communities'), where('visibility', '==', 'public'));
      await assertSucceeds(getDocs(q));
    });
    test('outsider cannot read or write Community memberships', async () => {
      await assertFails(getDocs(collection(db(ids.communityOutsider), 'communities', 'c1', 'members')));
      await assertFails(updateDoc(doc(db(ids.communityOutsider), 'communities', 'c1', 'members', ids.memberCommunity), { role: 'owner' }));
    });
    test('rejects arbitrary Community personal copy', () => assertFails(setDoc(doc(db(ids.communityOutsider), 'users', ids.communityOutsider, 'communities', 'c1'), communityCopy('c1', ids.communityOutsider))));
    test('accepts complete public Community join transaction', () => assertSucceeds(joinCommunityBatch()));
    test('rejects unauthenticated Community join', () => assertFails(setDoc(doc(anonymousDb(), 'communities', 'c1', 'members', 'anonymous'), gubMember('anonymous'))));
    test('rejects incomplete Community join', () => assertFails(joinCommunityBatch({ includeCopy: false })));
    test('rejects Community join without count update', () => assertFails(joinCommunityBatch({ includeRoot: false })));
    test('rejects incoherent Community join copy', () => assertFails(joinCommunityBatch({ copyOverrides: { ownerId: ids.communityOutsider } })));
    test('rejects Community auto-promotion', () => assertFails(joinCommunityBatch({ memberRole: 'owner' })));
    test('rejects Community join under another UID', () => assertFails(joinCommunityBatch({ memberUid: ids.memberCommunity })));
    test('rejects duplicate Community join', () => assertFails(joinCommunityBatch({ actor: ids.memberCommunity })));
    test('rejects arbitrary Community root updates and memberCount changes', async () => {
      const root = doc(db(ids.memberCommunity), 'communities', 'c1');
      await assertFails(updateDoc(root, { memberCount: 1 }));
      await assertFails(updateDoc(root, { memberCount: -1 }));
      await assertFails(updateDoc(root, { memberCount: 3 }));
      await assertFails(updateDoc(root, { ownerId: ids.memberCommunity }));
      await assertFails(updateDoc(root, { createdAt: serverTimestamp() }));
      await assertFails(updateDoc(root, { arbitrary: true }));
    });
    test('rejects client-controlled join timestamps', async () => {
      const fixed = new Date('2026-01-01T00:00:00Z');
      await assertFails(joinCommunityBatch({ copyOverrides: { joinedAt: fixed } }));
    });
    test('an orphan user copy grants no membership but can be replaced by a valid join', async () => {
      await env.withSecurityRulesDisabled(async (context) => {
        await setDoc(
          doc(context.firestore(), 'users', ids.communityOutsider, 'communities', 'c1'),
          communityCopy('c1', ids.communityOutsider),
        );
      });
      await assertSucceeds(getDoc(doc(db(ids.communityOutsider), 'communities', 'c1', 'members', ids.communityOutsider)));
      await assertFails(getDocs(collection(db(ids.communityOutsider), 'communities', 'c1', 'members')));
      await assertFails(getDocs(collection(db(ids.communityOutsider), 'communities', 'c1', 'messages')));
      await assertSucceeds(joinCommunityBatch());
    });
    test('an authoritative member can recreate only a coherent missing personal copy', async () => {
      await env.withSecurityRulesDisabled((context) =>
        deleteDoc(doc(context.firestore(), 'users', ids.memberCommunity, 'communities', 'c1')),
      );
      const copy = communityCopy('c1', ids.memberCommunity, 'member', {
        memberCount: 2,
        joinedAt: new Date('2026-01-01T00:00:00Z'),
      });
      await assertSucceeds(
        setDoc(doc(db(ids.memberCommunity), 'users', ids.memberCommunity, 'communities', 'c1'), copy),
      );
      await assertFails(
        setDoc(doc(db(ids.memberCommunity), 'users', ids.memberCommunity, 'communities', 'c1'), {
          ...copy,
          role: 'owner',
        }),
      );
    });
    test('legacy Community copy can backfill only its authoritative role despite stale count', async () => {
      await env.withSecurityRulesDisabled(async (context) => {
        const ref = doc(context.firestore(), 'users', ids.memberCommunity, 'communities', 'c1');
        const data = communityCopy('c1', ids.memberCommunity, 'member', { memberCount: 1 });
        delete data.role;
        await setDoc(ref, data);
      });
      await assertSucceeds(setDoc(doc(db(ids.memberCommunity), 'users', ids.memberCommunity, 'communities', 'c1'), { role: 'member' }, { merge: true }));
    });
    test('rejects normal Community writes while deleting', async () => {
      await env.clearFirestore();
      await seedProfiles();
      await seedCommunity({ status: 'deleting' });
      await assertFails(joinCommunityBatch());
    });
  });
});

describe('Gub chat, read states, and Board', () => {
  beforeEach(async () => {
    await seedProfiles();
    await seedGub();
  });
  test('owner and member can create real Gub messages', async () => {
    await assertSucceeds(setDoc(doc(db(ids.ownerGub), 'gubs', 'g1', 'messages', 'm-owner'), gubMessage('m-owner', ids.ownerGub)));
    await assertSucceeds(setDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'messages', 'm-member'), gubMessage('m-member', ids.memberGub)));
  });
  test('member can read messages; outsider and anonymous cannot', async () => {
    await env.withSecurityRulesDisabled(async (context) => setDoc(doc(context.firestore(), 'gubs', 'g1', 'messages', 'm1'), { ...gubMessage('m1', ids.ownerGub), createdAt: new Date() }));
    await assertSucceeds(getDocs(query(collection(db(ids.memberGub), 'gubs', 'g1', 'messages'), where('createdAt', '>=', new Date('2026-01-01T00:00:00Z')))));
    await assertFails(getDocs(collection(db(ids.outsider), 'gubs', 'g1', 'messages')));
    await assertFails(getDocs(collection(anonymousDb(), 'gubs', 'g1', 'messages')));
  });
  for (const [name, overrides] of [
    ['senderId spoofing', { senderId: ids.ownerGub }],
    ['senderName spoofing', { senderName: 'Forged' }],
    ['incoherent gubId', { gubId: 'other' }],
    ['wrong createdAt type', { createdAt: 'today' }],
    ['arbitrary extra field', { isAdmin: true }],
  ]) {
    test(`rejects ${name} in Gub message`, () => assertFails(setDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'messages', `bad-${name}`), gubMessage(`bad-${name}`, ids.memberGub, overrides))));
  }
  test('rejects a Gub message without createdAt', async () => {
    const data = gubMessage('missing-created-at', ids.memberGub);
    delete data.createdAt;
    await assertFails(setDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'messages', 'missing-created-at'), data));
  });
  test('outsider cannot create Gub message', () => assertFails(setDoc(doc(db(ids.outsider), 'gubs', 'g1', 'messages', 'outsider-message'), gubMessage('outsider-message', ids.outsider))));
  test('Gub message update and normal delete are denied because client has no such flow', async () => {
    await env.withSecurityRulesDisabled(async (context) => setDoc(doc(context.firestore(), 'gubs', 'g1', 'messages', 'm1'), { ...gubMessage('m1', ids.memberGub), createdAt: new Date() }));
    await assertFails(updateDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'messages', 'm1'), { text: 'Edited' }));
    await assertFails(deleteDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'messages', 'm1')));
  });
  test('Gub chat write is denied during deletion', async () => {
    await env.clearFirestore();
    await seedProfiles();
    await seedGub({ status: 'deleting' });
    await assertFails(setDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'messages', 'blocked'), gubMessage('blocked', ids.memberGub)));
  });

  test('chatReads supports create and merge-update only for self', async () => {
    const ref = doc(db(ids.memberGub), 'gubs', 'g1', 'chatReads', ids.memberGub);
    await assertSucceeds(setDoc(ref, { userId: ids.memberGub, gubId: 'g1', lastReadAt: serverTimestamp() }, { merge: true }));
    await assertSucceeds(setDoc(ref, { userId: ids.memberGub, gubId: 'g1', lastReadAt: serverTimestamp() }, { merge: true }));
  });
  test('chatReads rejects wrong owner, internal IDs, types, extras, and delete', async () => {
    await assertFails(setDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'chatReads', ids.secondMember), { userId: ids.secondMember, gubId: 'g1', lastReadAt: serverTimestamp() }));
    const ref = doc(db(ids.memberGub), 'gubs', 'g1', 'chatReads', ids.memberGub);
    await assertFails(setDoc(ref, { userId: ids.ownerGub, gubId: 'g1', lastReadAt: serverTimestamp() }));
    await assertFails(setDoc(ref, { userId: ids.memberGub, gubId: 'other', lastReadAt: serverTimestamp() }));
    await assertFails(setDoc(ref, { userId: ids.memberGub, gubId: 'g1', lastReadAt: 'today' }));
    await assertFails(setDoc(ref, { userId: ids.memberGub, gubId: 'g1', lastReadAt: serverTimestamp(), extra: true }));
    await env.withSecurityRulesDisabled(async (context) => setDoc(doc(context.firestore(), 'gubs', 'g1', 'chatReads', ids.memberGub), { userId: ids.memberGub, gubId: 'g1', lastReadAt: new Date() }));
    await assertFails(deleteDoc(ref));
  });
  test('outsider cannot access chatReads', async () => {
    await assertFails(setDoc(doc(db(ids.outsider), 'gubs', 'g1', 'chatReads', ids.outsider), { userId: ids.outsider, gubId: 'g1', lastReadAt: serverTimestamp() }));
    await assertFails(getDoc(doc(db(ids.outsider), 'gubs', 'g1', 'chatReads', ids.memberGub)));
  });

  test('boardReads supports create and merge-update only for self', async () => {
    const ref = doc(db(ids.memberGub), 'gubs', 'g1', 'boardReads', ids.memberGub);
    await assertSucceeds(setDoc(ref, { lastReadAt: serverTimestamp() }, { merge: true }));
    await assertSucceeds(setDoc(ref, { lastReadAt: serverTimestamp() }, { merge: true }));
  });
  test('boardReads rejects wrong owner, types, extras, outsiders, and delete', async () => {
    await assertFails(setDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'boardReads', ids.secondMember), { lastReadAt: serverTimestamp() }));
    const ref = doc(db(ids.memberGub), 'gubs', 'g1', 'boardReads', ids.memberGub);
    await assertFails(setDoc(ref, { lastReadAt: 'today' }));
    await assertFails(setDoc(ref, { lastReadAt: serverTimestamp(), extra: true }));
    await assertFails(setDoc(doc(db(ids.outsider), 'gubs', 'g1', 'boardReads', ids.outsider), { lastReadAt: serverTimestamp() }));
    await env.withSecurityRulesDisabled(async (context) => setDoc(doc(context.firestore(), 'gubs', 'g1', 'boardReads', ids.memberGub), { lastReadAt: new Date() }));
    await assertFails(deleteDoc(ref));
  });
  test('read-state writes are denied while deleting', async () => {
    await env.clearFirestore();
    await seedProfiles();
    await seedGub({ status: 'deleting' });
    await assertFails(setDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'chatReads', ids.memberGub), { userId: ids.memberGub, gubId: 'g1', lastReadAt: serverTimestamp() }));
    await assertFails(setDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'boardReads', ids.memberGub), { lastReadAt: serverTimestamp() }));
  });

  test('owner and member can create real Board posts', async () => {
    await assertSucceeds(setDoc(doc(db(ids.ownerGub), 'gubs', 'g1', 'posts', 'p-owner'), boardPost(ids.ownerGub)));
    await assertSucceeds(setDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'posts', 'p-member'), boardPost(ids.memberGub)));
  });
  test('outsider cannot create or read Board posts; member can read', async () => {
    await assertFails(setDoc(doc(db(ids.outsider), 'gubs', 'g1', 'posts', 'p-out'), boardPost(ids.outsider)));
    await assertSucceeds(getDocs(query(collection(db(ids.memberGub), 'gubs', 'g1', 'posts'), where('createdAt', '>=', new Date('2026-01-01T00:00:00Z')))));
    await assertFails(getDocs(collection(db(ids.outsider), 'gubs', 'g1', 'posts')));
  });
  for (const [name, overrides] of [
    ['authorId spoofing', { authorId: ids.ownerGub }],
    ['authorName spoofing', { authorName: 'Forged' }],
    ['incoherent gubId', { gubId: 'other' }],
    ['wrong createdAt type', { createdAt: 'today' }],
    ['arbitrary extra field', { isAdmin: true }],
  ]) {
    test(`rejects ${name} in Board post`, () => assertFails(setDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'posts', `bad-${name}`), boardPost(ids.memberGub, overrides))));
  }
  test('Board update and delete are denied because the client implements neither', async () => {
    await env.withSecurityRulesDisabled(async (context) => setDoc(doc(context.firestore(), 'gubs', 'g1', 'posts', 'p1'), { ...boardPost(ids.memberGub), createdAt: new Date(), updatedAt: new Date() }));
    await assertFails(updateDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'posts', 'p1'), { message: 'Edited', updatedAt: serverTimestamp() }));
    await assertFails(deleteDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'posts', 'p1')));
    await assertFails(deleteDoc(doc(db(ids.ownerGub), 'gubs', 'g1', 'posts', 'p1')));
  });
  test('Board writes are denied while deleting', async () => {
    await env.clearFirestore();
    await seedProfiles();
    await seedGub({ status: 'deleting' });
    await assertFails(setDoc(doc(db(ids.memberGub), 'gubs', 'g1', 'posts', 'blocked'), boardPost(ids.memberGub)));
  });
});

describe('Community chat', () => {
  beforeEach(async () => {
    await seedProfiles();
    await seedCommunity();
  });
  test('owner and member can create real Community messages', async () => {
    await assertSucceeds(setDoc(doc(db(ids.ownerCommunity), 'communities', 'c1', 'messages', 'm-owner'), communityMessage('m-owner', ids.ownerCommunity)));
    await assertSucceeds(setDoc(doc(db(ids.memberCommunity), 'communities', 'c1', 'messages', 'm-member'), communityMessage('m-member', ids.memberCommunity)));
  });
  test('member can read Community chat; public outsider and anonymous cannot', async () => {
    await assertSucceeds(getDocs(query(collection(db(ids.memberCommunity), 'communities', 'c1', 'messages'), where('createdAt', '>=', new Date('2026-01-01T00:00:00Z')))));
    await assertFails(getDocs(collection(db(ids.communityOutsider), 'communities', 'c1', 'messages')));
    await assertFails(getDocs(collection(anonymousDb(), 'communities', 'c1', 'messages')));
  });
  test('public outsider cannot write Community chat', () => assertFails(setDoc(doc(db(ids.communityOutsider), 'communities', 'c1', 'messages', 'outsider'), communityMessage('outsider', ids.communityOutsider))));
  for (const [name, overrides] of [
    ['senderId spoofing', { senderId: ids.ownerCommunity }],
    ['senderName spoofing', { senderName: 'Forged' }],
    ['incoherent communityId', { communityId: 'other' }],
    ['wrong createdAt type', { createdAt: 'today' }],
    ['client-controlled createdAt', { createdAt: new Date('2026-01-01T00:00:00Z') }],
    ['empty text', { text: '   ' }],
    ['text over the limit', { text: 'x'.repeat(2001) }],
    ['arbitrary extra field', { isAdmin: true }],
  ]) {
    test(`rejects ${name} in Community message`, () => assertFails(setDoc(doc(db(ids.memberCommunity), 'communities', 'c1', 'messages', `bad-${name}`), communityMessage(`bad-${name}`, ids.memberCommunity, overrides))));
  }
  test('rejects a Community message without createdAt', async () => {
    const data = communityMessage('missing-created-at', ids.memberCommunity);
    delete data.createdAt;
    await assertFails(setDoc(doc(db(ids.memberCommunity), 'communities', 'c1', 'messages', 'missing-created-at'), data));
  });
  test('Community message update and normal delete are denied', async () => {
    await env.withSecurityRulesDisabled(async (context) => setDoc(doc(context.firestore(), 'communities', 'c1', 'messages', 'm1'), { ...communityMessage('m1', ids.memberCommunity), createdAt: new Date() }));
    await assertFails(updateDoc(doc(db(ids.memberCommunity), 'communities', 'c1', 'messages', 'm1'), { text: 'Edited' }));
    await assertFails(deleteDoc(doc(db(ids.memberCommunity), 'communities', 'c1', 'messages', 'm1')));
  });
  test('Community chat write is denied while deleting', async () => {
    await env.clearFirestore();
    await seedProfiles();
    await seedCommunity({ status: 'deleting' });
    await assertFails(setDoc(doc(db(ids.memberCommunity), 'communities', 'c1', 'messages', 'blocked'), communityMessage('blocked', ids.memberCommunity)));
  });
});
