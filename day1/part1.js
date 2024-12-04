import { readFileSync, writeFileSync } from 'fs';
// read file as raw bytes
const input = readFileSync('input.txt');
// create a new WebAssembly instance with the module from the file
const wasm = new WebAssembly.Instance(new WebAssembly.Module(readFileSync('part1.wasm')));
// we need two buffers, because we will write the string length as a uint32 and the string itself as bytes (uint8)
// get memory buffer as Uint8Array
const memory = new Uint8Array(wasm.exports.memory.buffer);
// get memory buffer as Uint32Array
const memory32 = new Uint32Array(wasm.exports.memory.buffer);
// get free memory pointer
const inputPtr = wasm.exports['get-free-ptr']();
// write the length of the input as first 4 bytes
memory32[inputPtr] = input.length;
// write input to memory
memory.set(input, inputPtr + 4);
// update free memory pointer
wasm.exports['incr-free-ptr'](4 + input.length);
// call the main function with the pointer to the input
console.log(wasm.exports.main(inputPtr));
// write memory to file
writeFileSync('output.bin', memory.slice(0, wasm.exports['get-free-ptr']()));