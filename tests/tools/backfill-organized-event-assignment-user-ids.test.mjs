import test from 'node:test';
import assert from 'node:assert/strict';
import {
  assignmentUserIdsBackfillFor,
  countOversizedLegacyEvent,
} from '../../tools/backfill-organized-event-assignment-user-ids.mjs';

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

test('backfill reports but does not rewrite assignment lists over 20', () => {
  const assignments = Array.from({ length: 21 }, (_, index) => ({
    userId: `member-${index}`,
  }));
  assert.equal(countOversizedLegacyEvent({ assignments }), 1);
  assert.equal(assignmentUserIdsBackfillFor({ assignments }), null);
  assert.equal(assignments.length, 21);
});
