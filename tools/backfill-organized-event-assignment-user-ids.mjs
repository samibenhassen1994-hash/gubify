import { applicationDefault, getApps, initializeApp } from 'firebase-admin/app';
import { FieldPath, getFirestore } from 'firebase-admin/firestore';
import { pathToFileURL } from 'node:url';

export function assignmentUserIdsBackfillFor(data) {
  const assignments = data.assignments;
  if (!Array.isArray(assignments)) return null;
  const assignmentUserIds = assignments.map((assignment) => assignment?.userId);
  if (assignmentUserIds.some((userId) => typeof userId !== 'string')) return null;
  const current = data.assignmentUserIds;
  if (Array.isArray(current)
    && current.length === assignmentUserIds.length
    && current.every((userId, index) => userId === assignmentUserIds[index])) {
    return null;
  }
  return assignmentUserIds;
}

async function main() {
  const apply = process.argv.includes('--apply');
  const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;

  if (!getApps().length) {
    initializeApp({ credential: applicationDefault(), projectId });
  }

  const firestore = getFirestore();
  const pageSize = 200;
  let cursor;
  let scanned = 0;
  let changed = 0;

  while (true) {
    let query = firestore
      .collectionGroup('organizedEvents')
      .orderBy(FieldPath.documentId())
      .limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;

    const updates = [];
    for (const document of page.docs) {
      scanned += 1;
      const assignmentUserIds = assignmentUserIdsBackfillFor(document.data());
      if (assignmentUserIds) updates.push([document.ref, assignmentUserIds]);
    }

    changed += updates.length;
    if (apply && updates.length) {
      const batch = firestore.batch();
      for (const [reference, assignmentUserIds] of updates) {
        batch.update(reference, { assignmentUserIds });
      }
      await batch.commit();
    }
    cursor = page.docs.at(-1);
  }

  console.log(`${apply ? 'Updated' : 'Would update'} ${changed} of ${scanned} Organized Events.`);
  if (!apply) console.log('Dry run only. Re-run with --apply after reviewing the count.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
