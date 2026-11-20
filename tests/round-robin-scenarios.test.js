const assert=require('node:assert/strict');
const rr=require('../round-robin-nassau.js');
const presses=require('../round-robin-presses.js');
const {settle}=require('../round-robin-settlement.js');
const players=[{id:'A',courseHandicap:8},{id:'B',courseHandicap:12},{id:'C',courseHandicap:20}];
function round(count,scoreFor){
 const holes=Array.from({length:18},(_,i)=>({number:i+1,strokeIndex:i+1,scores:i<count?scoreFor(i+1):{}}));
 return rr.calculate(players,holes);
}
// Strokes are relative to the low handicap of each individual pairing.
let [ab,ac,bc]=round(2,()=>({A:4,B:4,C:4}));
assert.deepEqual(ab.strokes,[0,4]);
assert.deepEqual(ac.strokes,[0,12]);
assert.deepEqual(bc.strokes,[0,8]);
assert.equal(ab.holes[0].winner,'B');
assert.equal(ac.holes[0].winner,'C');
assert.equal(bc.holes[0].winner,'C');
// Two-down is matchup-specific. A-B and A-C can be pressed; B-C is tied.
[ab,ac,bc]=round(2,()=>({A:3,B:5,C:6}));
assert.equal(presses.eligible(ab,'front'),true);
assert.equal(presses.eligible(ac,'front'),true);
assert.equal(presses.eligible(bc,'front'),false);
assert.equal(presses.eligible(ab,'overall'),true);
assert.equal(presses.eligible(ab,'back'),false);
// The first press starts on hole 3; no immediate re-press is allowed.
const first={segment:'front',startHole:3};
assert.equal(presses.eligible(ab,'front',[first]),false);
// Lose holes 3 and 4 in A-B: the first press is now down two and can be re-pressed.
[ab,ac,bc]=round(4,h=>h<=2?{A:3,B:5,C:6}:{A:6,B:4,C:4});
assert.equal(presses.evaluate(ab,[first])[0].lead,-2);
assert.equal(presses.eligible(ab,'front',[first]),true);
const second={segment:'front',startHole:5};
assert.equal(presses.eligible(ab,'front',[first,second]),false);
// Closing the front nine must prevent new front presses.
[ab]=round(9,()=>({A:3,B:5,C:5}));
assert.equal(presses.eligible(ab,'front'),false);
// No settlement of an incomplete scorecard, even if all bets are mathematically closed.
assert.throws(()=>settle(round(17,()=>({A:3,B:5,C:5})),{},5),/unfinished/);
console.log('Round Robin scenarios passed');
