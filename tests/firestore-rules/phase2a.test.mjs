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
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-gubify-phase2a';
const uid = {
  owner: 'communityOwner',
  member: 'communityMember',
  requester: 'communityRequester',
  outsider: 'communityOutsider',
};
let env;
const db = (userId) => env.authenticatedContext(userId).firestore();
const anonymousDb = () => env.unauthenticatedContext().firestore();
const now = () => new Date('2026-01-01T00:00:00Z');

const root = (accessMode = 'approval', overrides = {}) => ({
  communityId: 'c1',
  name: 'Community',
  ownerId: uid.owner,
  memberCount: 1,
  visibility: 'public',
  createdAt: now(),
  type: 'General',
  language: 'English',
  description: '',
  accessMode,
  nameKey: 'community',
  slug: 'community',
  slugAssignedAt: now(),
  ...overrides,
});
const member = (userId, role = 'member', overrides = {}) => ({
  uid: userId,
  displayName: userId,
  photoUrl: null,
  role,
  joinedAt: now(),
  ...overrides,
});
const copy = (userId, memberCount = 2, overrides = {}) => ({
  communityId: 'c1',
  name: 'Community',
  ownerId: uid.owner,
  memberCount,
  visibility: 'public',
  role: 'member',
  joinedAt: now(),
  ...overrides,
});
const accessRequest = (userId = uid.requester, overrides = {}) => ({
  userId,
  displayName: userId,
  status: 'pending',
  createdAt: now(),
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
    const seedDb = context.firestore();
    const batch = writeBatch(seedDb);
    for (const userId of Object.values(uid)) {
      batch.set(doc(seedDb, 'users', userId), {
        displayName: userId,
        createdAt: now(),
        updatedAt: now(),
        activeHub: null,
        avatar: null,
      });
    }
    batch.set(doc(seedDb, 'communities', 'c1'), root());
    batch.set(doc(seedDb, 'communityPublic', 'community'), {
      communityId: 'c1',
      slug: 'community',
      name: 'Community',
      description: '',
      type: 'General',
      language: 'English',
      accessMode: 'approval',
      memberCount: 1,
      createdAt: now(),
      updatedAt: now(),
    });
    batch.set(
      doc(seedDb, 'communityGuidelinesAcceptances', uid.requester),
      { accepted: true, version: 1, acceptedAt: now() },
    );
    batch.set(
      doc(seedDb, 'communities', 'c1', 'members', uid.owner),
      member(uid.owner, 'owner'),
    );
    batch.set(doc(seedDb, 'users', uid.owner, 'communities', 'c1'), {
      ...copy(uid.owner, 1),
      role: 'owner',
    });
    batch.set(doc(seedDb, 'communityOwnership', uid.owner), {
      ownerId: uid.owner,
      communityId: 'c1',
      createdAt: now(),
    });
    await batch.commit();
  });
});

async function replaceRoot(data) {
  await env.withSecurityRulesDisabled((context) =>
    setDoc(doc(context.firestore(), 'communities', 'c1'), data),
  );
}

async function seedRequest(userId = uid.requester, overrides = {}) {
  await env.withSecurityRulesDisabled((context) =>
    setDoc(
      doc(context.firestore(), 'communities', 'c1', 'joinRequests', userId),
      accessRequest(userId, overrides),
    ),
  );
}

async function seedMember(userId = uid.member) {
  await env.withSecurityRulesDisabled(async (context) => {
    const seedDb = context.firestore();
    const batch = writeBatch(seedDb);
    batch.update(doc(seedDb, 'communities', 'c1'), { memberCount: 2 });
    batch.update(doc(seedDb, 'communityPublic', 'community'), {
      memberCount: 2,
      updatedAt: now(),
    });
    batch.set(
      doc(seedDb, 'communities', 'c1', 'members', userId),
      member(userId),
    );
    batch.set(
      doc(seedDb, 'users', userId, 'communities', 'c1'),
      copy(userId),
    );
    await batch.commit();
  });
}

function openJoinBatch({
  actor = uid.requester,
  count = 2,
  includeMember = true,
  includeCopy = true,
  role = 'member',
} = {}) {
  const clientDb = db(actor);
  const batch = writeBatch(clientDb);
  batch.update(doc(clientDb, 'communities', 'c1'), { memberCount: count });
  batch.update(doc(clientDb, 'communityPublic', 'community'), {
    memberCount: count,
    updatedAt: serverTimestamp(),
  });
  if (includeMember) {
    batch.set(doc(clientDb, 'communities', 'c1', 'members', actor), {
      ...member(actor, role),
      joinedAt: serverTimestamp(),
    });
  }
  if (includeCopy) {
    batch.set(doc(clientDb, 'users', actor, 'communities', 'c1'), {
      ...copy(actor, count, { role }),
      joinedAt: serverTimestamp(),
    });
  }
  batch.set(doc(clientDb, 'communityUserProgress', actor), {
    xp: 0,
    communityIds: ['c1'],
    membershipProjectionCommunityId: 'c1',
    membershipProjectionAction: 'join',
    membershipProjectionUpdatedAt: serverTimestamp(),
  }, { merge: true });
  return batch.commit();
}

function approveRequest({
  actor = uid.owner,
  target = uid.requester,
} = {}) {
  const clientDb = db(actor);
  return updateDoc(
    doc(clientDb, 'communities', 'c1', 'joinRequests', target),
    {
      status: 'approved',
      resolvedAt: serverTimestamp(),
      resolvedBy: actor,
    },
  );
}

function finalizeApprovedJoin({
  actor = uid.requester,
  target = uid.requester,
  count = 2,
} = {}) {
  const clientDb = db(actor);
  const batch = writeBatch(clientDb);
  batch.update(doc(clientDb, 'communities', 'c1'), { memberCount: count });
  batch.update(doc(clientDb, 'communityPublic', 'community'), {
    memberCount: count,
    updatedAt: serverTimestamp(),
  });
  batch.set(doc(clientDb, 'communities', 'c1', 'members', target), {
    ...member(target),
    joinedAt: serverTimestamp(),
  });
  batch.set(doc(clientDb, 'users', target, 'communities', 'c1'), {
    ...copy(target, count),
    joinedAt: serverTimestamp(),
  });
  batch.set(doc(clientDb, 'communityUserProgress', target), {
    xp: 0,
    communityIds: ['c1'],
    membershipProjectionCommunityId: 'c1',
    membershipProjectionAction: 'join',
    membershipProjectionUpdatedAt: serverTimestamp(),
  }, { merge: true });
  batch.delete(doc(clientDb, 'communities', 'c1', 'joinRequests', target));
  return batch.commit();
}

async function assertApprovalOnly(target = uid.requester) {
  await env.withSecurityRulesDisabled(async (context) => {
    const seedDb = context.firestore();
    const [rootSnapshot, publicSnapshot, memberSnapshot, copySnapshot,
      projectionSnapshot, requestSnapshot] = await Promise.all([
      getDoc(doc(seedDb, 'communities', 'c1')),
      getDoc(doc(seedDb, 'communityPublic', 'community')),
      getDoc(doc(seedDb, 'communities', 'c1', 'members', target)),
      getDoc(doc(seedDb, 'users', target, 'communities', 'c1')),
      getDoc(doc(seedDb, 'communityUserProgress', target)),
      getDoc(doc(seedDb, 'communities', 'c1', 'joinRequests', target)),
    ]);
    assert.equal(rootSnapshot.data().memberCount, 1);
    assert.equal(publicSnapshot.data().memberCount, 1);
    assert.equal(memberSnapshot.exists(), false);
    assert.equal(copySnapshot.exists(), false);
    assert.equal(projectionSnapshot.exists(), false);
    assert.equal(requestSnapshot.data().status, 'approved');
  });
}

describe('Community Explorer and public access', () => {
  test('anonymous Explorer read is denied', async () => {
    const q = query(
      collection(anonymousDb(), 'communities'),
      where('visibility', '==', 'public'),
    );
    await assertFails(getDocs(q));
  });
  test('authenticated user can read public Community details', () =>
    assertSucceeds(getDoc(doc(db(uid.outsider), 'communities', 'c1'))));
  test('Explorer query supports accessMode and stable pagination ordering', async () => {
    const q = query(
      collection(db(uid.outsider), 'communities'),
      where('visibility', '==', 'public'),
      where('accessMode', 'in', ['open', 'approval']),
      orderBy('createdAt', 'desc'),
      orderBy('__name__', 'desc'),
      limit(20),
    );
    await assertSucceeds(getDocs(q));
  });
  test('legacy Community is not open by fallback', async () => {
    const legacy = root();
    delete legacy.accessMode;
    await replaceRoot(legacy);
    await assertFails(openJoinBatch());
  });
  test('accessMode cannot be changed after creation', () =>
    assertFails(
      updateDoc(doc(db(uid.owner), 'communities', 'c1'), {
        accessMode: 'open',
      }),
    ));
});

describe('Open Community join', () => {
  beforeEach(() => replaceRoot(root('open')));
  test('valid atomic join succeeds', () => assertSucceeds(openJoinBatch()));
  test('join without authoritative membership fails', () =>
    assertFails(openJoinBatch({ includeMember: false })));
  test('join without coherent user copy fails', () =>
    assertFails(openJoinBatch({ includeCopy: false })));
  test('wrong memberCount fails', () =>
    assertFails(openJoinBatch({ count: 3 })));
  test('auto-promotion fails', () =>
    assertFails(openJoinBatch({ role: 'owner' })));
  test('double join fails', async () => {
    await assertSucceeds(openJoinBatch());
    await assertFails(openJoinBatch());
  });
});

describe('Approval requests', () => {
  test('direct join into Approval Community fails', () =>
    assertFails(openJoinBatch()));
  test('valid request succeeds and requester can read it', async () => {
    const ref = doc(
      db(uid.requester),
      'communities',
      'c1',
      'joinRequests',
      uid.requester,
    );
    await assertSucceeds(
      setDoc(ref, {
        ...accessRequest(),
        createdAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(getDoc(ref));
  });
  test('wrong uid, extra fields, blank and long names are denied', async () => {
    const ref = doc(
      db(uid.requester),
      'communities',
      'c1',
      'joinRequests',
      uid.requester,
    );
    for (const overrides of [
      { userId: uid.outsider },
      { role: 'owner' },
      { displayName: '   ' },
      { displayName: 'x'.repeat(26) },
    ]) {
      await assertFails(
        setDoc(ref, {
          ...accessRequest(uid.requester, overrides),
          createdAt: serverTimestamp(),
        }),
      );
    }
  });
  test('client timestamp and duplicate request are denied', async () => {
    const ref = doc(
      db(uid.requester),
      'communities',
      'c1',
      'joinRequests',
      uid.requester,
    );
    await assertFails(setDoc(ref, accessRequest()));
    await seedRequest();
    await assertFails(
      setDoc(ref, { ...accessRequest(), createdAt: serverTimestamp() }),
    );
  });
  test('request in Open or deleting Community is denied', async () => {
    await replaceRoot(root('open'));
    await assertFails(
      setDoc(
        doc(
          db(uid.requester),
          'communities',
          'c1',
          'joinRequests',
          uid.requester,
        ),
        { ...accessRequest(), createdAt: serverTimestamp() },
      ),
    );
    await replaceRoot(
      root('approval', {
        deletionStatus: 'deleting',
        deletionRequestedBy: uid.owner,
        deletionStartedBy: uid.owner,
      }),
    );
    await assertFails(
      setDoc(
        doc(
          db(uid.requester),
          'communities',
          'c1',
          'joinRequests',
          uid.requester,
        ),
        { ...accessRequest(), createdAt: serverTimestamp() },
      ),
    );
  });
  test('requester can cancel own pending request only', async () => {
    await seedRequest();
    const ref = doc(
      db(uid.requester),
      'communities',
      'c1',
      'joinRequests',
      uid.requester,
    );
    await assertFails(
      deleteDoc(
        doc(
          db(uid.outsider),
          'communities',
          'c1',
          'joinRequests',
          uid.requester,
        ),
      ),
    );
    await assertSucceeds(deleteDoc(ref));
  });
  test('processed request cannot be cancelled', async () => {
    await seedRequest(uid.requester, {
      status: 'rejected',
      resolvedAt: now(),
      resolvedBy: uid.owner,
    });
    await assertFails(
      deleteDoc(
        doc(
          db(uid.requester),
          'communities',
          'c1',
          'joinRequests',
          uid.requester,
        ),
      ),
    );
  });
  test('owner can list requests but normal member cannot', async () => {
    await seedMember();
    await seedRequest();
    await assertSucceeds(
      getDocs(
        query(
          collection(db(uid.owner), 'communities', 'c1', 'joinRequests'),
          where('status', '==', 'pending'),
        ),
      ),
    );
    await assertFails(
      getDocs(
        collection(db(uid.member), 'communities', 'c1', 'joinRequests'),
      ),
    );
  });
  test('pending request does not grant Community chat access', async () => {
    await seedRequest();
    await assertFails(
      getDocs(
        collection(
          db(uid.requester),
          'communities',
          'c1',
          'messages',
        ),
      ),
    );
  });
});

describe('Owner request resolution', () => {
  beforeEach(() => seedRequest());
  test('owner approval changes only the pending request', async () => {
    await assertSucceeds(approveRequest());
    await assertApprovalOnly();
  });
  test('non-owner approval fails', () =>
    assertFails(approveRequest({ actor: uid.outsider })));
  test('owner cannot approve a banned requester', async () => {
    await env.withSecurityRulesDisabled((context) =>
      setDoc(doc(context.firestore(), 'communities', 'c1', 'bans', uid.requester), {
        userId: uid.requester,
        displayName: uid.requester,
        photoUrl: null,
        bannedBy: uid.owner,
        bannedAt: now(),
      }),
    );
    await assertFails(approveRequest());
  });
  test('approved requester finalizes member, copy, projection and counts', async () => {
    await assertSucceeds(approveRequest());
    await assertSucceeds(finalizeApprovedJoin());
    await env.withSecurityRulesDisabled(async (context) => {
      const seedDb = context.firestore();
      const [rootSnapshot, publicSnapshot, memberSnapshot, copySnapshot,
        projectionSnapshot, requestSnapshot] = await Promise.all([
        getDoc(doc(seedDb, 'communities', 'c1')),
        getDoc(doc(seedDb, 'communityPublic', 'community')),
        getDoc(doc(seedDb, 'communities', 'c1', 'members', uid.requester)),
        getDoc(doc(seedDb, 'users', uid.requester, 'communities', 'c1')),
        getDoc(doc(seedDb, 'communityUserProgress', uid.requester)),
        getDoc(doc(seedDb, 'communities', 'c1', 'joinRequests', uid.requester)),
      ]);
      assert.equal(rootSnapshot.data().memberCount, 2);
      assert.equal(publicSnapshot.data().memberCount, 2);
      assert.equal(memberSnapshot.exists(), true);
      assert.equal(copySnapshot.exists(), true);
      assert.equal(projectionSnapshot.data().communityIds.includes('c1'), true);
      assert.equal(requestSnapshot.exists(), false);
    });
  });
  test('finalization is denied while request is pending, rejected, missing, or owned by another user', async () => {
    await assertFails(finalizeApprovedJoin());
    await env.withSecurityRulesDisabled((context) =>
      setDoc(
        doc(context.firestore(), 'communities', 'c1', 'joinRequests', uid.requester),
        accessRequest(uid.requester, {
          status: 'rejected',
          resolvedAt: now(),
          resolvedBy: uid.owner,
        }),
      ),
    );
    await assertFails(finalizeApprovedJoin());
    await env.withSecurityRulesDisabled((context) =>
      deleteDoc(doc(context.firestore(), 'communities', 'c1', 'joinRequests', uid.requester)),
    );
    await assertFails(finalizeApprovedJoin());
    await seedRequest();
    await assertSucceeds(approveRequest());
    await assertFails(finalizeApprovedJoin({ actor: uid.outsider }));
  });
  test('finalization requires current acceptance and cannot be replayed or target an existing member', async () => {
    await assertSucceeds(approveRequest());
    await env.withSecurityRulesDisabled((context) =>
      deleteDoc(doc(context.firestore(), 'communityGuidelinesAcceptances', uid.requester)),
    );
    await assertFails(finalizeApprovedJoin());
    await env.withSecurityRulesDisabled((context) =>
      setDoc(doc(context.firestore(), 'communityGuidelinesAcceptances', uid.requester), {
        accepted: true,
        version: 1,
        acceptedAt: now(),
      }),
    );
    await assertSucceeds(finalizeApprovedJoin());
    await assertFails(finalizeApprovedJoin());
    await env.withSecurityRulesDisabled(async (context) => {
      const seedDb = context.firestore();
      await setDoc(
        doc(seedDb, 'communities', 'c1', 'joinRequests', uid.requester),
        accessRequest(uid.requester),
      );
    });
    await assertFails(approveRequest());
  });
  test('owner can reject pending request without changing membership', () =>
    assertSucceeds(
      updateDoc(
        doc(
          db(uid.owner),
          'communities',
          'c1',
          'joinRequests',
          uid.requester,
        ),
        {
          status: 'rejected',
          resolvedAt: serverTimestamp(),
          resolvedBy: uid.owner,
        },
      ),
    ));
  test('non-owner reject and reject with memberCount change fail', async () => {
    await assertFails(
      updateDoc(
        doc(
          db(uid.outsider),
          'communities',
          'c1',
          'joinRequests',
          uid.requester,
        ),
        {
          status: 'rejected',
          resolvedAt: serverTimestamp(),
          resolvedBy: uid.outsider,
        },
      ),
    );
    const ownerDb = db(uid.owner);
    const batch = writeBatch(ownerDb);
    batch.update(doc(ownerDb, 'communities', 'c1'), { memberCount: 2 });
    batch.update(
      doc(ownerDb, 'communities', 'c1', 'joinRequests', uid.requester),
      {
        status: 'rejected',
        resolvedAt: serverTimestamp(),
        resolvedBy: uid.owner,
      },
    );
    await assertFails(batch.commit());
  });
});
