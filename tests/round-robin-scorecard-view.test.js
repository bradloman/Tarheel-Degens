const assert=require('node:assert/strict');
global.RoundRobinLoader={async load(){return {
 players:[{id:'A',name:'A'},{id:'B',name:'B'},{id:'C',name:'C'}],
 holes:Array.from({length:18},(_,i)=>({scores:i===0?{A:4,B:5,C:6}:{}})),
 matches:[['A','B'],['A','C'],['B','C']].map(pair=>({
  players:pair,front:{played:1,lead:1,closed:false,remaining:8},
  back:{played:0,lead:0,closed:false,remaining:9},
  overall:{played:1,lead:1,closed:false,remaining:17},
  holes:Array.from({length:18},(_,i)=>({played:i===0,winner:i===0?pair[0]:null}))
 })),
 pressesByMatch:{'A|B':[{segment:'front',startHole:2}]}
}}};
class Node {
 constructor(tag){this.tag=tag;this.children=[];this.attributes={};this.ownerDocument=doc;this.textContent='';}
 appendChild(node){this.children.push(node);return node}
 replaceChildren(...nodes){this.children=nodes}
 setAttribute(k,v){this.attributes[k]=v}
 addEventListener(k,fn){this.click=fn}
}
const doc={createElement:tag=>new Node(tag)};
const root=new Node('div');
const {create}=require('../round-robin-scorecard-view.js');
function collect(node){return [node.textContent,...node.children.flatMap(collect)].join(' ')}
(async()=>{
 const view=create({},'m1',root);
 await view.refresh();
 assert.match(collect(root),/Active presses: front \(hole 2\)/);
 view.select(1);
 assert.match(collect(root),/A vs C/);
 assert.match(collect(root),/Active presses: $/);
 assert.equal(root.children.at(-1).children.length,19);
 console.log('Round Robin scorecard view tests passed');
})().catch(e=>{console.error(e);process.exitCode=1});
