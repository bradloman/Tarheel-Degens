const assert=require('node:assert/strict');
const rr=require('../round-robin-nassau.js');
const press=require('../round-robin-presses.js');
const players=['A','B','C'].map(id=>({id,courseHandicap:0}));
const holes=Array.from({length:18},(_,i)=>({number:i+1,strokeIndex:i+1,scores:{}}));
// Original A-B front Nassau is decided after hole 7 (7&2).
// Press P1 started on hole 4, and P2 on hole 6. Each remains independent.
for(let i=0;i<7;i++)holes[i].scores={A:3,B:5,C:5};
const [ab,ac,bc]=rr.calculate(players,holes);
assert.equal(ab.front.closed,true);
const rows=press.evaluate(ab,[
 {id:'P1',segment:'front',startHole:4},
 {id:'P2',segment:'front',startHole:6},
 {id:'O1',segment:'overall',startHole:5}
]);
assert.equal(rows[0].closed,true,'P1 is mathematically closed after four wins with two remaining');
assert.equal(rows[1].closed,false,'P2 remains open with two wins and two remaining');
assert.equal(rows[2].closed,false,'Overall press remains open');
assert.equal(press.eligible(ab,'front',[{segment:'front',startHole:4},{segment:'front',startHole:6}]),true,'Latest open press can be re-pressed');
assert.equal(press.eligible(ab,'overall',[{segment:'overall',startHole:5}]),true);
assert.equal(press.eligible(bc,'front'),false,'Tied B-C matchup is unaffected');
assert.equal(press.eligible(ac,'front'),false,'Closed base A-C without an open press cannot be pressed');
console.log('Independent Nassau and simultaneous press bets passed');
