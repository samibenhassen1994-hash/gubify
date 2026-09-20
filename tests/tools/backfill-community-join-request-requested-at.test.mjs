import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';

import {
  applyCommunityJoinRequestRequestedAtUpdates,
  executeCommunityJoinRequestRequestedAtBackfill,
  parseCommunityJoinRequestBackfillMode,
  planCommunityJoinRequestRequestedAtBackfill,
  runCommunityJoinRequestRequestedAtBackfill,
} from '../../tools/backfill-community-join-request-requested-at.mjs';

const timestamp = (milliseconds) => Timestamp.fromMillis(milliseconds);
const fakeDocument = (path, data, updateTime = timestamp(1)) => ({
  data: () => data,
  ref: { path },
  updateTime,
});

const legacyDocuments = () => {
  const firstCreatedAt = timestamp(1000);
  const secondCreatedAt = timestamp(2000);
  const currentCreatedAt = timestamp(3000);
  return {
    documents: [
      fakeDocument('communities/one/joinRequests/first', {
        createdAt: firstCreatedAt,
      }, timestamp(101)),
      fakeDocument('communities/two/joinRequests/second', {
        createdAt: secondCreatedAt,
      }, timestamp(102)),
      fakeDocument('communities/three/joinRequests/current', {
        createdAt: currentCreatedAt,
        requestedAt: currentCreatedAt,
      }, timestamp(103)),
    ],
    firstCreatedAt,
    secondCreatedAt,
  };
};

class FakeFirestore {
  constructor(documents, { beforeFirstCommit, dropWrites = false } = {}) {
    this.records = new Map(documents.map((document, index) => [
      document.ref.path,
      {
        data: { ...document.data() },
        updateTime: document.updateTime ?? timestamp(100 + index),
      },
    ]));
    this.beforeFirstCommit = beforeFirstCommit;
    this.dropWrites = dropWrites;
    this.queryLimits = [];
    this.queryGets = 0;
    this.batchSizes = [];
    this.batchPreconditions = [];
  }

  collectionGroup(name) {
    assert.equal(name, 'joinRequests');
    return new FakeQuery(this);
  }

  batch() {
    const operations = [];
    return {
      update: (reference, data, precondition) => {
        operations.push({ reference, data, precondition });
      },
      commit: async () => {
        if (this.beforeFirstCommit) {
          const callback = this.beforeFirstCommit;
          this.beforeFirstCommit = undefined;
          await callback(this);
        }

        this.batchSizes.push(operations.length);
        this.batchPreconditions.push(
          operations.map((operation) => operation.precondition),
        );
        for (const operation of operations) {
          const record = this.records.get(operation.reference.path);
          if (!record.updateTime.isEqual(operation.precondition.lastUpdateTime)) {
            throw new Error(`FAILED_PRECONDITION: ${operation.reference.path}`);
          }
        }
        if (this.dropWrites) return;

        for (const [index, operation] of operations.entries()) {
          const record = this.records.get(operation.reference.path);
          record.data = { ...record.data, ...operation.data };
          record.updateTime = timestamp(
            record.updateTime.toMillis() + index + 1,
          );
        }
      },
    };
  }

  setConcurrentRequestedAt(path, requestedAt) {
    const record = this.records.get(path);
    record.data = { ...record.data, requestedAt };
    record.updateTime = timestamp(record.updateTime.toMillis() + 1000);
  }
}

class FakeQuery {
  constructor(firestore) {
    this.firestore = firestore;
    this.pageSize = 200;
    this.cursorPath = undefined;
  }

  orderBy() {
    return this;
  }

  limit(pageSize) {
    this.pageSize = pageSize;
    this.firestore.queryLimits.push(pageSize);
    return this;
  }

  startAfter(cursor) {
    this.cursorPath = cursor.ref.path;
    return this;
  }

  async get() {
    this.firestore.queryGets += 1;
    const paths = [...this.firestore.records.keys()].sort();
    const start = this.cursorPath == null
      ? 0
      : paths.indexOf(this.cursorPath) + 1;
    const pagePaths = paths.slice(start, start + this.pageSize);
    const docs = pagePaths.map((path) => {
      const record = this.firestore.records.get(path);
      return fakeDocument(path, { ...record.data }, record.updateTime);
    });
    return { docs, empty: docs.length === 0 };
  }
}

test('planner reports the pinned legacy migration totals', () => {
  const { documents } = legacyDocuments();

  const plan = planCommunityJoinRequestRequestedAtBackfill(documents);

  assert.deepEqual(plan.summary, {
    missing: 2,
    updated: 2,
    alreadyCurrent: 1,
    invalidCreatedAt: 0,
  });
  assert.ok(plan.updates.every((update) => update.updateTime instanceof Timestamp));
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

test('apply copies createdAt exactly with an updateTime precondition and is idempotent', async () => {
  const { documents, firstCreatedAt, secondCreatedAt } = legacyDocuments();
  const writes = [];
  const updateDocument = async (reference, update, precondition) => {
    writes.push([reference.path, update.requestedAt, precondition]);
    const document = documents.find((item) => item.ref.path === reference.path);
    assert.ok(precondition.lastUpdateTime.isEqual(document.updateTime));
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
  assert.deepEqual(writes.map(([path, requestedAt]) => [path, requestedAt]), [
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

test('CLI parsing defaults safely and rejects ambiguous or unknown modes', () => {
  assert.equal(parseCommunityJoinRequestBackfillMode([]), 'dry-run');
  assert.equal(parseCommunityJoinRequestBackfillMode(['--dry-run']), 'dry-run');
  assert.equal(parseCommunityJoinRequestBackfillMode(['--apply']), 'apply');
  assert.throws(
    () => parseCommunityJoinRequestBackfillMode(['--dry-run', '--apply']),
    /Choose exactly one/,
  );
  assert.throws(
    () => parseCommunityJoinRequestBackfillMode(['--production']),
    /Unknown argument: --production/,
  );
});

test('production runner paginates, splits batches, and verifies the applied state', async () => {
  const documents = Array.from({ length: 5 }, (_, index) => fakeDocument(
    `communities/c${index}/joinRequests/u${index}`,
    { createdAt: timestamp(1000 + index) },
    timestamp(100 + index),
  ));
  documents.push(fakeDocument(
    'communities/current/joinRequests/current',
    { createdAt: timestamp(2000), requestedAt: timestamp(2000) },
    timestamp(200),
  ));
  const firestore = new FakeFirestore(documents);
  const logs = [];

  const result = await runCommunityJoinRequestRequestedAtBackfill({
    firestore,
    mode: 'apply',
    pageSize: 2,
    batchSize: 2,
    log: (message) => logs.push(message),
  });

  assert.deepEqual(result.plan, {
    missing: 5,
    updated: 5,
    alreadyCurrent: 1,
    invalidCreatedAt: 0,
  });
  assert.deepEqual(result.verification, {
    missing: 0,
    updated: 0,
    alreadyCurrent: 6,
    invalidCreatedAt: 0,
  });
  assert.deepEqual(firestore.batchSizes, [2, 2, 1]);
  assert.equal(firestore.queryGets, 8);
  assert.deepEqual(firestore.queryLimits, Array(8).fill(2));
  assert.ok(firestore.batchPreconditions.flat().every(
    (precondition) => precondition.lastUpdateTime instanceof Timestamp,
  ));
  assert.ok([...firestore.records.values()].every(
    (record) => record.data.requestedAt instanceof Timestamp,
  ));
  assert.match(logs.at(-1), /Verification: missing=0, updated=0/);
});

test('production batch aborts rather than overwriting a concurrent request cycle', async () => {
  const path = 'communities/one/joinRequests/first';
  const concurrentRequestedAt = timestamp(9000);
  const firestore = new FakeFirestore([
    fakeDocument(path, { createdAt: timestamp(1000) }, timestamp(100)),
  ], {
    beforeFirstCommit: (store) => {
      store.setConcurrentRequestedAt(path, concurrentRequestedAt);
    },
  });
  const logs = [];

  await assert.rejects(
    runCommunityJoinRequestRequestedAtBackfill({
      firestore,
      mode: 'apply',
      log: (message) => logs.push(message),
    }),
    /FAILED_PRECONDITION/,
  );

  assert.ok(
    firestore.records.get(path).data.requestedAt.isEqual(concurrentRequestedAt),
  );
  assert.equal(logs.some((message) => message.startsWith('Verification:')), false);
});

test('post-apply verification fails when planned writes are not observable', async () => {
  const path = 'communities/one/joinRequests/first';
  const firestore = new FakeFirestore([
    fakeDocument(path, { createdAt: timestamp(1000) }, timestamp(100)),
  ], { dropWrites: true });
  const logs = [];

  await assert.rejects(
    runCommunityJoinRequestRequestedAtBackfill({
      firestore,
      mode: 'apply',
      log: (message) => logs.push(message),
    }),
    /Verification failed: requestedAt backfill is incomplete/,
  );
  assert.match(logs.at(-1), /Verification: missing=1, updated=1/);
});

test('production module imports only Firebase Admin Firestore/App and Node URL APIs', async () => {
  const source = await readFile(
    new URL('../../tools/backfill-community-join-request-requested-at.mjs', import.meta.url),
    'utf8',
  );
  const imports = [...source.matchAll(/from\s+['"]([^'"]+)['"]/g)]
    .map((match) => match[1])
    .sort();

  assert.deepEqual(imports, [
    'firebase-admin/app',
    'firebase-admin/firestore',
    'node:url',
  ]);
  assert.doesNotMatch(
    source,
    /pushDeliveryEvents|pushNotifications|PUSH_(?:FANOUT|DELIVERY)_QUEUE|cloudflare|\bqueue\b/i,
  );
});

test('batch helper rejects an unsafe update without an updateTime precondition', async () => {
  const firestore = new FakeFirestore([]);
  await assert.rejects(
    applyCommunityJoinRequestRequestedAtUpdates(firestore, [{
      reference: { path: 'communities/one/joinRequests/first' },
      requestedAt: timestamp(1000),
    }]),
    /missing updateTime precondition/,
  );
});
