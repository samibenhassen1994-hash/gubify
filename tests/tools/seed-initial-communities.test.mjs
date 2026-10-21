import test from 'node:test';
import assert from 'node:assert/strict';

import {
  buildCommunityDocumentPlan,
  classifyExistingCommunity,
  validateExistingDocumentSet,
} from '../../tools/seed-initial-communities.mjs';
import {initialCommunityCatalog} from '../../tools/initial-community-catalog.mjs';

const owner = {
  uid: 'admin-uid',
  displayName: 'Gubify',
  photoUrl: null,
};

test('document plan contains every canonical Community projection', () => {
  const plan = buildCommunityDocumentPlan({
    community: initialCommunityCatalog[0],
    communityId: 'community-id',
    owner,
  });
  assert.deepEqual(new Set(plan.map((entry) => entry.path)), new Set([
    'communities/community-id',
    'communityNames/aibuilders',
    'communitySlugs/ai-builders',
    'communityPublic/ai-builders',
    'communityRestrictions/community-id',
    'communities/community-id/members/admin-uid',
    'users/admin-uid/communities/community-id',
    'platformAdminCommunityOwnership/admin-uid/communities/community-id',
    'communityUserProgress/admin-uid',
  ]));
});

test('matching name and slug registries are idempotently skipped', () => {
  assert.equal(classifyExistingCommunity({
    nameRegistry: {communityId: 'same', ownerId: owner.uid},
    slugRegistry: {communityId: 'same', ownerId: owner.uid},
    root: {communityId: 'same', ownerId: owner.uid, name: 'AI Builders'},
    expectedName: 'AI Builders',
    ownerId: owner.uid,
  }), 'existing');
});

test('partial or foreign collisions are rejected rather than overwritten', () => {
  assert.equal(classifyExistingCommunity({
    nameRegistry: {communityId: 'one', ownerId: owner.uid},
    slugRegistry: {communityId: 'two', ownerId: owner.uid},
    root: null,
    expectedName: 'AI Builders',
    ownerId: owner.uid,
  }), 'conflict');
  assert.equal(classifyExistingCommunity({
    nameRegistry: null,
    slugRegistry: null,
    root: null,
    expectedName: 'AI Builders',
    ownerId: owner.uid,
  }), 'new');
});

test('existing import is accepted only when every required projection exists', () => {
  const community = initialCommunityCatalog[0];
  const plan = buildCommunityDocumentPlan({
    community,
    communityId: 'community-id',
    owner,
  });
  const documents = new Map(plan.map((entry) => [entry.path, entry.data]));
  documents.set('communityUserProgress/admin-uid', {
    xp: 0,
    communityIds: ['community-id'],
  });
  assert.equal(validateExistingDocumentSet({
    documents,
    communityId: 'community-id',
    ownerId: owner.uid,
    community,
  }), true);
  documents.delete('communityRestrictions/community-id');
  assert.equal(validateExistingDocumentSet({
    documents,
    communityId: 'community-id',
    ownerId: owner.uid,
    community,
  }), false);
});
