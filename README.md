# Advent of Code 2024 in pure handwritten WebAssembly

This year I will be solving [AoC](https://adventofcode.com/) in pure handwritten WebAssembly. Inputs will be loaded directly into memory as raw ASCII-encoded bytes and solutions will be printed to the console. Everything in between will be implemented entirely in WebAssembly. I am doing this to dive deeper into WebAssembly and get a better understanding of low level programming and memory management.

- [Day 1, Part 1](#day-1-part-1)
- [0. Output the result](#0-output-the-result)
- [1. Sum up the absolute differences](#1-sum-up-the-absolute-differences)
- [2. Calculate the absolute differences of the input](#2-calculate-the-absolute-differences-of-the-input)
- [Step 3. Sorting the vectors](#step-3-sorting-the-vectors)
- [Step 4. Parsing the input and computing the result](#step-4-parsing-the-input-and-computing-the-result)
- [Final Code](day1/part1.wat)

[Try it in your browser](day1/browser.md)

## Day 1, Part 1

In [day 1](https://adventofcode.com/2024/day/1) we are given an input *like* this (The [rules](https://adventofcode.com/about#faq_copying) do not allow me to post the actual example input):

```
4   3
2   5
3   4
3   3
1   3
3   9
```

Our goal is to sort the left and right columns and then sum up the absolute differences between corresponding numbers. In this example the result would be `abs(1-3)+abs(2-3)+abs(3-3)+abs(3-4)+abs(3-5)+abs(4-9) = 11`

Sounds easy? It's not. We have to parse the text input, implement a sorting algorithm from scratch, even our own representation of strings and vectors in memeory.

This might seem overwhelming, so to keep it simple for the beginning, let's start from the end and work our way back:

## 0. Output the result

Well, we know, that for our example the result is 11, so how do we output it? We need the wasm code and the host code to run it. The wasm code will be written in a text file with the extension `.wat` and then compiled to a binary `.wasm` file. The host code will be written with the extension `.js` and run in node.js. We will use the es6 import style, because it looks nicer, so we will also need a `package.json` file.

[step0.wat](day1/step0.wat):
```wat
(module
	(func $main
		(export "main")
		(result i32)
		(i32.const 11) ;; return 11
	)
)
```

compile it with `wat2wasm step0.wat` and it will create a `step0.wasm` file.

[step0.js](day1/step0.js):
```js
import { readFileSync } from 'fs';
// load the wasm module
const wasm = new WebAssembly.Instance(new WebAssembly.Module(readFileSync('step0.wasm')));
// run the main function and print the result
console.log(wasm.exports.main());
```

package.json:

```json
{
	"type": "module"
}
```

run it with `node step0.js`

This will output `11` to the console. Yeay!

## 1. Sum up the absolute differences

Ok, unfortunately it gets difficult quickly. Suppose, we magically had a list of absolute differences. What does this even mean? WebAssembly has no concept of lists. So we somehow need to represent a list of integers in memory. We will call them `vector` from now on. We also do not know the length of the vector beforehand, because the actual puzzle input is much longer than the example input. One way to do it, is to store the length of the vector at the beginning of the memory followed by the elements.
So let's create a vector with the length 3 and elements 1 2 3.

```wat
(module
	(memory (export "memory") 1 1) ;; 1 page initial (= 64 KiB), 1 page max, because 64 KiB is plenty for now
	(func $main
		(export "main")
		(result i32)
		;; store the length of the vector at the beginning of the memory
		;; the "address" of the vector in memory is 0, it points to it's length
		(i32.store (i32.const 0) (i32.const 3))
		;; store the elements of the vector
		(i32.store (i32.const 4) (i32.const 1)) ;; 4, because the size of i32 is 4 bytes
		(i32.store (i32.const 8) (i32.const 2))
		(i32.store (i32.const 12) (i32.const 3))

		;; let's return the length of the vector:
		(i32.load (i32.const 0))

		;; this would return the second element of the vector:
		;; (i32.load (i32.const 8))
		;; in general, to return the nth element of the vector we load the address (vectorPointer + 4 + 4 * n)
	)
)
```

now after `wat2wasm part1.wat` and `node part1.js` it should output `3`. Cool.

Now let's implement a function that calculates the sum of a vector, given it's address pointer. We will need something like a for loop, which is implemented with a block and a loop inside it. To break out of the for loop, we break to the block label, to continue the for loop, we break to the loop label.

Let's also add a convenience function to get the nth element of a vector at memory location `vectorPointer + 4 + 4 * n`.

Then let's output the sum of the absolute diffs of the sample input [2, 1, 0, 1, 2, 5].

[step1.wat](day1/step1.wat):

```wat
(module
	(memory (export "memory") 1 1) ;; 1 page initial (= 64 KiB), 1 page max, because 64 KiB is plenty for now
	(func $vector-nth (export "vector-nth") (param $ptr i32) (param $n i32) (result i32)
		(i32.load
			(i32.add
				(i32.const 4) ;; skip the length
				(i32.add
					(local.get $ptr)
					(i32.mul
						(local.get $n) ;; nth element
						(i32.const 4) ;; 4 bytes per element
					)
				)
			)
		)
	)
	(func $vector-sum (export "vector-sum") (param $ptr i32) (result i32)
		;; receive a memory location as uint32
		;; read the uint32 at that location
		;; it's the length of a vector
		;; sum the elements of the vector
		;; return the sum as uint32
		(local $len i32)
		(local $sum i32)
		(local $i i32)
		(local.set $len (i32.load (local.get $ptr)))
		;; for(i = 0; i < len; i++)
		(block $block1
			(loop $loop2
				;; if i == len, break
				(br_if $block1
					(i32.eq
						(local.get $i)
						(local.get $len)
					)
				)
				;; sum += ptr[i]
				(local.set $sum (i32.add
					(local.get $sum)
					(call $vector-nth (local.get $ptr) (local.get $i))
				))
				;; i++
				(local.set $i (i32.add
					(local.get $i)
					(i32.const 1)
				))
				;; continue
				(br $loop2)
			)
		)
		(local.get $sum)
	)

	(func $main
		(export "main")
		(result i32)
		;; store the length of the vector at the beginning of the memory
		;; we have 6 diffs, so the vector has length 6
		(i32.store (i32.const 0) (i32.const 6))
		;; store the elements of the vector
		(i32.store (i32.const 4) (i32.const 2))
		(i32.store (i32.const 8) (i32.const 1))
		(i32.store (i32.const 12) (i32.const 0))
		(i32.store (i32.const 16) (i32.const 1))
		(i32.store (i32.const 20) (i32.const 2))
		(i32.store (i32.const 24) (i32.const 5))

		;; let's return the sum of the vector:
		(call $vector-sum (i32.const 0))
	)
)
```

It should output `11`. Great!

## 2. Calculate the absolute differences of the input

Well, we have some new challenges. We need multiple vectors, one for each column and one for the diffs. Let's introduce a pointer to free memory and some convenience functions to create vectors and set their elements. Finally, we will iterate over the two input vectors and store the absolute differences in a third vector.


[step2.wat](day1/step2.wat)

New memory functions:

```wat
;; free memory pointer
(global $freeptr (mut i32) (i32.const 0))
;; get the free memory pointer
(func $get-free-ptr (export "get-free-ptr") (result i32)
	(global.get $freeptr)
)
;; increment the free memory pointer by n bytes
(func $incr-free-ptr (export "incr-free-ptr") (param $n i32)
	(global.set $freeptr (i32.add (global.get $freeptr) (local.get $n)))
)
;;
```

New vector functions:

```wat
;; set the nth element of a vector
(func $vector-set (export "vector-set") (param $ptr i32) (param $n i32) (param $val i32)
	(i32.store
		(i32.add
			(i32.const 4) ;; skip the length
			(i32.add
				(local.get $ptr)
				(i32.mul
					(local.get $n) ;; nth element
					(i32.const 4) ;; 4 bytes per element
				)
			)
		)
		(local.get $val)
	)
)

;; create a new vector at the free memory pointer
;; the i32 at the memory pointer is the length of the vector
;; increment the free memory pointer by 4 bytes for the length and len*4 bytes for the elements
(func $vector-new (export "vector-new") (param $len i32) (result i32)
	(local $ptr i32)
	(local.set $ptr (call $get-free-ptr))
	(call $incr-free-ptr (i32.mul (i32.const 4) (i32.add (local.get $len) (i32.const 1))))
	(i32.store (local.get $ptr) (local.get $len))
	(local.get $ptr)
)
```

Absolute difference function:

```wat
;; get the absolute difference of two u32:
;; if a > b, return a - b, else return b - a
(func $abs-diff (export "abs-diff") (param $a i32) (param $b i32) (result i32)
	(if (result i32) (i32.gt_u (local.get $a) (local.get $b))
		(i32.sub (local.get $a) (local.get $b))
		(i32.sub (local.get $b) (local.get $a))
	)
)
```

Calucate the diffs:
```wat
;; iterate over two vectors creating a new vector with the absolute differences
(func $calc-diffs (export "calc-diffs") (param $left-ptr i32) (param $right-ptr i32) (result i32)
	(local $diffs-ptr i32)
	(local $len i32)
	(local $i i32)
	;; we trust the input vectors to have the same length
	(local.set $len (i32.load (local.get $left-ptr)))
	;; create a new vector to store the differences
	(local.set $diffs-ptr (call $vector-new (local.get $len)))
	;; iterate over the vectors
	;; for(i = 0; i < len; i++)
	(block $block1
		(loop $loop2
			;; if i == len, break
			(br_if $block1
				(i32.eq
					(local.get $i)
					(local.get $len)
				)
			)
			;; store the absolute difference of the elements
			;; diffs[i] = absdiff(left[i], right[i])
			(call $vector-set (local.get $diffs-ptr) (local.get $i)
				(call $abs-diff
					(call $vector-nth (local.get $left-ptr) (local.get $i))
					(call $vector-nth (local.get $right-ptr) (local.get $i))
				)
			)
			;; i++
			(local.set $i (i32.add
				(local.get $i)
				(i32.const 1)
			))
			;; continue
			(br $loop2)
		)
	)
	(local.get $diffs-ptr)
)
```

Main:
```
(func $main
	(export "main")
	(result i32)
	(local $left-ptr i32)
	(local $right-ptr i32)
	(local $diffs-ptr i32)
	
	;; create a vector with the sorted values of the left column [1, 2, 3, 3, 3, 4] with length 6
	;; save the pointer to the vector in $left-ptr
	(local.set $left-ptr (call $vector-new (i32.const 6)))
	(call $vector-set (local.get $left-ptr) (i32.const 0) (i32.const 1))
	(call $vector-set (local.get $left-ptr) (i32.const 1) (i32.const 2))
	(call $vector-set (local.get $left-ptr) (i32.const 2) (i32.const 3))
	(call $vector-set (local.get $left-ptr) (i32.const 3) (i32.const 3))
	(call $vector-set (local.get $left-ptr) (i32.const 4) (i32.const 3))
	(call $vector-set (local.get $left-ptr) (i32.const 5) (i32.const 4))

	;; create a vector with the sorted values of the right column [3, 3, 3, 4, 5, 9] with length 6
	(local.set $right-ptr (call $vector-new (i32.const 6)))
	(call $vector-set (local.get $right-ptr) (i32.const 0) (i32.const 3))
	(call $vector-set (local.get $right-ptr) (i32.const 1) (i32.const 3))
	(call $vector-set (local.get $right-ptr) (i32.const 2) (i32.const 3))
	(call $vector-set (local.get $right-ptr) (i32.const 3) (i32.const 4))
	(call $vector-set (local.get $right-ptr) (i32.const 4) (i32.const 5))
	(call $vector-set (local.get $right-ptr) (i32.const 5) (i32.const 9))

	;; calculate the differences between the two vectors
	;; save the pointer to the vector in $diffs-ptr
	(local.set $diffs-ptr (call $calc-diffs (local.get $left-ptr) (local.get $right-ptr)))
	

	;; return the sum of the differences
	(call $vector-sum (local.get $diffs-ptr))
)
```

It still outputs our beloved `11`! For the next step, we will need to implement a sorting algorithm!

## Step 3. Sorting the vectors

In the previous step, we assumed that the numbers of the left and right columns are already sorted.

It's time to implement a sorting algorithm. We will use the bubble sort algorithm, because it's simple and works in place. We will use a helper function to swap two elements in a vector.

[step3.wat](day1/step3.wat)

The [bubble sort](https://www.geeksforgeeks.org/bubble-sort-algorithm/) algorithm we will implement is basically this:

```c
int i, j;
bool swapped;
for (i = 0; i < n - 1; i++) {
	swapped = false;
	for (j = 0; j < n - i - 1; j++) {
		if (arr[j] > arr[j + 1]) {
			swap(&arr[j], &arr[j + 1]);
			swapped = true;
		}
	}
	if (swapped == false)
		break;
}
```

Swap function:
```wat
(func $vector-swap (export "vector-swap") (param $ptr i32) (param $i i32) (param $j i32)
	(local $tmp i32)
	;; tmp = ptr[i]
	(local.set $tmp (call $vector-nth (local.get $ptr) (local.get $i)))
	;; ptr[i] = ptr[j]
	(call $vector-set
		(local.get $ptr)
		(local.get $i)
		(call $vector-nth (local.get $ptr) (local.get $j))
	)
	;; ptr[j] = tmp
	(call $vector-set
		(local.get $ptr)
		(local.get $j)
		(local.get $tmp)
	)
)
```

Bubble sort function:
```wat
;; BUBBLE SORT
(func $bubble-sort (export "bubble-sort") (param $ptr i32)
	(local $i i32) (local $j i32) (local $len i32) (local $swapped i32)
	(local.set $len (i32.load (local.get $ptr)))
	;; for (i = 0; i < n - 1; i++) {
	(block $outer-block
		(loop $outer-loop
			;; if i >= n - 1, break;
			(br_if $outer-block
				(i32.ge_u
					(local.get $i)
					(i32.sub
						(local.get $len)
						(i32.const 1)
					)
				)
			)
			;; swapped = false;
			(local.set $swapped (i32.const 0))
			;; j = 0;
			(local.set $j (i32.const 0))
			;; for (j = 0; j < n - i - 1; j++) {
			(block $inner-block
				(loop $inner-loop
					;; if j >= n - i - 1, break;
					(br_if $inner-block
						(i32.ge_u
							(local.get $j)
							(i32.sub
								(local.get $len)
								(i32.add
									(local.get $i)
									(i32.const 1)
								)
							)
						)
					)
					;; if (arr[j] > arr[j + 1]) {
					(if
						(i32.gt_u
							(call $vector-nth (local.get $ptr) (local.get $j))
							(call $vector-nth (local.get $ptr) (i32.add (local.get $j) (i32.const 1)))
						)
						;; swap(arr[j], arr[j + 1]);
						(then
							(call $vector-swap
								(local.get $ptr)
								(local.get $j)
								(i32.add (local.get $j) (i32.const 1))
							)
							(local.set $swapped (i32.const 1))
						)
					)
					;; j++;
					(local.set $j (i32.add (local.get $j) (i32.const 1)))
					(br $inner-loop)
				)
			)
			;; i++;
			(local.set $i (i32.add (local.get $i) (i32.const 1)))
			;; if (!swapped) break;
			(br_if $outer-block
				(i32.eqz (local.get $swapped))
			)
			(br $outer-loop)
		)
	)
)
```

Our main function does not change much, we simply use the unsorted columns for our left and right vectors and sort them before calculating the differences:
```wat
(func $main
	(export "main")
	(result i32)
	(local $left-ptr i32)
	(local $right-ptr i32)
	(local $diffs-ptr i32)
	
	;; create a vector with the values of the left column [3, 4, 2, 1, 3, 3] with length 6
	;; save the pointer to the vector in $left-ptr
	(local.set $left-ptr (call $vector-new (i32.const 6)))
	(call $vector-set (local.get $left-ptr) (i32.const 0) (i32.const 3))
	(call $vector-set (local.get $left-ptr) (i32.const 1) (i32.const 4))
	(call $vector-set (local.get $left-ptr) (i32.const 2) (i32.const 2))
	(call $vector-set (local.get $left-ptr) (i32.const 3) (i32.const 1))
	(call $vector-set (local.get $left-ptr) (i32.const 4) (i32.const 3))
	(call $vector-set (local.get $left-ptr) (i32.const 5) (i32.const 3))

	;; create a vector with the sorted values of the right column [4, 3, 5, 3, 9, 3] with length 6
	(local.set $right-ptr (call $vector-new (i32.const 6)))
	(call $vector-set (local.get $right-ptr) (i32.const 0) (i32.const 4))
	(call $vector-set (local.get $right-ptr) (i32.const 1) (i32.const 3))
	(call $vector-set (local.get $right-ptr) (i32.const 2) (i32.const 5))
	(call $vector-set (local.get $right-ptr) (i32.const 3) (i32.const 3))
	(call $vector-set (local.get $right-ptr) (i32.const 4) (i32.const 9))
	(call $vector-set (local.get $right-ptr) (i32.const 5) (i32.const 3))

	;; sort the left vector
	(call $bubble-sort (local.get $left-ptr))
	;; sort the right vector
	(call $bubble-sort (local.get $right-ptr))

	;; calculate the differences between the two vectors
	;; save the pointer to the vector in $diffs-ptr
	(local.set $diffs-ptr (call $calc-diffs (local.get $left-ptr) (local.get $right-ptr)))
	

	;; return the sum of the differences
	(call $vector-sum (local.get $diffs-ptr))
)
```

Let's take a deep breath, we just implemented a sorting algorithm in pure WebAssembly on top of our own vector implementation. We will also need some oxygen to take on the last and most challenging step: parsing the input.

## Step 4. Parsing the input and computing the result

As I said in the beginning, the input will be loaded to the memory unparsed as ASCII encoded bytes. We will need to parse the input to integers.

Since WebAssembly does not support strings, we have to choose a representation for it in memory. We will use a similar approach to vectors.

We will store the length of the string at the beginning of the memory and then the characters. But unlinke vectors, we will store them as bytes, not as 4 byte integers.

We will also have to load the input from the host code and write it to the memory. As previously, let's start with the end and work our way back.

We will create a [sample.txt](day1/sample.txt) file with the example input (leaving a blank line at the end, as the AoC inputs usually do).

We will then copy it to the memory and pass the address to the main function.

Final Code: [part1.wat](day1/part1.wat)

[part1.js](day1/part1.js):
```js
import { readFileSync } from 'fs';
// read file as raw bytes
const input = readFileSync('sample.txt');
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
wasm.exports['incr-free-ptr'](4 + input.length * 4);
// call the main function with the pointer to the input
console.log(wasm.exports.main(inputPtr));
```

Now let's start with some utility functions. For example, we will need to count the lines in the input to know how big the vectors should be.

The ASCII code for the newline character is 10.

```wat
(func $count-lines (export "count-lines") (param $ptr i32) (result i32)
	(local $count i32) (local $i i32) (local $len i32)
	;; get the length of the input
	(local.set $len (i32.load (local.get $ptr)))
	;; for(i = 0; i < len; i++)
	(block $block
		(loop $loop
			;; if i >= len, break
			(br_if $block
				(i32.ge_u
					(local.get $i)
					(local.get $len)
				)
			)
			;; if character at $ptr + 4 + i = 10, count++
			(if
				(i32.eq
					(i32.load8_u
						(i32.add
							(i32.const 4)
							(i32.add
								(local.get $ptr)
								(local.get $i)
							)
						)
					)
					(i32.const 10)
				)
				;; count++
				(local.set $count (i32.add
					(local.get $count)
					(i32.const 1)
				))
			)
			;; i++
			(local.set $i (i32.add
				(local.get $i)
				(i32.const 1)
			))
			;; continue
			(br $loop)
		)
	)
	;; return count
	(local.get $count)
)
```

Let's also implement a function, that checks if an ASCII character is a digit. The ASCII codes for the digits are 48 ("0") to 57 ("9").

```wat
(func $is-digit (export "is-digit") (param $char i32) (result i32)
	(i32.and
		(i32.ge_u (local.get $char) (i32.const 48))
		(i32.le_u (local.get $char) (i32.const 57))
	)
)
```

Now we can actually implement our parsing. We will store all numbers in a single vector and split it later into left and right columns.

First we will count the lines in the input and create a vector with size lines * 2, because we have two numbers per line.

```wat
(func $parse-input-to-numbers (export "parse-input-to-numbers") (param $input-ptr i32) (result i32)
	;; current character index
	(local $i i32)
	;; input length
	(local $input-length i32)
	;; number of lines of input
	(local $lines i32)
	;; currently parsed number
	(local $num i32)
	;; result vector pointer
	(local $vector-ptr i32)
	;; current character
	(local $char i32)
	;; which vector position to write to
	(local $vector-pos i32)
	;; get the length of the input
	(local.set $input-length (i32.load (local.get $input-ptr)))
	;; count lines of input
	(local.set $lines (i32.sub
		(call $count-lines (local.get $input-ptr))
		(i32.const 1)
	))
	;; initialize a vector with length = 2 * number of lines
	(local.set $vector-ptr (call $vector-new
		(i32.mul (i32.const 2) (local.get $lines))
	))
	;; for(i = 0; i < input-length; i++)
	(block $block-input
		(loop $loop-input
			;; if i >= input-length, break
			(br_if $block-input
				(i32.ge_u
					(local.get $i)
					(local.get $input-length)
				)
			)
			;; char = uint8 memory[input-ptr + 4 + i]
			(local.set $char (i32.load8_u
				(i32.add
					(i32.const 4)
					(i32.add
						(local.get $input-ptr)
						(local.get $i)
					)
				)
			))
			;; if char is a digit, num = num * 10 + (char - 48)
			(if
				(call $is-digit (local.get $char))
				(then
					(local.set $num (i32.add
						(i32.mul (local.get $num) (i32.const 10))
						(i32.sub (local.get $char) (i32.const 48))
					))
				)
				;; if char is not a digit and num is not 0, write num to vector and increment vector position
				(else
					(if
						(i32.ne (local.get $num) (i32.const 0))
						(then
							(call $vector-set (local.get $vector-ptr) (local.get $vector-pos) (local.get $num))
							(local.set $num (i32.const 0))
							(local.set $vector-pos (i32.add (local.get $vector-pos) (i32.const 1)))
						)
					)
				)
			)
			(local.set $i (i32.add (local.get $i) (i32.const 1)))
			;; continue
			(br $loop-input)
		)
	)
	;; return the vector pointer
	(local.get $vector-ptr)
)
```

Now that we have the numbers in a single vector, we can split them into two vectors alternatingly.

Since we cannot return two values from a function, we will pass the pointers to the left and right vectors as parameters.

```wat
(func $split-vector (export "split-vector") (param $vector-ptr i32) (param $left-ptr i32) (param $right-ptr i32)
	;; fill left and right alternatingly from vector-ptr
	(local $i i32) (local $len i32)
	(local.set $len (i32.load (local.get $vector-ptr)))
	(local.set $i (i32.const 0))
	;; for(i = 0; i < len; i++);
	(block $block
		(loop $loop
			;; if i >= len, break
			(br_if $block
				(i32.ge_u
					(local.get $i)
					(local.get $len)
				)
			)
			;; left[i / 2] = vector[i]
			;; right[i / 2] = vector[i + 1]
			(call $vector-set
				(local.get $left-ptr)
				(i32.div_s (local.get $i) (i32.const 2))
				(call $vector-nth (local.get $vector-ptr) (local.get $i))
			)
			(call $vector-set
				(local.get $right-ptr)
				(i32.div_s (local.get $i) (i32.const 2))
				(call $vector-nth (local.get $vector-ptr) (i32.add (local.get $i) (i32.const 1)))
			)
			;; i++
			(local.set $i (i32.add (local.get $i) (i32.const 2)))
			;; continue
			(br $loop)
		)
	)
)
```

And that is all we need to parse the input and compute the result from ASCII input to the final number.

Let's put it all together in the main function:

```wat
(func $main
	(export "main")
	(param $input-ptr i32)
	(result i32)
	(local $numbers-ptr i32)
	(local $numbers-len i32)
	(local $left-ptr i32)
	(local $right-ptr i32)
	(local $diffs-ptr i32)
	;; parse input to numbers vector
	(local.set $numbers-ptr (call $parse-input-to-numbers (local.get $input-ptr)))
	(local.set $numbers-len (i32.load (local.get $numbers-ptr)))
	;; create left and right vectors with half the length of numbers
	(local.set $left-ptr (call $vector-new (i32.div_s (local.get $numbers-len) (i32.const 2))))
	(local.set $right-ptr (call $vector-new (i32.div_s (local.get $numbers-len) (i32.const 2))))
	;; split the numbers vector into left and right vectors
	(call $split-vector (local.get $numbers-ptr) (local.get $left-ptr) (local.get $right-ptr))
	;; sort the left and right vectors
	(call $bubble-sort (local.get $left-ptr))
	(call $bubble-sort (local.get $right-ptr))
	;; calculate the differences between the left and right vectors
	(local.set $diffs-ptr (call $calc-diffs (local.get $left-ptr) (local.get $right-ptr)))
	;; return the sum of the differences
	(call $vector-sum (local.get $diffs-ptr))
)
```

## [ELEVEN!](https://www.youtube.com/watch?v=NMS2VnDveP8)

To run it with the real input (The [rules](https://adventofcode.com/about#faq_copying) do not allow me to post my actual input, so I created my own), we change the `sample.txt` to `input.txt` and run `node part1.js` again.
For my input, it outputs `1889772`, which gives us our first star in the Advent of Code 2024

## ⭐️

Speaking of stars, I hope you liked this article. If you did, please leave a star on GitHub.

In Part 2 of Day 1, we will need a way to count the occurences of numbers in a vector and also look them up. We will implement it using some variation of *association lists*.