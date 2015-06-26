              struc vector
.size:        resq  1
.capacity:    resq  1
.sign:        resq  1               ; used only for bigint
.data:        resq  1               
              endstruc 

;; A macro which points %1 to the data of vector in %2
%macro GET_DATA 2
              lea   %1, [%2 + vector.data]
              mov   %1, [%1]
%endmacro

%macro SET_DATA 2
              mov   [%1 + vector.data], %2
%endmacro
