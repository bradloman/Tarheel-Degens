import assert from 'node:assert/strict';
import {ninesHolePoints,ninesSettlement} from './nines.js';
for (const [scores,expected] of [ [[3,4,5],[5,3,1]],[[3,4,4],[5,2,2]],[[3,3,5],[4,4,1]],[[4,4,4],[3,3,3]],[[5,3,3],[1,4,4]] ]) assert.deepEqual(ninesHolePoints(scores),expected);
for (const [totals,stake,mode,expected] of [ [[65,55,42],1,'per_point',[33,-10,-23]],[[65,55,42],20,'fixed',[40,-20,-20]],[[60,60,42],1,'per_point',[9,9,-18]],[[60,60,42],20,'fixed',[10,10,-20]],[[50,50,50],20,'fixed',[0,0,0]] ]) assert.deepEqual(ninesSettlement(totals,stake,mode),expected);
console.log('Nines tests passed');
