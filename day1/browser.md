To run the result in the browser, go to https://webassembly.github.io/wabt/demo/wat2wasm/

Paste the contents of [part1.wat](part1.wat) into the WAT editor and this slightly modified version of [part1.js](part1.js) into the JS editor:

```js
// read file as raw bytes
const input = new TextEncoder().encode(`3   4
4   3
2   5
1   3
3   9
3   3
`);
// create a new WebAssembly instance with the module from the file
const wasm = new WebAssembly.Instance(wasmModule, {});
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
wasm.exports['incr-free-ptr'](4 + input.length * 4);
// call the main function with the pointer to the input
console.log(wasm.exports.main(inputPtr));
```