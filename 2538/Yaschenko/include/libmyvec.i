%ifndef LIBMYVEC_I
%define LIBMYVEC_I

;; Vector struct stores pointer to memory with data, size of vector
;; (number of elements inside), and capacity (number of elements that
;; can this vector hold).
;; Vector is self-expanding: grows twice in size with every addition
;; that current capacity can't hold.
;; Each element is a 64bit integer.

struc Vector
	.data		resq	1
	.size		resq	1
	.capacity	resq	1
endstruc

%endif