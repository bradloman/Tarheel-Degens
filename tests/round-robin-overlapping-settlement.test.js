const assert=require('node:assert/strict');
const rr=require('../round-robin-nassau.js');
const {settle}=require('../round-robin-settlement.js');
const players=['A','B','C'].map(id=>({id,courseHandicap:0}));
const holes=Array.from({length:18},(_,i)=>({number:i+1,strokeIndex:i+1,scores:{A:i<9?3:5,B:4,C:4}}));
const matches=rr.calculate(players,holes);
const presses={
 'A|B':[{id:'p1',segment:'front',startHole:3},{id:'p2',segment:'front',startHole:6},{id:'p3',segment:'overall',startHole:10}],
 'A|C':[{id:'p4',segment:'back',startHole:12}]
};
const result=settle(matches,presses,10);
assert.equal(result.bets.length,13,'Nine base bets plus four independent presses');
assert.deepEqual(result.totals,{A:0,B:-10,C:10});
assert.deepEqual(result.bets.filter(b=>b.type==='press').map(b=>b.amountA),[10,10,-10,-10]);
assert.equal(Object.values(result.totals).reduce((a,b)=>a+b,0),0);
assert.equal(result.bets.filter(b=>b.type==='press').length,4);
assert.equal(result.bets.filter(b=>b.type==='press'&&b.amountA<0).length,2);
assert.equal(result.bets.filter(b=>b.type==='press'&&b.amountA>0).length,2);
console.log('Overlapping independent press settlements passed');
