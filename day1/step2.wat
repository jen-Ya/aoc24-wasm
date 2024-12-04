(module
	(memory (export "memory") 1 1) ;; 1 page initial (= 64 KiB), 1 page max, because 64 KiB is plenty for now

	;; free memory pointer
	(global $freeptr (mut i32) (i32.const 0))
	;; get the free memory pointer
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
)