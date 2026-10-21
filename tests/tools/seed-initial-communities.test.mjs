import test from 'node:test';
import assert from 'node:assert/strict';

import {
  buildCommunityDocumentPlan,
  classifyExistingCommunity,
  executePreflightedSeed,
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

test('existing progress keeps non-zero XP across multiple Community plans', () => {
  const storedProgress = {xp: 875, bestAnswerCount: 12};
  const plans = [0, 1].map((index) => buildCommunityDocumentPlan({
    community: initialCommunityCatalog[index],
    communityId: `community-${index}`,
    owner,
    progressExists: true,
  }));
  for (const plan of plans) {
    const progress = plan.find((entry) => entry.path === 'communityUserProgress/admin-uid');
    assert.equal(progress.merge, true);
    assert.equal(Object.hasOwn(progress.data, 'xp'), false);
    Object.assign(storedProgress, progress.data);
  }
  assert.equal(storedProgress.xp, 875);
  assert.equal(storedProgress.bestAnswerCount, 12);
});

test('missing progress initializes XP exactly once', () => {
  const plan = buildCommunityDocumentPlan({
    community: initialCommunityCatalog[0],
    communityId: 'community-id',
    owner,
    progressExists: false,
  });
  const progress = plan.find((entry) => entry.path === 'communityUserProgress/admin-uid');
  assert.equal(progress.data.xp, 0);
});

test('apply preflight blocks every write when any initial conflict exists', async () => {
  const created = [];
  await assert.rejects(
    executePreflightedSeed({
      catalog: initialCommunityCatalog.slice(0, 3),
      apply: true,
      inspect: async (community) => community.slug === initialCommunityCatalog[2].slug
        ? 'conflict'
        : 'new',
      create: async (community) => created.push(community.slug),
    }),
    (error) => error.message === 'Catalog conflicts require review.'
      && error.report.conflicts === 1,
  );
  assert.deepEqual(created, []);
});

test('apply writes only new records after a clean complete preflight', async () => {
  const created = [];
  const catalog = initialCommunityCatalog.slice(0, 3);
  const report = await executePreflightedSeed({
    catalog,
    apply: true,
    inspect: async (community) => community.slug === catalog[0].slug
      ? 'existing'
      : 'new',
    create: async (community) => created.push(community.slug),
  });
  assert.deepEqual(created, [catalog[1].slug, catalog[2].slug]);
  assert.deepEqual(report, {
    scanned: 3,
    wouldCreate: 2,
    existing: 1,
    conflicts: 0,
    created: 2,
  });
});

test('retry after interruption skips completed records without duplicates', async () => {
  const catalog = initialCommunityCatalog.slice(0, 3);
  const stored = new Set();
  let attempts = 0;
  await assert.rejects(executePreflightedSeed({
    catalog,
    apply: true,
    inspect: async (community) => stored.has(community.slug) ? 'existing' : 'new',
    create: async (community) => {
      attempts += 1;
      if (attempts === 2) throw new Error('interrupted');
      stored.add(community.slug);
    },
  }), /interrupted/);
  const report = await executePreflightedSeed({
    catalog,
    apply: true,
    inspect: async (community) => stored.has(community.slug) ? 'existing' : 'new',
    create: async (community) => stored.add(community.slug),
  });
  assert.equal(stored.size, 3);
  assert.equal(report.existing, 1);
  assert.equal(report.created, 2);
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
