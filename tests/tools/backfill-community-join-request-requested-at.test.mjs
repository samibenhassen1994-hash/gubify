import assert from 'node:assert/strict';
import test from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';

import {
  executeCommunityJoinRequestRequestedAtBackfill,
  planCommunityJoinRequestRequestedAtBackfill,
} from '../../tools/backfill-community-join-request-requested-at.mjs';

const timestamp = (milliseconds) => Timestamp.fromMillis(milliseconds);
const fakeDocument = (path, data) => ({
  data: () => data,
  ref: { path },
});

const legacyDocuments = () => {
  const firstCreatedAt = timestamp(1000);
  const secondCreatedAt = timestamp(2000);
  const currentCreatedAt = timestamp(3000);
  return {
    documents: [
      fakeDocument('communities/one/joinRequests/first', {
        createdAt: firstCreatedAt,
      }),
      fakeDocument('communities/two/joinRequests/second', {
        createdAt: secondCreatedAt,
      }),
      fakeDocument('communities/three/joinRequests/current', {
        createdAt: currentCreatedAt,
        requestedAt: currentCreatedAt,
      }),
    ],
    firstCreatedAt,
    secondCreatedAt,
  };
};

test('planner reports the pinned legacy migration totals', () => {
  const { documents } = legacyDocuments();

  const plan = planCommunityJoinRequestRequestedAtBackfill(documents);

  assert.deepEqual(plan.summary, {
    missing: 2,
    updated: 2,
    alreadyCurrent: 1,
    invalidCreatedAt: 0,
  });
});

test('dry-run plans updates without performing writes', async () => {
  const { documents } = legacyDocuments();
  const writes = [];

  const summary = await executeCommunityJoinRequestRequestedAtBackfill({
    documents,
    apply: false,
    updateDocument: async (...args) => writes.push(args),
  });

  assert.deepEqual(summary, {
    missing: 2,
    updated: 2,
    alreadyCurrent: 1,
    invalidCreatedAt: 0,
  });
  assert.deepEqual(writes, []);
});

test('apply copies createdAt exactly and a second apply is a no-op', async () => {
  const { documents, firstCreatedAt, secondCreatedAt } = legacyDocuments();
  const writes = [];
  const updateDocument = async (reference, update) => {
    writes.push([reference.path, update.requestedAt]);
    const document = documents.find((item) => item.ref.path === reference.path);
    const previousData = document.data();
    document.data = () => ({ ...previousData, ...update });
  };

  const first = await executeCommunityJoinRequestRequestedAtBackfill({
    documents,
    apply: true,
    updateDocument,
  });
  const second = await executeCommunityJoinRequestRequestedAtBackfill({
    documents,
    apply: true,
    updateDocument,
  });

  assert.deepEqual(first, {
    missing: 2,
    updated: 2,
    alreadyCurrent: 1,
    invalidCreatedAt: 0,
  });
  assert.deepEqual(second, {
    missing: 0,
    updated: 0,
    alreadyCurrent: 3,
    invalidCreatedAt: 0,
  });
  assert.deepEqual(writes, [
    ['communities/one/joinRequests/first', firstCreatedAt],
    ['communities/two/joinRequests/second', secondCreatedAt],
  ]);
});

test('invalid or missing createdAt fails verification before writes', async () => {
  const writes = [];
  const documents = [
    fakeDocument('communities/one/joinRequests/missing', {}),
    fakeDocument('communities/two/joinRequests/invalid', {
      createdAt: 'not-a-timestamp',
    }),
  ];

  await assert.rejects(
    executeCommunityJoinRequestRequestedAtBackfill({
      documents,
      apply: true,
      updateDocument: async (...args) => writes.push(args),
    }),
    /2 join request documents have invalid or missing createdAt/,
  );
  assert.deepEqual(writes, []);
});

test('execution has no push or queue dependency', async () => {
  const { documents } = legacyDocuments();
  const firestoreOnlyDependency = new Proxy(
    { updateDocument: async () => {} },
    {
      get(target, property) {
        if (!(property in target)) {
          throw new Error(`Unexpected external dependency: ${String(property)}`);
        }
        return target[property];
      },
    },
  );

  await executeCommunityJoinRequestRequestedAtBackfill({
    documents,
    apply: false,
    updateDocument: firestoreOnlyDependency.updateDocument,
  });
});
