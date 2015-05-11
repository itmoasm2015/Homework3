%ifndef LIBHW_I
%define LIBHW_I

;; Bigint struct stores pointer to vector with digits and sign:
;; -1 for Bigint < 0
;;  0 for Bigint = 0
;;  1 for Bigint > 0
;;
;; Highest digit is stored at the end of vector, lowest in the beginnig.
;; Last digit is always non-zero.

struc Bigint
	.vector		resq	1
	.sign		resq	1
endstruc

%endif