(module
	(memory (export "memory") 1) ;; 1 page initial (= 64 KiB), 1 page max, because 64 KiB is plenty for now

	;; free memory pointer
	(global $freeptr (mut i32) (i32.const 0))
	;; increment the free memory pointer by n bytes
	(func $get-free-ptr (export "get-free-ptr") (result i32)
		(global.get $freeptr)
	)
	;; increment the free memory pointer
	(func $incr-free-ptr (export "incr-free-ptr") (param $n i32)
		(global.set $freeptr (i32.add (global.get $freeptr) (local.get $n)))
	)

	;; get the nth element of a vector
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
		;; free-ptr += 4 + len*4
		(call $incr-free-ptr (i32.mul (i32.const 4) (i32.add (local.get $len) (i32.const 1))))
		;; store the length of the vector
		;; mem[$ptr] = len
		(i32.store (local.get $ptr) (local.get $len))
		;; return the pointer to the vector
		(local.get $ptr)
	)

	;; sum the elements of a vector
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
		;; for(i = 0; i < len; i ++)
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

	;; get the absolute difference of two u32:
	;; if a > b, return a - b, else return b - a
	(func $abs-diff (export "abs-diff") (param $a i32) (param $b i32) (result i32)
		(if (result i32) (i32.gt_u (local.get $a) (local.get $b))
			(i32.sub (local.get $a) (local.get $b))
			(i32.sub (local.get $b) (local.get $a))
		)
	)

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

	;; swap two elements of a vector
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

	(func $is-digit (export "is-digit") (param $char i32) (result i32)
		(i32.and
			(i32.ge_u (local.get $char) (i32.const 48))
			(i32.le_u (local.get $char) (i32.const 57))
		)
	)

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
		(local.set $lines
			(call $count-lines (local.get $input-ptr))
		)
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
)