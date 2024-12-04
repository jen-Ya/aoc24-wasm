(module
	(memory (export "memory") 1 1) ;; 1 page initial (= 64 KiB), 1 page max, because 64 KiB is plenty for now

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
				(local.set $i (i32.add
					(local.get $i)
					(i32.const 1)
				))
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

		;; let's return the sum of the vector
		(call $vector-sum (i32.const 0))
	)
)