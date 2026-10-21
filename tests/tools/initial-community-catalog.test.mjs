import test from 'node:test';
import assert from 'node:assert/strict';

import {
  initialCommunityCatalog,
  validateInitialCommunityCatalog,
} from '../../tools/initial-community-catalog.mjs';

test('catalog contains exactly 100 valid, original Community records', () => {
  const result = validateInitialCommunityCatalog(initialCommunityCatalog);
  assert.deepEqual(result.errors, []);
  assert.equal(result.communities.length, 100);
  assert.deepEqual(result.segmentCounts, {
    global: 20,
    niche: 20,
    additional: 60,
  });
});

test('catalog rejects duplicate names and slugs', () => {
  const duplicate = [
    ...initialCommunityCatalog,
    {...initialCommunityCatalog[0], segment: 'additional'},
  ];
  const result = validateInitialCommunityCatalog(duplicate);
  assert.match(result.errors.join('\n'), /duplicate (name|slug)/i);
});

test('catalog records retain evidence and safe discoverability metadata', () => {
  for (const community of initialCommunityCatalog) {
    assert.equal(community.language, 'English');
    assert.ok(['open', 'approval'].includes(community.accessMode));
    assert.ok(community.description.length > 30);
    assert.ok(community.description.length <= 280);
    assert.ok(community.sourceUrls.length > 0);
    assert.ok(community.sourceUrls.every((url) => url.startsWith('https://')));
    const evidenceUrl = new URL(community.sourceUrls[0]);
    assert.equal(evidenceUrl.hostname, 'trends.google.com');
    assert.equal(evidenceUrl.searchParams.get('q'), community.name);
    assert.ok(['measured', 'qualitative'].includes(community.popularityBasis));
    if (community.popularityBasis === 'qualitative') {
      assert.match(community.popularityEvidence, /^Qualitative selection:/);
    }
    assert.doesNotMatch(community.description, /official community/i);
  }
});
