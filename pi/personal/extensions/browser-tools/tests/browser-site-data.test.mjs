import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {createServer} from 'node:http';
import {createRequire} from 'node:module';
import {mkdtemp, readFile, rm, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createInterface} from 'node:readline';
const req=createRequire(new URL('../index.ts',import.meta.url));
const browserRequire=createRequire(req.resolve('pi-browser-tools/package.json'));
const {chromium}=browserRequire('playwright');
const dir=await mkdtemp(join(tmpdir(),'pi-browser-data-test-'));
const server=createServer((req,res)=>{res.writeHead(200,{'Content-Type':'text/html'});res.end('<!doctype html><body>test</body>');});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const port=server.address().port;
const cp=spawn(chromium.executablePath(),['--headless=new','--remote-debugging-port=0',`--user-data-dir=${dir}/profile`,'--no-first-run','--no-default-browser-check','--disable-default-apps','--password-store=basic','--use-mock-keychain','--remote-allow-origins=*','--no-proxy-server','--host-resolver-rules=MAP *.test 127.0.0.1'],{stdio:['ignore','ignore','pipe']});
let browser,pi;
try {
 const ws=await new Promise((resolve,reject)=>{let all='';let timer=setTimeout(()=>reject(Error('chromium timeout')),15000);cp.stderr.on('data',data=>{all+=data;const match=all.match(/DevTools listening on (ws:\/\/[^\s]+)/);if(match){clearTimeout(timer);resolve(match[1]);}});cp.on('exit',code=>reject(Error(`chromium exit ${code}: ${all}`)));});
 const endpoint=new URL(ws); await writeFile(join(dir,'endpoint.json'),JSON.stringify({httpEndpoint:`http://${endpoint.host}`,wsEndpoint:ws,pid:cp.pid}));
 browser=await chromium.connectOverCDP(`http://${endpoint.host}`,{noDefaults:true});const context=browser.contexts()[0];
 const root=await context.newPage(),sub=await context.newPage(),other=await context.newPage(),sessionOnly=await context.newPage();
 const url=(host)=>`http://${host}:${port}`;
 await root.goto(url('owner.test'));await root.evaluate(()=>{document.cookie='own=root; path=/';document.cookie='shared=root; Domain=owner.test; path=/';localStorage.setItem('key','root');sessionStorage.setItem('key','root')});
 await sub.goto(url('sub.owner.test'));await sub.evaluate(()=>{document.cookie='sub=sub; path=/';localStorage.setItem('key','sub');sessionStorage.setItem('key','sub')});
 await other.goto(url('other.test'));await other.evaluate(()=>{document.cookie='other=other; path=/';localStorage.setItem('key','other');sessionStorage.setItem('key','other')});
 await sessionOnly.goto(url('sessiononly.test'));await sessionOnly.evaluate(()=>sessionStorage.setItem('secret','session-only'));
 // An unrelated browser context must never be modified.
 const otherContext=await browser.newContext();const separate=await otherContext.newPage();await separate.goto(url('owner.test'));await separate.evaluate(()=>sessionStorage.setItem('key','separate-context'));
 await separate.evaluate((u)=>{const f=document.createElement('iframe');f.src=u;document.body.append(f)},url('sub.owner.test'));await separate.waitForTimeout(500);
 const separateFrame=separate.frames().find(f=>f.url().includes('sub.owner.test'));assert(separateFrame);await separateFrame.evaluate(()=>sessionStorage.setItem('key','separate-frame'));
 // Cross-site iframes establish two different third-party partitions.
 await other.evaluate((u)=>{const f=document.createElement('iframe');f.src=u;document.body.append(f)},url('sub.owner.test'));
 await root.evaluate((u)=>{const f=document.createElement('iframe');f.src=u;document.body.append(f)},url('other.test'));
 await other.locator('iframe').waitFor(); await root.locator('iframe').waitFor();
 await other.waitForTimeout(1000);
 const subFrame=other.frames().find(x=>x.url().includes('sub.owner.test'));
 const otherFrame=root.frames().find(x=>x.url().includes('other.test'));
 assert(subFrame && otherFrame, 'iframe pages loaded');
 await subFrame.evaluate(()=>{localStorage.setItem('partition','target');sessionStorage.setItem('partition','target')});
 await subFrame.evaluate((u)=>{const f=document.createElement('iframe');f.src=u;document.body.append(f)},url('nested.sub.owner.test'));await other.waitForTimeout(500);
 const nested=other.frames().find(f=>f.url().includes('nested.sub.owner.test'));assert(nested);await nested.evaluate(()=>sessionStorage.setItem('key','nested'));
 // Page code cannot be allowed to replace the clearing primitive.
 await root.evaluate(()=>{Storage.prototype.clear=function(){};});
 await otherFrame.evaluate(()=>{localStorage.setItem('partition','preserve');sessionStorage.setItem('partition','preserve')});
 for (const frame of [root,sub,other,subFrame,otherFrame]) {
  await frame.evaluate(()=>new Promise((resolve,reject)=>{const request=indexedDB.open('auth-db',1);request.onupgradeneeded=()=>request.result.createObjectStore('data');request.onerror=()=>reject(request.error);request.onsuccess=()=>{request.result.close();resolve()}}));
 }
 pi=spawn('pi',['-ne','-e',fileURLToPath(new URL('../index.ts',import.meta.url)),'--mode','rpc','--no-session','--offline'],{env:{...process.env,PI_BROWSER_STATE_DIR:dir},stdio:['pipe','pipe','pipe']});
 let stderr='';pi.stderr.on('data',d=>stderr+=d);
 const rl=createInterface({input:pi.stdout});const callbacks=new Map();
 rl.on('line',line=>{const msg=JSON.parse(line);const cb=callbacks.get('active');if(cb)cb(msg)});
 async function run(id,domain,confirmed,beforeConfirm){return await new Promise((resolve,reject)=>{const messages=[];const timer=setTimeout(()=>reject(Error('rpc timeout')),45000);callbacks.set('active',async msg=>{messages.push(msg);if(msg.method==='select'){assert(msg.options.includes(domain),JSON.stringify(msg.options));pi.stdin.write(JSON.stringify({type:'extension_ui_response',id:msg.id,value:domain})+'\n')}
 if(msg.method==='confirm'){if(beforeConfirm)await beforeConfirm();pi.stdin.write(JSON.stringify({type:'extension_ui_response',id:msg.id,confirmed})+'\n');}
 if(msg.id===id&&msg.type==='response'){clearTimeout(timer);callbacks.delete('active');resolve(messages)}});pi.stdin.write(JSON.stringify({id,type:'prompt',message:'/browser-data'})+'\n')})}
 const denied=await run('cancel','owner.test',false);assert(denied.some(m=>m.method==='confirm'));assert.equal(await root.evaluate(()=>localStorage.getItem('key')),'root');assert.equal((await context.cookies()).length,4);console.log('cancel leaves data intact');
 const sessionResult=await run('session','sessiononly.test',true);assert(!sessionResult.some(m=>m.notifyType==='error'),JSON.stringify(sessionResult));assert.equal(await sessionOnly.evaluate(()=>sessionStorage.getItem('secret')),null);
 const child=await run('child','sub.owner.test',true);assert(child.some(m=>m.method==='confirm' && m.message.includes('parent-domain cookies kept: 1')));assert(!child.some(m=>m.notifyType==='error'),JSON.stringify(child));
 await new Promise(r=>setTimeout(r,2000));
 assert.equal(await sub.evaluate(()=>localStorage.getItem('key')),null);assert.equal(await subFrame.evaluate(()=>localStorage.getItem('partition')),null);assert.equal(await nested.evaluate(()=>sessionStorage.getItem('key')),null);
 assert.equal((await sub.evaluate(()=>indexedDB.databases())).length,0);assert.equal((await subFrame.evaluate(()=>indexedDB.databases())).length,0);
 assert.equal(await root.evaluate(()=>localStorage.getItem('key')),'root');assert.equal((await root.evaluate(()=>indexedDB.databases())).length,1);
 assert.deepEqual((await context.cookies()).map(c=>c.name).sort(),['other','own','shared']);
 await sub.evaluate(()=>{document.cookie='sub=sub; path=/';localStorage.setItem('key','sub');sessionStorage.setItem('key','sub')});
 await subFrame.evaluate(()=>{localStorage.setItem('partition','target');sessionStorage.setItem('partition','target')});
 const done=await run('delete','owner.test',true,async()=>{await sub.evaluate(()=>{document.cookie='late=created-during-confirm; path=/'});});assert(done.some(m=>m.method==='confirm'));assert(!done.some(m=>m.notifyType==='error'),JSON.stringify(done));
 await new Promise(r=>setTimeout(r,3000));
 console.log('root',await root.evaluate(()=>({local:localStorage.getItem('key'),session:sessionStorage.getItem('key')})));
 console.log('sub',await sub.evaluate(()=>({local:localStorage.getItem('key'),session:sessionStorage.getItem('key')})));
 console.log('other',await other.evaluate(()=>({local:localStorage.getItem('key'),session:sessionStorage.getItem('key')})));
 console.log('frames',await subFrame.evaluate(()=>({local:localStorage.getItem('partition'),session:sessionStorage.getItem('partition')})),await otherFrame.evaluate(()=>({local:localStorage.getItem('partition'),session:sessionStorage.getItem('partition')})));
 console.log('cookie domains',(await context.cookies()).map(c=>c.domain));
 assert.equal(await root.evaluate(()=>localStorage.getItem('key')),null);assert.equal(await root.evaluate(()=>sessionStorage.getItem('key')),null);
 assert.equal(await sub.evaluate(()=>localStorage.getItem('key')),null);assert.equal(await sub.evaluate(()=>sessionStorage.getItem('key')),null);
 assert.equal(await subFrame.evaluate(()=>localStorage.getItem('partition')),null);assert.equal(await subFrame.evaluate(()=>sessionStorage.getItem('partition')),null);
 assert.equal((await root.evaluate(()=>indexedDB.databases())).length,0);
 assert.equal(await other.evaluate(()=>localStorage.getItem('key')),'other');assert.equal(await other.evaluate(()=>sessionStorage.getItem('key')),'other');assert.equal(await otherFrame.evaluate(()=>localStorage.getItem('partition')),'preserve');assert.equal((await other.evaluate(()=>indexedDB.databases())).length,1);assert.equal((await otherFrame.evaluate(()=>indexedDB.databases())).length,1);assert.deepEqual((await context.cookies()).map(c=>c.domain),['other.test']);
 assert.equal(await separate.evaluate(()=>sessionStorage.getItem('key')),'separate-context');assert.equal(await separateFrame.evaluate(()=>sessionStorage.getItem('key')),'separate-frame');await otherContext.close();
 console.log('PASS');
}finally{
 if(pi){pi.stdin.end();if(pi.exitCode===null)await new Promise(resolve=>pi.once('exit',resolve));}
 if(browser)await browser.close();
 if(cp.exitCode===null){cp.kill('SIGTERM');await new Promise(resolve=>cp.once('exit',resolve));}server.close();await rm(dir,{recursive:true,force:true});
}
