// One shared gross score entry path for all three Round Robin pairings.
// Save is injected by the host app; never assume a direct table write is authorized.
(function(root){
'use strict';
function create(loader,saveHole){
 if(typeof loader!=='function'||typeof saveHole!=='function')throw Error('Loader and save callback required');
 let state=null,busy=false;
 async function refresh(){state=await loader();return state;}
 async function save(holeNumber,grossByPlayer){
  if(busy)throw Error('Score save already in progress');
  if(!state)throw Error('Load match before saving');
  if(!Number.isInteger(holeNumber)||holeNumber<1||holeNumber>18)throw Error('Invalid hole');
  const ids=state.players.map(p=>p.id);
  if(ids.length!==3||new Set(ids).size!==3)throw Error('Three distinct players required');
  if(!grossByPlayer||Object.keys(grossByPlayer).length!==3||
    !ids.every(id=>Number.isInteger(grossByPlayer[id])&&grossByPlayer[id]>=1&&grossByPlayer[id]<=30))
    throw Error('All three gross scores required');
  busy=true;
  try{
   // No optimistic local score mutations. Only display data reloaded after the host confirms persistence.
   await saveHole(holeNumber,Object.fromEntries(ids.map(id=>[id,grossByPlayer[id]])));
   return await refresh();
  }finally{busy=false;}
 }
 return {refresh,save,getState:()=>state};
}
const api={create};
if(typeof module!=='undefined'&&module.exports)module.exports=api;
else root.RoundRobinScoreEntry=api;
})(typeof globalThis!=='undefined'?globalThis:this);
