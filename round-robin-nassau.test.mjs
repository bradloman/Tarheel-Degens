import test from 'node:test';
import assert from 'node:assert/strict';
import {roundRobinPairs, roundRobinNetScores, roundRobinSegmentStatus, ROUND_ROBIN_SEGMENTS} from './round-robin-nassau.js';

test('three players produce exactly three independent matchups', () => {
  const pairs = roundRobinPairs([{id:'A'},{id:'B'},{id:'C'}]);
  assert.deepEqual(pairs.map(p=>p.playerIds), [['A','B'],['A','C'],['B','C']]);
  assert.equal(new Set(pairs.map(p=>p.key)).size, 3);
  assert.equal(ROUND_ROBIN_SEGMENTS.length * pairs.length, 9);
});
test('reject invalid rosters', () => {
  assert.throws(()=>roundRobinPairs([{id:'A'},{id:'B'}]));
  assert.throws(()=>roundRobinPairs([{id:'A'},{id:'A'},{id:'C'}]));
});
test('net scores use lowest course handicap across all three players', () => {
  const players=[{id:'A',courseHandicap:10},{id:'B',courseHandicap:13},{id:'C',courseHandicap:29}];
  assert.deepEqual(roundRobinNetScores(players,{A:4,B:5,C:6},2),{A:4,B:4,C:4});
  assert.deepEqual(roundRobinNetScores(players,{A:4,B:5,C:6},4),{A:4,B:5,C:5});
});
test('match closes when lead exceeds remaining holes', () => {
  const pair={playerIds:['A','B']}, net={};
  for(let h=1;h<=6;h++) net[h]={A:4,B:5};
  assert.deepEqual(roundRobinSegmentStatus(pair,net,1,9),{lead:6,played:6,lastHole:6,remaining:3,closed:true});
});
test('incomplete hole does not count',()=>{
  const pair={playerIds:['A','B']};
  assert.deepEqual(roundRobinSegmentStatus(pair,{1:{A:4,B:4},2:{A:3}},1,9),{lead:0,played:1,lastHole:1,remaining:8,closed:false});
});
