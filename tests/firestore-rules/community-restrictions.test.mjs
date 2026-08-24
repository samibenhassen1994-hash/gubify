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
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-gubify';
const ids = {
  owner: 'owner',
  member: 'member',
  joiner: 'joiner',
  outsider: 'outsider',
};
const joinedAt = new Date('2026-08-20T00:00:00Z');
let env;

const db = (uid) => env.authenticatedContext(uid).firestore();
const communityRef = (uid, communityId) =>
  doc(db(uid), 'communities', communityId);
const memberRef = (uid, communityId, memberId) =>
  doc(db(uid), 'communities', communityId, 'members', memberId);
const messageRef = (uid, communityId, messageId) =>
  doc(db(uid), 'communities', communityId, 'messages', messageId);
const requestRef = (uid, communityId, userId) =>
  doc(db(uid), 'communities', communityId, 'joinRequests', userId);
const platformRestrictionRef = (uid, userId) =>
  doc(db(uid), 'platformRestrictions', userId);
const communityRestrictionRef = (uid, communityId) =>
  doc(db(uid), 'communityRestrictions', communityId);
const ownershipRef = (uid, ownerId) =>
  doc(db(uid), 'communityOwnership', ownerId);
const slugRef = (uid, slug) => doc(db(uid), 'communitySlugs', slug);
const nameRef = (uid, nameKey) => doc(db(uid), 'communityNames', nameKey);
const publicRef = (uid, slug) => doc(db(uid), 'communityPublic', slug);
const banRef = (uid, communityId, userId) =>
  doc(db(uid), 'communities', communityId, 'bans', userId);

const communityData = (communityId, accessMode, memberCount = 1) => ({
  communityId,
  name: `${communityId} Community`,
  ownerId: ids.owner,
  memberCount,
  visibility: 'public',
  deletionStatus: 'active',
  accessMode,
  createdAt: joinedAt,
});

const memberData = (uid, displayName, role = 'member') => ({
  uid,
  displayName,
  photoUrl: null,
  role,
  joinedAt,
});

const communityMessage = (communityId, messageId, senderId, senderName) => ({
  messageId,
  communityId,
  senderId,
  senderName,
  text: 'Hello Community',
  createdAt: serverTimestamp(),
});

const joinOpenCommunity = (uid, communityId) => {
  const clientDb = db(uid);
  const root = doc(clientDb, 'communities', communityId);
  const member = doc(clientDb, 'communities', communityId, 'members', uid);
  const copy = doc(clientDb, 'users', uid, 'communities', communityId);
  return runTransaction(clientDb, async (transaction) => {
    const rootSnapshot = await transaction.get(root);
    await transaction.get(member);
    await transaction.get(copy);
    const rootData = rootSnapshot.data();
    const memberCount = rootData.memberCount + 1;
    transaction.update(root, { memberCount });
    transaction.set(member, {
      uid,
      displayName: 'Joiner',
      photoUrl: null,
      role: 'member',
      joinedAt: serverTimestamp(),
    });
    transaction.set(copy, {
      communityId,
      name: rootData.name,
      ownerId: rootData.ownerId,
      memberCount,
      visibility: 'public',
      role: 'member',
      joinedAt: serverTimestamp(),
    });
  });
};

const leaveCommunity = (uid, communityId) => {
  const clientDb = db(uid);
  const root = doc(clientDb, 'communities', communityId);
  const member = doc(clientDb, 'communities', communityId, 'members', uid);
  return runTransaction(clientDb, async (transaction) => {
    const rootSnapshot = await transaction.get(root);
    await transaction.get(member);
    transaction.update(root, { memberCount: rootSnapshot.data().memberCount - 1 });
    transaction.delete(member);
  });
};

const initializePlatformRestriction = (actor, userId = actor) => {
  const clientDb = db(actor);
  const reference = doc(clientDb, 'platformRestrictions', userId);
  return runTransaction(clientDb, async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (snapshot.exists()) return false;
    transaction.set(reference, {
      communityChatRestricted: false,
      updatedAt: serverTimestamp(),
    });
    return true;
  });
};

const initializeCommunityRestriction = (actor, communityId) => {
  const clientDb = db(actor);
  const root = doc(clientDb, 'communities', communityId);
  const restriction = doc(clientDb, 'communityRestrictions', communityId);
  return runTransaction(clientDb, async (transaction) => {
    const rootSnapshot = await transaction.get(root);
    const restrictionSnapshot = await transaction.get(restriction);
    if (!rootSnapshot.exists() || restrictionSnapshot.exists()) return false;
    transaction.set(restriction, {
      hiddenFromDiscovery: false,
      joiningRestricted: false,
      updatedAt: serverTimestamp(),
    });
    return true;
  });
};

const createCommunityWithRestriction = () => {
  const communityId = 'new-community';
  const slug = 'new-community';
  const name = 'New Community';
  const clientDb = db(ids.owner);
  const batch = writeBatch(clientDb);
  batch.set(doc(clientDb, 'communities', communityId), {
    communityId,
    name,
    ownerId: ids.owner,
    memberCount: 1,
    visibility: 'public',
    createdAt: serverTimestamp(),
    type: 'General',
    language: 'English',
    description: '',
    accessMode: 'open',
    nameKey: name.toLowerCase(),
    slug,
    slugAssignedAt: serverTimestamp(),
  });
  batch.set(doc(clientDb, 'communityNames', name.toLowerCase()), {
    nameKey: name.toLowerCase(),
    communityId,
    ownerId: ids.owner,
    createdAt: serverTimestamp(),
  });
  batch.set(doc(clientDb, 'communitySlugs', slug), {
    slug,
    communityId,
    ownerId: ids.owner,
    createdAt: serverTimestamp(),
  });
  batch.set(doc(clientDb, 'communityPublic', slug), {
    communityId,
    slug,
    name,
    description: '',
    language: 'English',
    accessMode: 'open',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.set(doc(clientDb, 'communities', communityId, 'members', ids.owner), {
    ...memberData(ids.owner, 'Owner', 'owner'),
    joinedAt: serverTimestamp(),
  });
  batch.set(doc(clientDb, 'users', ids.owner, 'communities', communityId), {
    communityId,
    name,
    ownerId: ids.owner,
    memberCount: 1,
    visibility: 'public',
    role: 'owner',
    joinedAt: serverTimestamp(),
  });
  batch.set(doc(clientDb, 'communityOwnership', ids.owner), {
    ownerId: ids.owner,
    communityId,
    createdAt: serverTimestamp(),
  });
  batch.set(doc(clientDb, 'communityRestrictions', communityId), {
    hiddenFromDiscovery: false,
    joiningRestricted: false,
    updatedAt: serverTimestamp(),
  });
  return batch.commit();
};

const deleteCommunityWithRestriction = (communityId) => {
  const clientDb = db(ids.owner);
  const root = doc(clientDb, 'communities', communityId);
  const restriction = doc(clientDb, 'communityRestrictions', communityId);
  const batch = writeBatch(clientDb);
  batch.delete(restriction);
  batch.delete(root);
  return batch.commit();
};

const seedModernCommunityForDeletion = async (communityId = 'modern-delete') => {
  const slug = `${communityId}-slug`;
  const name = `${communityId} Community`;
  const nameKey = name.toLowerCase();
  await env.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    const batch = writeBatch(firestore);
    batch.set(doc(firestore, 'communities', communityId), {
      communityId,
      name,
      ownerId: ids.owner,
      memberCount: 2,
      visibility: 'public',
      deletionStatus: 'active',
      createdAt: joinedAt,
      type: 'General',
      language: 'English',
      description: '',
      accessMode: 'open',
      nameKey,
      slug,
      slugAssignedAt: joinedAt,
    });
    batch.set(doc(firestore, 'communities', communityId, 'members', ids.owner),
      memberData(ids.owner, 'Owner', 'owner'));
    batch.set(doc(firestore, 'communities', communityId, 'members', ids.member),
      memberData(ids.member, 'Member'));
    batch.set(doc(firestore, 'communities', communityId, 'messages', 'message'), {
      ...communityMessage(communityId, 'message', ids.owner, 'Owner'),
      createdAt: joinedAt,
    });
    batch.set(doc(firestore, 'communities', communityId, 'joinRequests', ids.member), {
      userId: ids.member,
      displayName: 'Member',
      status: 'pending',
      createdAt: joinedAt,
    });
    batch.set(doc(firestore, 'communities', communityId, 'bans', ids.outsider), {
      userId: ids.outsider,
      displayName: 'Outsider',
      photoUrl: null,
      bannedBy: ids.owner,
      bannedAt: joinedAt,
    });
    batch.set(doc(firestore, 'communityOwnership', ids.owner), {
      ownerId: ids.owner,
      communityId,
      createdAt: joinedAt,
    });
    batch.set(doc(firestore, 'communitySlugs', slug), {
      slug,
      communityId,
      ownerId: ids.owner,
      createdAt: joinedAt,
    });
    batch.set(doc(firestore, 'communityNames', nameKey), {
      nameKey,
      communityId,
      ownerId: ids.owner,
      createdAt: joinedAt,
    });
    batch.set(doc(firestore, 'communityPublic', slug), {
      communityId,
      slug,
      name,
      description: '',
      language: 'English',
      accessMode: 'open',
      createdAt: joinedAt,
      updatedAt: joinedAt,
    });
    batch.set(doc(firestore, 'communityRestrictions', communityId), {
      hiddenFromDiscovery: false,
      joiningRestricted: false,
      updatedAt: joinedAt,
    });
    await batch.commit();
  });
  return { communityId, nameKey, slug };
};

const markCommunityDeleting = (communityId) =>
  updateDoc(communityRef(ids.owner, communityId), {
    deletionStatus: 'deleting',
    deletionStartedAt: serverTimestamp(),
    deletionStartedBy: ids.owner,
    deletionRequestedBy: ids.owner,
  });

const finalizeModernCommunityDeletion = (
  { communityId, nameKey, slug },
  { leave = [] } = {},
) => {
  const clientDb = db(ids.owner);
  const batch = writeBatch(clientDb);
  const references = {
    ownership: doc(clientDb, 'communityOwnership', ids.owner),
    slug: doc(clientDb, 'communitySlugs', slug),
    name: doc(clientDb, 'communityNames', nameKey),
    public: doc(clientDb, 'communityPublic', slug),
    restriction: doc(clientDb, 'communityRestrictions', communityId),
  };
  for (const [key, reference] of Object.entries(references)) {
    if (!leave.includes(key)) batch.delete(reference);
  }
  batch.delete(doc(clientDb, 'communities', communityId));
  return batch.commit();
};

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
    const firestore = context.firestore();
    await setDoc(doc(firestore, 'communities', 'open'), communityData('open', 'open', 2));
    await setDoc(doc(firestore, 'communities', 'approval'), communityData('approval', 'approval'));
    await setDoc(doc(firestore, 'communities', 'open', 'members', ids.owner), memberData(ids.owner, 'Owner', 'owner'));
    await setDoc(doc(firestore, 'communities', 'open', 'members', ids.member), memberData(ids.member, 'Member'));
    await setDoc(doc(firestore, 'communities', 'approval', 'members', ids.owner), memberData(ids.owner, 'Owner', 'owner'));
    await setDoc(doc(firestore, 'gubs', 'private-gub'), {
      gubId: 'private-gub',
      ownerId: ids.owner,
      deletionStatus: 'active',
    });
    await setDoc(doc(firestore, 'gubs', 'private-gub', 'members', ids.member), memberData(ids.member, 'Member'));
  });
});

describe('manual Community restrictions', () => {
  test('authenticated users initialize only their own missing safe platform restriction once', async () => {
    assert.equal(
      await assertSucceeds(initializePlatformRestriction(ids.member)),
      true,
    );
    const initial = await getDoc(platformRestrictionRef(ids.member, ids.member));
    assert.deepEqual(initial.data().communityChatRestricted, false);
    assert.equal(
      await assertSucceeds(initializePlatformRestriction(ids.member)),
      false,
    );
    await assertFails(initializePlatformRestriction(ids.member, ids.outsider));
  });

  test('platform restriction initialization rejects unsafe flags and extra fields', async () => {
    await assertFails(
      setDoc(platformRestrictionRef(ids.member, ids.member), {
        communityChatRestricted: true,
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      setDoc(platformRestrictionRef(ids.member, ids.member), {
        communityChatRestricted: false,
        updatedAt: serverTimestamp(),
        forged: true,
      }),
    );
  });

  test('existing platform restrictions are never overwritten by initialization', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'platformRestrictions', ids.member), {
        communityChatRestricted: true,
        updatedAt: joinedAt,
      });
    });

    assert.equal(
      await assertSucceeds(initializePlatformRestriction(ids.member)),
      false,
    );
    const restriction = await getDoc(platformRestrictionRef(ids.member, ids.member));
    assert.equal(restriction.data().communityChatRestricted, true);
  });

  test('restricted Community users cannot send messages but retain Community reads and membership', async () => {
    await assertSucceeds(
      setDoc(
        messageRef(ids.member, 'open', 'before-restriction'),
        communityMessage('open', 'before-restriction', ids.member, 'Member'),
      ),
    );
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'platformRestrictions', ids.member), {
        communityChatRestricted: true,
        updatedAt: joinedAt,
      });
    });

    await assertFails(
      setDoc(
        messageRef(ids.member, 'open', 'restricted-message'),
        communityMessage('open', 'restricted-message', ids.member, 'Member'),
      ),
    );
    await assertSucceeds(getDoc(messageRef(ids.member, 'open', 'before-restriction')));
    await assertSucceeds(getDoc(memberRef(ids.member, 'open', ids.member)));
  });

  test('platform restriction does not block Private Gub chat', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'platformRestrictions', ids.member), {
        communityChatRestricted: true,
        updatedAt: joinedAt,
      });
    });
    await assertSucceeds(
      setDoc(
        doc(db(ids.member), 'gubs', 'private-gub', 'messages', 'private-message'),
        {
          messageId: 'private-message',
          gubId: 'private-gub',
          senderId: ids.member,
          senderName: 'Member',
          text: 'Private chat remains available',
          createdAt: serverTimestamp(),
        },
      ),
    );
  });

  test('clients can only get their own platform restriction and cannot mutate it', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'platformRestrictions', ids.member), {
        communityChatRestricted: true,
        updatedAt: joinedAt,
      });
    });
    const own = platformRestrictionRef(ids.member, ids.member);
    await assertSucceeds(getDoc(own));
    await assertFails(getDoc(platformRestrictionRef(ids.outsider, ids.member)));
    await assertFails(getDocs(collection(db(ids.member), 'platformRestrictions')));
    await assertFails(setDoc(platformRestrictionRef(ids.joiner, ids.joiner), {
      communityChatRestricted: true,
      updatedAt: serverTimestamp(),
    }));
    await assertFails(setDoc(own, { communityChatRestricted: false, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(own, { communityChatRestricted: false }));
    await assertFails(deleteDoc(own));
  });

  test('joiningRestricted blocks new open joins but existing members can leave', async () => {
    await assertSucceeds(joinOpenCommunity(ids.joiner, 'open'));
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'communityRestrictions', 'open'), {
        hiddenFromDiscovery: false,
        joiningRestricted: true,
        updatedAt: joinedAt,
      });
    });
    await assertFails(joinOpenCommunity(ids.outsider, 'open'));
    await assertSucceeds(leaveCommunity(ids.member, 'open'));
  });

  test('joiningRestricted blocks new and resubmitted approval requests', async () => {
    await assertSucceeds(
      setDoc(requestRef(ids.joiner, 'approval', ids.joiner), {
        userId: ids.joiner,
        displayName: 'Joiner',
        status: 'pending',
        createdAt: serverTimestamp(),
      }),
    );
    await env.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      await setDoc(doc(firestore, 'communityRestrictions', 'approval'), {
        hiddenFromDiscovery: false,
        joiningRestricted: true,
        updatedAt: joinedAt,
      });
      await setDoc(doc(firestore, 'communities', 'approval', 'joinRequests', ids.outsider), {
        userId: ids.outsider,
        displayName: 'Outsider',
        status: 'rejected',
        createdAt: joinedAt,
        resolvedAt: joinedAt,
        resolvedBy: ids.owner,
      });
    });
    await assertFails(
      setDoc(requestRef(ids.outsider, 'approval', ids.outsider), {
        userId: ids.outsider,
        displayName: 'Outsider',
        status: 'pending',
        createdAt: joinedAt,
      }),
    );
    await assertFails(
      setDoc(requestRef(ids.member, 'approval', ids.member), {
        userId: ids.member,
        displayName: 'Member',
        status: 'pending',
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('community restrictions are individually readable but never client-mutable or listable', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'communityRestrictions', 'open'), {
        hiddenFromDiscovery: true,
        joiningRestricted: true,
        updatedAt: joinedAt,
      });
    });
    const restriction = communityRestrictionRef(ids.outsider, 'open');
    await assertSucceeds(getDoc(restriction));
    await assertFails(getDocs(collection(db(ids.outsider), 'communityRestrictions')));
    await assertFails(
      setDoc(communityRestrictionRef(ids.outsider, 'new-community'), {
        hiddenFromDiscovery: true,
        joiningRestricted: true,
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(setDoc(restriction, { hiddenFromDiscovery: false }));
    await assertFails(updateDoc(restriction, { joiningRestricted: false }));
    await assertFails(deleteDoc(restriction));
  });

  test('only a Community owner can initialize safe defaults and existing restrictions remain unchanged', async () => {
    assert.equal(
      await assertSucceeds(initializeCommunityRestriction(ids.owner, 'open')),
      true,
    );
    const initial = await getDoc(communityRestrictionRef(ids.member, 'open'));
    assert.deepEqual(initial.data().hiddenFromDiscovery, false);
    assert.deepEqual(initial.data().joiningRestricted, false);
    assert.equal(
      await assertSucceeds(initializeCommunityRestriction(ids.owner, 'open')),
      false,
    );
    await assertFails(initializeCommunityRestriction(ids.member, 'approval'));

    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'communityRestrictions', 'approval'), {
        hiddenFromDiscovery: true,
        joiningRestricted: true,
        updatedAt: joinedAt,
      });
    });
    assert.equal(
      await assertSucceeds(initializeCommunityRestriction(ids.owner, 'approval')),
      false,
    );
    const existing = await getDoc(communityRestrictionRef(ids.member, 'approval'));
    assert.equal(existing.data().hiddenFromDiscovery, true);
    assert.equal(existing.data().joiningRestricted, true);
  });

  test('Community restriction initialization rejects true flags, extra fields, and Private Gub IDs', async () => {
    await assertFails(
      setDoc(communityRestrictionRef(ids.owner, 'open'), {
        hiddenFromDiscovery: true,
        joiningRestricted: false,
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      setDoc(communityRestrictionRef(ids.owner, 'open'), {
        hiddenFromDiscovery: false,
        joiningRestricted: false,
        updatedAt: serverTimestamp(),
        forged: true,
      }),
    );
    await assertFails(initializeCommunityRestriction(ids.owner, 'private-gub'));
  });

  test('new public Community creation atomically includes its safe restriction document', async () => {
    await assertSucceeds(createCommunityWithRestriction());
    const restriction = await getDoc(
      communityRestrictionRef(ids.owner, 'new-community'),
    );
    assert.equal(restriction.data().hiddenFromDiscovery, false);
    assert.equal(restriction.data().joiningRestricted, false);
  });

  test('a restriction is removable only with the final Community deletion transaction', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      await setDoc(doc(firestore, 'communityRestrictions', 'open'), {
        hiddenFromDiscovery: true,
        joiningRestricted: true,
        updatedAt: joinedAt,
      });
      await updateDoc(doc(firestore, 'communities', 'open'), {
        deletionStatus: 'deleting',
        deletionRequestedBy: ids.owner,
      });
    });

    await assertSucceeds(deleteCommunityWithRestriction('open'));
    await env.withSecurityRulesDisabled(async (context) => {
      const snapshot = await getDoc(
        doc(context.firestore(), 'communityRestrictions', 'open'),
      );
      assert.equal(snapshot.exists(), false);
    });
  });

  test('owner can mark a modern Community as deleting through the valid flow', async () => {
    const community = await seedModernCommunityForDeletion();

    await assertSucceeds(markCommunityDeleting(community.communityId));
    const root = await getDoc(communityRef(ids.owner, community.communityId));
    assert.equal(root.data().deletionStatus, 'deleting');
    assert.equal(root.data().deletionRequestedBy, ids.owner);
  });

  test('owner cannot delete only the modern Community root', async () => {
    const community = await seedModernCommunityForDeletion();
    await assertSucceeds(markCommunityDeleting(community.communityId));

    await assertFails(deleteDoc(communityRef(ids.owner, community.communityId)));
  });

  for (const linkage of ['ownership', 'slug', 'name', 'public', 'restriction']) {
    test(`owner cannot finalize a modern Community while leaving ${linkage} linkage`, async () => {
      const community = await seedModernCommunityForDeletion();
      await assertSucceeds(markCommunityDeleting(community.communityId));

      await assertFails(finalizeModernCommunityDeletion(community, { leave: [linkage] }));
    });
  }

  test('owner can atomically finalize modern Community deletion with all required linkage', async () => {
    const community = await seedModernCommunityForDeletion();
    await assertSucceeds(markCommunityDeleting(community.communityId));

    await assertSucceeds(finalizeModernCommunityDeletion(community));
    await env.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      const snapshots = await Promise.all([
        getDoc(doc(firestore, 'communities', community.communityId)),
        getDoc(doc(firestore, 'communityOwnership', ids.owner)),
        getDoc(doc(firestore, 'communitySlugs', community.slug)),
        getDoc(doc(firestore, 'communityNames', community.nameKey)),
        getDoc(doc(firestore, 'communityPublic', community.slug)),
        getDoc(doc(firestore, 'communityRestrictions', community.communityId)),
      ]);
      for (const snapshot of snapshots) assert.equal(snapshot.exists(), false);
    });
  });

  test('legacy Community without modern linkage remains deletable in the compatible final flow', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'communities', 'open'), {
        deletionStatus: 'deleting',
        deletionRequestedBy: ids.owner,
      });
    });

    await assertSucceeds(deleteDoc(communityRef(ids.owner, 'open')));
  });

  test('orphaned Community messages and members are unreadable after root deletion', async () => {
    const community = await seedModernCommunityForDeletion();
    await assertSucceeds(markCommunityDeleting(community.communityId));
    await assertSucceeds(finalizeModernCommunityDeletion(community));

    await assertFails(getDoc(messageRef(ids.member, community.communityId, 'message')));
    await assertFails(getDoc(memberRef(ids.member, community.communityId, ids.member)));
  });

  test('orphaned join requests and bans are unreadable after root deletion', async () => {
    const community = await seedModernCommunityForDeletion();
    await assertSucceeds(markCommunityDeleting(community.communityId));
    await assertSucceeds(finalizeModernCommunityDeletion(community));

    await assertFails(getDoc(requestRef(ids.member, community.communityId, ids.member)));
    await assertFails(getDoc(banRef(ids.outsider, community.communityId, ids.outsider)));
  });

  test('members and outsiders cannot exploit a Community deletion state', async () => {
    const community = await seedModernCommunityForDeletion();
    await assertSucceeds(markCommunityDeleting(community.communityId));

    await assertFails(deleteDoc(communityRef(ids.member, community.communityId)));
    await assertFails(deleteDoc(communityRef(ids.outsider, community.communityId)));
  });

  test('owner cannot delete a Community restriction independently while root remains', async () => {
    const community = await seedModernCommunityForDeletion();

    await assertFails(deleteDoc(communityRestrictionRef(ids.owner, community.communityId)));
    await assertSucceeds(markCommunityDeleting(community.communityId));
    await assertFails(deleteDoc(communityRestrictionRef(ids.owner, community.communityId)));
  });
});
