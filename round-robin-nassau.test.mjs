import test from 'node:test';
import assert from 'node:assert/strict';
import {roundRobinPairs, roundRobinNetScores, roundRobinSegmentStatus, ROUND_ROBIN_SEGMENTS, roundRobinCanPress, roundRobinAllStandings, roundRobinPressStatus} from './round-robin-nassau.js';

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

test('only the player two down may press, beginning next hole',()=>{
 const pair={key:'A:B',playerIds:['A','B']}, net={1:{A:5,B:4},2:{A:5,B:4}};
 const segment=ROUND_ROBIN_SEGMENTS[0];
 assert.equal(roundRobinCanPress(pair,net,segment,'A'),true);
 assert.equal(roundRobinCanPress(pair,net,segment,'B'),false);
 assert.equal(roundRobinCanPress(pair,net,segment,'A',[{calledBy:'A',segment:'F',startHole:3}]),false);
});
test('press status starts at next hole, independent of original bet',()=>{
 const pair={key:'A:B',playerIds:['A','B']}, net={1:{A:5,B:4},2:{A:5,B:4},3:{A:4,B:5}};
 const press={pairKey:'A:B',segment:'F',calledBy:'A',startHole:3};
 assert.equal(roundRobinPressStatus(pair,net,press,ROUND_ROBIN_SEGMENTS[0]).lead,1);
 const standings=roundRobinAllStandings([{id:'A'},{id:'B'},{id:'C'}],net,[press]);
 assert.equal(standings[0].segments[0].presses.length,1);
 assert.equal(standings[1].segments[0].presses.length,0);
 assert.equal(standings[2].segments[0].presses.length,0);
});
