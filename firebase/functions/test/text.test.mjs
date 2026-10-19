import assert from 'node:assert/strict';
import test from 'node:test';

import { chatPreview, firstName, rewardNotice } from '../lib/text.js';

test('text: chat previews and notices', () => {
  assert.equal(firstName('Juan Dela Cruz'), 'Juan');
  assert.equal(firstName(''), 'Student');
  assert.equal(chatPreview('  Salamat po!  '), 'Salamat po!');
  assert.equal(chatPreview('', 'map.png'), 'Sent a file: map.png');
  assert.equal(chatPreview('x'.repeat(150)).length, 141);
  assert.equal(rewardNotice('Andrea Aquino', 'Line leader for a day', 150),
    'Andrea Aquino wants “Line leader for a day” (150 pts)');
});
