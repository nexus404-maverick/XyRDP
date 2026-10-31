import {test} from 'node:test';import assert from 'node:assert/strict';
import {requirePortmapConfiguration} from '../src/lib/access-options';import {defaults,choices} from '../src/lib/workflow';
const ctx={repo:'owner/test',token:'synthetic',subject:'admin',kind:'admin' as const};
test('Sunshine is the only configured access mode and requires no provider secret',async()=>{assert.equal(defaults.akses,'sunshine');assert.deepEqual(choices.akses,['sunshine']);let reads=0;const old=fetch;try{globalThis.fetch=async()=>{reads++;return Response.json({message:'Not Found'},{status:404})};await requirePortmapConfiguration(ctx,{akses:'sunshine'});assert.equal(reads,0);}finally{globalThis.fetch=old}});
