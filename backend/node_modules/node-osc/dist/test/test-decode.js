'use strict';

var tap = require('tap');
var decode = require('#decode');

tap.test('decode: valid', (t) => {
  const buf = Buffer.from('/test\0\0\0,s\0,testing\0');
  t.same(decode(buf), ['/test', 'testing'], 'should be empty array');
  t.end();
});

tap.test('decode: valid', (t) => {
  const buf = Buffer.from('/test\0\0\0,s\0,testing\0');
  t.same(decode(buf), ['/test', 'testing'], 'should be empty array');
  t.end();
});

tap.test('decode: malformed packet', (t) => {
  t.throws(() => {
    const buf = Buffer.from('/test\0\0');
    decode(buf);
  }, /Malformed Packet/);
  t.end();
});

tap.test('decode: invalid typetags', (t) => {
  t.throws(() => {
    const buf = Buffer.from('/test\0\0\0,R\0');
    decode(buf);
  }, /I don't understand the argument code R/);
  t.end();
});
