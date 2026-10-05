import Wire from './wire.bend';
import {wireDecoder} from '../../src/web/wire.js';
const list = xs => {const out=[];for(;xs.$==='Con';xs=xs.tail)out.push(xs.head);return out};
const decode = wireDecoder(list(Wire.keys()), list(Wire.words()), Wire.rules(), Wire.key_text);
const output = document.querySelector('pre');
output.textContent = 'Waiting for the current hub history…';
const started = performance.now();
const ws = new WebSocket(`${location.protocol==='https:'?'wss:':'ws:'}//${location.host}/ws?enc=cbor`);
ws.binaryType = 'arraybuffer';
ws.onmessage = e => {
  ws.close(); ws.onmessage = null;
  const bytes = new Uint8Array(e.data), arrival = performance.now()-started;
  output.textContent = 'Measuring current history…';
  setTimeout(() => {
    let at=performance.now(); const fast=decode(bytes); const bufferMs=performance.now()-at;
    at=performance.now();let xs={$:'Nil'};for(let i=bytes.length-1;i>=0;i--)xs={$:'Con',head:bytes[i],tail:xs};
    const json=Wire.decode(xs);const old=JSON.parse(Wire.show(json));const oldMs=performance.now()-at;
    const results={bytes:bytes.length,arrivalMs:Math.round(arrival),events:fast.value?.items?.length,
      bufferMs:Math.round(bufferMs),oldMs:Math.round(oldMs),
      equal:JSON.stringify(old)===JSON.stringify(fast.value)};
    output.textContent=JSON.stringify(results,null,2);
    globalThis.startupBench=results;
  },50);
};
