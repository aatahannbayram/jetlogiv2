import assert from 'node:assert/strict';
import { test } from 'node:test';

import { dialableFromStored } from '../src/services/masked-call.js';

test('dialableFromStored: E.164 ve TR biçimleri', () => {
  assert.equal(dialableFromStored('+905321110026'), '+905321110026');
  assert.equal(dialableFromStored('0532 111 00 26'), '+905321110026');
  assert.equal(dialableFromStored('5321110026'), '+905321110026');
  assert.equal(dialableFromStored('905321110026'), '+905321110026');
});

test('dialableFromStored: şifre yer tutucusu ve kısa değer yok sayılır', () => {
  assert.equal(dialableFromStored('dev-placeholder'), null);
  assert.equal(dialableFromStored(''), null);
  assert.equal(dialableFromStored(null), null);
  assert.equal(dialableFromStored('123'), null);
});
