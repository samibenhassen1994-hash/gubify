import test from 'node:test';
import assert from 'node:assert/strict';
import { assignmentUserIdsBackfillFor } from '../../tools/backfill-organized-event-assignment-user-ids.mjs';

test('legacy Organized Event backfill is idempotent', () => {
  const assignments = [
    { userId: 'first', userName: 'First' },
    { userId: 'second', userName: 'Second' },
  ];
  assert.deepEqual(assignmentUserIdsBackfillFor({ assignments }), ['first', 'second']);
  assert.equal(assignmentUserIdsBackfillFor({
    assignments,
    assignmentUserIds: ['first', 'second'],
  }), null);
});
