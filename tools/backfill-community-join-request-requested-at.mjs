import { applicationDefault, getApps, initializeApp } from 'firebase-admin/app';
import { FieldPath, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { pathToFileURL } from 'node:url';

const PAGE_SIZE = 200;
const BATCH_SIZE = 400;

function isTimestamp(value) {
  return value instanceof Timestamp;
}

export function planCommunityJoinRequestRequestedAtBackfill(documents) {
  const updates = [];
  let missing = 0;
  let alreadyCurrent = 0;
  let invalidCreatedAt = 0;

  for (const document of documents) {
    const data = document.data();
    if (data.requestedAt != null) {
      alreadyCurrent += 1;
      continue;
    }

    missing += 1;
    if (!isTimestamp(data.createdAt)) {
      invalidCreatedAt += 1;
      continue;
    }
    updates.push({
      reference: document.ref,
      requestedAt: data.createdAt,
      updateTime: document.updateTime,
    });
  }

  return {
    updates,
    summary: {
      missing,
      updated: updates.length,
      alreadyCurrent,
      invalidCreatedAt,
    },
  };
}

export async function executeCommunityJoinRequestRequestedAtBackfill({
  documents,
  apply,
  updateDocument,
}) {
  const plan = planCommunityJoinRequestRequestedAtBackfill(documents);
  if (plan.summary.invalidCreatedAt > 0) {
    throw new Error(
      `${plan.summary.invalidCreatedAt} join request documents have invalid or missing createdAt`,
    );
  }

  if (apply) {
    for (const update of plan.updates) {
      if (!isTimestamp(update.updateTime)) {
        throw new Error(
          `Join request ${update.reference.path} is missing updateTime precondition`,
        );
      }
      await updateDocument(
        update.reference,
        { requestedAt: update.requestedAt },
        { lastUpdateTime: update.updateTime },
      );
    }
  }
  return plan.summary;
}

export function parseCommunityJoinRequestBackfillMode(args) {
  const knownArguments = new Set(['--dry-run', '--apply']);
  const unknown = args.filter((argument) => !knownArguments.has(argument));
  if (unknown.length > 0) {
    throw new Error(`Unknown argument: ${unknown.join(', ')}`);
  }
  if (args.includes('--dry-run') && args.includes('--apply')) {
    throw new Error('Choose exactly one of --dry-run or --apply.');
  }
  return args.includes('--apply') ? 'apply' : 'dry-run';
}

export async function readAllCommunityJoinRequests(
  firestore,
  pageSize = PAGE_SIZE,
) {
  const documents = [];
  let cursor;
  while (true) {
    let query = firestore
      .collectionGroup('joinRequests')
      .orderBy(FieldPath.documentId())
      .limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    documents.push(...page.docs);
    cursor = page.docs.at(-1);
  }
  return documents;
}

export async function applyCommunityJoinRequestRequestedAtUpdates(
  firestore,
  updates,
  batchSize = BATCH_SIZE,
) {
  for (const update of updates) {
    if (!isTimestamp(update.updateTime)) {
      throw new Error(
        `Join request ${update.reference.path} is missing updateTime precondition`,
      );
    }
  }

  for (let start = 0; start < updates.length; start += batchSize) {
    const batch = firestore.batch();
    for (const update of updates.slice(start, start + batchSize)) {
      batch.update(
        update.reference,
        { requestedAt: update.requestedAt },
        { lastUpdateTime: update.updateTime },
      );
    }
    await batch.commit();
  }
}

function printSummary(label, summary, log) {
  log(
    `${label}: missing=${summary.missing}, updated=${summary.updated}, `
      + `alreadyCurrent=${summary.alreadyCurrent}, invalidCreatedAt=${summary.invalidCreatedAt}`,
  );
}

export async function runCommunityJoinRequestRequestedAtBackfill({
  firestore,
  mode,
  pageSize = PAGE_SIZE,
  batchSize = BATCH_SIZE,
  log = console.log,
}) {
  const documents = await readAllCommunityJoinRequests(firestore, pageSize);
  const plan = planCommunityJoinRequestRequestedAtBackfill(documents);
  printSummary(mode === 'apply' ? 'Planned apply' : 'Dry run', plan.summary, log);
  if (plan.summary.invalidCreatedAt > 0) {
    throw new Error(
      `${plan.summary.invalidCreatedAt} join request documents have invalid or missing createdAt`,
    );
  }

  if (mode !== 'apply') {
    log('Dry run only. Re-run with --apply after reviewing the totals.');
    return { plan: plan.summary, verification: null };
  }

  await applyCommunityJoinRequestRequestedAtUpdates(
    firestore,
    plan.updates,
    batchSize,
  );
  const verification = planCommunityJoinRequestRequestedAtBackfill(
    await readAllCommunityJoinRequests(firestore, pageSize),
  ).summary;
  printSummary('Verification', verification, log);
  if (verification.missing > 0 || verification.invalidCreatedAt > 0) {
    throw new Error('Verification failed: requestedAt backfill is incomplete.');
  }
  return { plan: plan.summary, verification };
}

async function main() {
  const mode = parseCommunityJoinRequestBackfillMode(process.argv.slice(2));
  const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
  if (!getApps().length) {
    initializeApp({ credential: applicationDefault(), projectId });
  }

  const firestore = getFirestore();
  await runCommunityJoinRequestRequestedAtBackfill({ firestore, mode });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
