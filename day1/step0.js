import { readFileSync } from 'fs';
// load the wasm module
const wasm = new WebAssembly.Instance(new WebAssembly.Module(readFileSync('step0.wasm')));
// run the main function and print the result
console.log(wasm.exports.main());