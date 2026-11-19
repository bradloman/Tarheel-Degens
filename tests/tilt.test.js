// Run with: node tests/tilt.test.js
const assert = require('node:assert/strict');
const tilt = require('../tilt.js');
assert.deepEqual([2,1,0,-1,-2,-3].map(tilt.basePoints),[-4,0,2,4,8,16]);
const round = tilt.scoreRound([
  {gross:4,par:4,strokesReceived:1}, // birdie: 4, next 2x
  {gross:3,par:4,strokesReceived:0}, // birdie: 8, next 3x
  {gross:6,par:4,strokesReceived:0}, // double: -12, reset
  {gross:4,par:4,strokesReceived:0}, // par: 2
  {gross:2,par:4,strokesReceived:0}, // eagle: 8, next 3x
  {gross:4,par:4,strokesReceived:0}  // par: 6
]);
assert.deepEqual(round.holes.map(h=>h.points),[4,8,-12,2,8,6]);
assert.equal(round.points,16);
assert.equal(round.nextMultiplier,1);
assert.equal(tilt.nextMultiplier(-2,2),4);
assert.equal(tilt.scoreRound([{gross:4,par:4,strokesReceived:1},{gross:null,par:4},{gross:3,par:4}]).holes[2].pending,true);
const players=Array.from({length:12},(_,i)=>({id:'p'+i,name:'Golfer '+i}));
const groups=[players.slice(0,4).map(p=>p.id),players.slice(4,8).map(p=>p.id),players.slice(8,12).map(p=>p.id)];
for (const size of [2,3,4]) {
 const teams=Array.from({length:12/size},(_,i)=>players.slice(i*size,(i+1)*size).map(p=>p.id));
 assert.equal(tilt.validateGroups(players,groups,teams,size),true);
 const scores=Object.fromEntries(players.map(p=>[p.id,[{gross:4,par:4,strokesReceived:0}]]));
 const board=tilt.leaderboard(players,scores,teams);
 assert.equal(board.individual.length,12);
 assert.equal(board.teams.length,12/size);
 assert.equal(board.teams[0].points,2*size);
}
assert.throws(()=>tilt.validateGroups(players,[groups[0],groups[1],groups[1]],null),/exactly one/);
console.log('Tilt scoring and team validation tests passed');
