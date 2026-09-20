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
    updates.push({ reference: document.ref, requestedAt: data.createdAt });
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
      await updateDocument(update.reference, { requestedAt: update.requestedAt });
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

async function readAllJoinRequests(firestore) {
  const documents = [];
  let cursor;
  while (true) {
    let query = firestore
      .collectionGroup('joinRequests')
      .orderBy(FieldPath.documentId())
      .limit(PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    documents.push(...page.docs);
    cursor = page.docs.at(-1);
  }
  return documents;
}

async function applyUpdates(firestore, updates) {
  for (let start = 0; start < updates.length; start += BATCH_SIZE) {
    const batch = firestore.batch();
    for (const update of updates.slice(start, start + BATCH_SIZE)) {
      batch.update(update.reference, { requestedAt: update.requestedAt });
    }
    await batch.commit();
  }
}

function printSummary(label, summary) {
  console.log(
    `${label}: missing=${summary.missing}, updated=${summary.updated}, `
      + `alreadyCurrent=${summary.alreadyCurrent}, invalidCreatedAt=${summary.invalidCreatedAt}`,
  );
}

async function main() {
  const mode = parseCommunityJoinRequestBackfillMode(process.argv.slice(2));
  const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
  if (!getApps().length) {
    initializeApp({ credential: applicationDefault(), projectId });
  }

  const firestore = getFirestore();
  const documents = await readAllJoinRequests(firestore);
  const plan = planCommunityJoinRequestRequestedAtBackfill(documents);
  printSummary(mode === 'apply' ? 'Planned apply' : 'Dry run', plan.summary);
  if (plan.summary.invalidCreatedAt > 0) {
    throw new Error(
      `${plan.summary.invalidCreatedAt} join request documents have invalid or missing createdAt`,
    );
  }

  if (mode === 'apply') {
    await applyUpdates(firestore, plan.updates);
    const verification = planCommunityJoinRequestRequestedAtBackfill(
      await readAllJoinRequests(firestore),
    ).summary;
    printSummary('Verification', verification);
    if (verification.missing > 0 || verification.invalidCreatedAt > 0) {
      throw new Error('Verification failed: requestedAt backfill is incomplete.');
    }
  } else {
    console.log('Dry run only. Re-run with --apply after reviewing the totals.');
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
