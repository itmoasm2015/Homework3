default rel

section .text

extern malloc
extern free
extern strlen
extern printf

global biFromInt
global biFromString
global biToString
global biDelete
global biSign
global biAdd
global biSub
global biMul
global biDivRem
global biCmp

BASE              equ 1000000000
BASE_LENGTH       equ 9
DEFAULT_CAPACITY  equ 2

; Длинные числа храним следующим образом:
; Первый байт -- знак:
;       -1, если число отрицательное
;       0 , если число равно 0
;       1 , если число положительное
; Следующие 4 байта -- длина длинного числа
; Следующие 4 байта -- вместимость длинного числа, капасити, то есть сколько цифр
; мы можем в этом длинном числе хранить. Изначально вместимость равна 2
; Следующие группы по 4 байта -- цифры числа
; Одна цифра -- число от 0 до BASE - 1
; Число хранится перевернутым, то есть x = digits[0] * BASE^0 + digits[1]*BASE^1 + ...
; Число хранится в десятичной системе счисления, BASE = 10^9

struc BigInt
	.sign     : resb 1
	.size     : resq 1
	.capacity : resq 1
	.digits   : resq 1
endstruc

; Добавляет на стек регистры, переданные в аргументах, в прямом порядке
%macro mpush 1-*
%rep %0
    push %1
%rotate 1
%endrep
%endmacro

; Забирает регистры, переданные в аргументах, в обратном порядке
%macro mpop 1-*
%rep %0
%rotate -1
    pop %1
%endrep
%endmacro

; Кладет на стек все регистры, которые могут измениться
%macro pushAll 0
    mpush rdi, rsi, rax, rcx, rdx, r8, r9, r10, r11
%endmacro

; Забирает со стека все регистры, которые положил туда pushAll
%macro popAll 0
    mpop rdi, rsi, rax, rcx, rdx, r8, r9, r10, r11
%endmacro

; Очищает память, предварительно сохранив все регистры
%macro callFree 1
    pushAll
	mov r11, %1	
	xor rdi, rdi				 		; запоминаем указатель на структуру с длинным числом
    mov edi, [r11 + BigInt.digits]		; удаляем указатель на цифры длинного числа
    ;call free
	mov rdi, r11						; удаляем указатель на структуру
	call free
    popAll
%endmacro

%macro callFreeVector 1
	pushAll
	mov rdi, %1							; удаляем указатель на вектор
	;call free
	popAll
%endmacro

; Создает новый вектор по указателю на структуру с длинным числом и размеру
; Старый вектор удаляется
%macro newVector 2
	mpush rdi, %1, %2, r12, r13
	lea rdi, [%2 * 4]					; %2 * 4 -- количество байт, которые надо выделить

	mpush rdi, rax
	call malloc							; выделяем память под новый вектор
	mov r13, rax						; копируем указатель на новый вектор в R13
	mpop rdi, rax
	
	xor r12, r12						; R12 -- указатель на цифру
	push r14
	mov r14, r13
%%fill_zeroes:     
	cmp r12, rdi
	je %%finish
	mov dword [r13], 0					; записываем в цифру 0
	add r13, 4							; переходим к следующей цифре
	add r12, 4
	jmp %%fill_zeroes
%%finish:
	mov [%1 + BigInt.digits], r14d
	mpop rdi, %1, %2, r12, r13, r14
%endmacro

; BigInt createBigIntWithCapacity(size_t capacity);
; создает длинное число по вместимости массива для цифр
; capacity -- RDI
; RAX -- результат
; сохраняет RDI
%macro createBigIntWithCapacity 1
	mov rdi, 16							; 32 байта выделяем под структуру
	mpush %1, rsi
	call malloc							; RAX -- выделенная структура
	mpop %1, rsi
	mov byte [rax + BigInt.sign], 0		; Записываем 0 в знак и размер вектора
	mov dword [rax + BigInt.size], 0	;
	mov [rax + BigInt.capacity], %1d	; Вместимость берем из аргумента

	mpush r9, rsi
	mov r9, %1
	newVector rax, r9
	mpop r9, rsi
%endmacro

; BigInt createBigInt();
; создает длинное число с вместимостью по умолчанию (DEFAULT_CAPACITY)
; RAX -- результат
; сохраняет RDI
%macro createBigInt 0
    mpush rdi, rsi, r9
    mov rdi, DEFAULT_CAPACITY
	mov r9, rdi
    createBigIntWithCapacity r9
    mpop rdi, rsi, r9
%endmacro

; void ensureCapacity(size_t size, size_t capacity, BigInt number);
; Проверяет, хватает ли вместимости длинного числа, чтобы добавить в конец одну цифру
; Если не хватает, увеличивает вместимость в два раза
; size -- RDI
; capacity -- RSI
; number -- RDX
; сохраняет RDI, RSI
ensureCapacity:
    cmp rdi, rsi                    ; сравниваем размер и вместимость
    jl .finish
                                    ; RDI >= RSI, значит надо увеличивать размер
    mpush rdx, rdi, rsi  	            
	shl rsi, 1                      ; RSI -- новая вместимость, RSI = RSI_OLD * 2
	xor rax, rax
	mov eax, [rdx + BigInt.digits]  ; RAX -- указатель на вектор с цифрами

	mpush rax
    newVector rdx, rsi
	mpop rax
    mpop rdx, rdi, rsi

	mov r8, 0                       ; R8 -- индекс текущей цифры
	push r12
	xor r12, r12					; указатель на новый вектор с цифрами
	mov r12d, [rdx + BigInt.digits]
.fill_values:                       
    cmp r8, rdi                     ; R8 = RDI (размер числа) => закончили
    je .before_simple_push_back         
    push r11
    xor r11, r11
    mov r11d, [rax + r8 * 4 + 9]	; [RAX + r8 * 4 + 9] -- цифра с индексом R8 числа RAX
    mov [r12 + r8 * 4 + 9], r11d    ; копируем это значение в соответствующую цифру R12
    pop r11
    inc r8                          ; следующая цифра
    jmp .fill_values
.before_simple_push_back:
	pop r12

	callFreeVector rax
.finish:
    ret

; Добавляет в конец длинного числа новую цифру
; %1 -- указатель на число
; %2 -- цифра
; вызывает ensureCapacity, которая, если надо, увеличивает вместимость
; и потом просто записывает в конец новую цифру
%macro pushBack 2    
    mpush rdi, rsi, rdx, rcx

    xor rdi, rdi
    mov edi, [%1 + BigInt.size] 	; RDI -- размер числа
    xor rsi, rsi
    mov esi, [%1 + BigInt.capacity] ; RSI -- вместимость числа
    mov rdx, %1                 	; RDX -- само длинное число
                                	; можем вызвать ensureCapacity, он все сделает, что нам надо
    	
	mpush %2, rax
	call ensureCapacity
    mpop %2, rax
    mov %1, rdx

	mpush r12
	xor r12, r12
	mov r12d, [%1 + BigInt.digits]
    
    mov dword [r12 + rdi * 4], %2d 	; добавляем в конец цифру

   	inc rdi                     	; увеличиваем на один RDI -- размер числа
    mov [%1 + BigInt.size], edi    	; и изменяем размер в указателе, конец

	mpop r12
	mpop rdi, rsi, rdx, rcx
%endmacro

; переводит int в строку длиной ровно 9 символов (дополняет нулями)
; %1 -- число, которое нужно перевести в строку
; результат в RAX
%macro intToStr 1
    push %1
    push %1    
    mov rdi, 10
    push rdi
    call malloc
    pop rdi
    pop %1
       
    mov r8, %1
    xor rcx, rcx
%%write_decimal_digit:
    cmp r8, 0
    je %%get_string

    mpush rax, rcx
    mov rax, r8
    xor rdx, rdx
    mov r9, 10
    div r9
    mov r8, rax
    mov r9, rdx
    mpop rax, rcx

    push r9

    inc rcx
    jmp %%write_decimal_digit
%%get_string:
    xor rdx, rdx
%%write_digits_to_string:
    cmp rcx, 0
    je %%add_zeroes

    pop r9
    add r9, '0'
    mov byte [rax + rdx], r9b
    inc rdx
    dec rcx
    jmp %%write_digits_to_string
%%add_zeroes:
    mov r8, 9
    sub r8, rdx
    dec rdx
%%loop:
    cmp rdx, 0
    jl %%add_to_begin
    lea r9, [rax + rdx]
    push r11
    xor r11, r11
    mov r11b, byte [r9]
    mov byte [r9 + r8], r11b
    pop r11
    dec rdx
    jmp %%loop
%%add_to_begin:
    cmp r8, 0
    je %%finish
    mov byte [rax + r8 - 1], '0'
    dec r8
    jmp %%add_to_begin
%%finish
    mov byte [rax + 9], 0
    mov rcx, 9
    pop %1
%endmacro

%macro deleteZeroesFromString 2
    push r12
    xor r12, r12
%%loop:
    cmp byte [%1 + r12], '0'
    jne %%delete_zeroes
    inc r12
    jmp %%loop
%%delete_zeroes:
    push r13
    mov r13, r12
%%write_digit:
    cmp r13, %2
    jg %%finish
    push r14
    lea r14, [%1 + r13]
    push r11
    xor r11, r11
    mov r11b, byte [r14]
    sub r14, r12
    mov byte [r14], r11b
    pop r11
    pop r14
    inc r13
    jmp %%write_digit
%%finish:
    sub %2, r12
    pop r13
    pop r12
%endmacro

%macro deleteZeroesFromBigInt 1
    mpush rdi, rcx
    xor rdi, rdi
    mov edi, [%1 + BigInt.size]

	push r12
	xor r12, r12
	mov r12d, [%1 + BigInt.digits]
    lea rcx, [r12 + rdi * 4 - 4]
	pop r12
%%while_zero:
    cmp dword [rcx], 0
    jne %%change_size
    sub rcx, 4
    dec rdi
%%change_size:
    cmp rdi, 0
    jg %%all_is_ok
    mov rdi, 1
%%all_is_ok:
    mov [%1 + BigInt.size], edi
    mpop rdi, rcx
%endmacro

%macro biCopy 2
	xor r8, r8
	mov r8b, byte [%2 + BigInt.sign]

	mov byte [%1 + BigInt.sign], r8b
	mov r8d, [%2 + BigInt.size]
	mov [%1 + BigInt.size], r8d
	mov r8d, [%2 + BigInt.capacity]
	mov [%1 + BigInt.capacity], r8d

	mov r8d, [%2 + BigInt.size]

	mpush r15, %2, r8
	mov r15, %1
	newVector r15, r8
	mov %1, r15
	mpop r15, %2, r8

	push rcx
	xor rcx, rcx
	xor r10, r10
	xor r11, r11
	mov r10d, [%2 + BigInt.digits]
	mov r11d, [%1 + BigInt.digits]
%%copy_digits:
	cmp rcx, r8
	je %%finish
	push r12
	xor r12, r12
	mov r12d, [r10]
	mov [r11], r12d
	pop r12
	add r10, 4
	add r11, 4
	inc rcx
	jmp %%copy_digits
%%finish:
	pop rcx
%endmacro

%macro biNegate 1
	mpush r15
	xor r15, r15
	mov r15b, byte [%1 + BigInt.sign]
	neg r15
	mov byte [%1 + BigInt.sign], r15b
	mpop r15
%endmacro

; BigInt biFromInt(int64_t number);
; number -- RDI
; возвращает RAX
; создает длинное число по короткому
biFromInt:
    xor r8, r8
	createBigInt                		; создаем число с дефолтной вместимостью
    mov byte [rax + BigInt.sign], 1     ; изначально его знак равен 1
    cmp rdi, 0
    jge .non_negative           
    mov byte [rax + BigInt.sign], -1	; число отрицательное, пишем в его знак -1
    neg rdi                     		; RDI = -RDI, теперь число можно парсить как положительное
    jmp .positive_number
.non_negative:
    cmp rdi, 0                  
    jg .positive_number         
    mov byte [rax + BigInt.sign], 0		; число равно 0
    mov dword [rax + BigInt.size], 1    ; количество цифр -- 1
    jmp .finish
.positive_number:
    xor r8, r8                  ; R8 -- текущая цифра
    mov r10, 1                  ; R10 -- текущая степень 10
    xor r11, r11                ; R11 -- перенос
.process_digits:
    cmp rdi, 0
    je .finish
    
    mpush rax, rdx
    mov rax, rdi                ; подготавливаем деление -- переносим делимое в RAX
    xor rdx, rdx                ; чистим RDX
    mov r9, 10                     
    div r9                      ; теперь RAX = [RAX / 10], RDX = RAX % 10
    mov r9, rdx                 ; R9 -- цифра в десятичной системе счисления
    mov rdi, rax                ; обновляем RDI -- теперь без последней цифры
    mpop rax, rdx
    
    cmp r10, BASE               ; если R10 = BASE, мы закончили строить цифру в системе счисления BASE
    je .push_back
    imul r9, r10                ; R9 * R10 -- то, что надо прибавить к текущей цифре
    add r8, r9                  ; R8 += R9 -- увеличиваем текущую цифру
    imul r10, 10                ; степень десятки увеличивается
    jmp .process_digits
.push_back:
    mov r11, r9                 ; запоминаем перенос, а после этого делаем push_back
    mpush r11
    pushBack rax, r8            ; добавляем в конец RAX цифру R8
    mpop r11
    mov r10, 10                 ; степень десятки равна 1
    mov r8, r11                 ; R8 = R11 -- пишем в новую цифру запомненный перенос
    jmp .process_digits    
.finish:
    cmp r8, 0                   ; если в конце осталась незаписанная цифра, добавляем ее в конец RAX
    je .all_is_done
    pushBack rax, r8
    xor r9, r9
.all_is_done:
    ret

; BigInt biFromString(char const *s);
; s -- RDI
; ответ в RAX
; делает большое число по строке (строка удовлетворяет ^-?\d+$)
; если строка некорректна, возвращает 0
biFromString:
    createBigInt
    mov byte [rax + BigInt.sign], 1
    xor rcx, rcx
    cmp byte [rdi], '-'
    jne .positive_number
    mov byte [rax + BigInt.sign], -1
    inc rcx
.positive_number:
    cmp byte [rdi + rcx], 0
    je .error_occurred
    mov r9, rcx
    xor r10, r10
.count_zeroes:
    cmp byte [rdi + r9], '0'
    jne .not_zero_digit
    inc r9
    inc r10
    jmp .count_zeroes
.not_zero_digit:
    cmp byte [rdi + r9], 0
    jne .number_is_not_zero
    mov byte [rax + BigInt.sign], 0
	mov dword [rax + BigInt.size], 1
    jmp .finish
.number_is_not_zero:
    mpush rax, rdx
    xor rdx, rdx
    mov rax, r10
    mov r10, BASE_LENGTH
    div r10
    imul rax, BASE_LENGTH
    add rcx, rax
    mpop rax, rdx

    mpush rax, rdi, rcx 
    xor rax, rax
    call strlen
    mov r8, rax
    mpop rax, rdi, rcx
    lea rdx, [rdi + r8 - 1]
    add rcx, rdi
    xor r8, r8
    mov r10, 1
.process_digits:
    cmp rdx, rcx
    jl .finally
    
    cmp byte [rdx], '0'
    jl .error_occurred
    cmp byte [rdx], '9'
    jg .error_occurred
    xor r9, r9
    mov r9b, byte [rdx]
    sub r9, '0'
    dec rdx

    cmp r10, BASE
    je .push_back
    imul r9, r10
    add r8, r9
    imul r10, 10
    jmp .process_digits
.push_back:
    mov r11, r9
    mpush r11
    pushBack rax, r8
    mpop r11
    mov r10, 10
    mov r8, r11
    
    jmp .process_digits
.finally:
    cmp r8, 0
    je .finish
    pushBack rax, r8
    jmp .finish
.error_occurred:
    ;callFree rax
    xor rax, rax
.finish:
    ret

; void biToString(BigInt bi, char *buffer, size_t limit);
; bi -- RDI
; buffer -- RSI
; limit -- RDX
biToString:
    xor rcx, rcx
    dec rdx
    cmp rdx, 0
    je .add_zero
    cmp byte [rdi + BigInt.sign], 0
    jne .non_zero_number
    mov byte [rsi + rcx], '0'
    inc rcx
    jmp .add_zero
.non_zero_number:
    cmp byte [rdi + BigInt.sign], -1
    jne .positive_number
    mov byte [rsi + rcx], '-'
    inc rcx
    dec rdx
.positive_number:
    xor r8, r8
    mov r8d, [rdi + BigInt.size]
	push r12
	xor r12, r12
	mov r12d, [rdi + BigInt.digits]
    lea r9, [r12 + r8 * 4 - 4]
	pop r12

.write_digits:
    cmp rdx, 0  
    je .add_zero
    cmp r8, 0
    je .add_zero

    mpush rcx, rdx, r8, r9, rdi, rsi, r12
    xor r12, r12
    mov r12d, [r9]
    intToStr r12
    
    mov r11, rcx
    mpop rcx, rdx, r8, r9, rdi, rsi, r12

    cmp r8d, [rdi + BigInt.size]
    jne .continue
    deleteZeroesFromString rax, r11
.continue; 
    cmp rdx, r11
    jge .write_one_digit
    mov r11, rdx
    jmp .write_one_digit
.write_one_digit:
    xor r10, r10
.write_decimal_digit:
    cmp r10, r11
    je .prepare_for_next_iteration
    push r11
    xor r11, r11
    mov r11b, byte [rax + r10]
    mov byte [rsi + rcx], r11b
    pop r11
    inc r10
    inc rcx
    dec rdx
    jmp .write_decimal_digit
.prepare_for_next_iteration:
    sub r9, 4
    dec r8

    callFreeVector rax

    jmp .write_digits
.add_zero:
    mov byte [rsi + rcx], 0
    jmp .finish
.finish
    ret

; void biDelete(BigInt bi);
; bi -- RDI
; удаляет ранее созданное длинное число
biDelete:
    callFree rdi
    ret

; int biSign(BigInt bi);
; bi -- RDI
; возвращает знак числа
biSign:
    xor rax, rax
    cmp byte [rdi + BigInt.sign], -1
    jne .write_non_negative
    mov rax, -1
.write_non_negative:
    mov al, byte [rdi + BigInt.sign]
    ret

; void biAdd(BigInt a, BigInt b);
; a += b
; a -- RDI
; b -- RSI
; result in RDI
biAdd:
	createBigInt
	push rdi
	mov rdi, rax
	biCopy rdi, rsi
	mov rax, rdi
	pop rdi

	xor r10, r10
	xor r11, r11
	mov r10b, byte [rdi + BigInt.sign]
	mov r11b, byte [rax + BigInt.sign]
	
	cmp r11, 0
	je .finish
	cmp r10, 0
	je .copy
	cmp r10, 1
	je .first_positive
	cmp r11, 1
	je .first_negative_second_positive
	jmp .add
.first_negative_second_positive:
	biNegate rax

	push rsi
	mov rsi, rax
	call biSub
	pop rsi
	jmp .finish
.first_positive:
	cmp r11, 1
	jg .first_positive_second_negative
	jmp .add
.first_positive_second_negative:
	biNegate rax

	push rsi
	mov rsi, rax	
	call biSub
	pop rsi
	jmp .finish
.add:
	xor r10, r10
	xor r11, r11
	xor r8, r8
	xor r9, r9
	mpush r12, r13, r14, r15
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15
	mov r12d, [rdi + BigInt.digits]
	mov r13d, [rax + BigInt.digits]
	xor rcx, rcx
	mov r14d, [rdi + BigInt.digits]
	mov r15d, [rax + BigInt.digits]
.sum_digits:
	mov r10d, [rdi + BigInt.size]
	mov r11d, [rax + BigInt.size]
	
	lea rdx, [r14 + r10 * 4]
	cmp r12, rdx
	jl .first_non_zero
	xor r8, r8
	jmp .second
.first_non_zero:
	mov r8d, [r12]
.second:
	lea rdx, [r15 + r11 * 4]
	cmp r13, rdx
	jl .second_non_zero
	xor r9, r9
	jmp .check_finish
.second_non_zero:
	mov r9d, [r13]
.check_finish:
	cmp r8, 0
	jne .ok
	cmp r9, 0
	jne .ok
	cmp rcx, 0
	jne .ok
	jmp .sum_is_done
.ok:
	add r8, r9
	add r8, rcx
	xor rcx, rcx
	cmp r8, BASE
	jl .write_digit
	mov rcx, 1
	sub r8, BASE
.write_digit:
	lea rdx, [r14 + r10 * 4]
	cmp r12, rdx
	jl .non_zero
	mpush r8
	mov r8, 0
	push rbx
	mov rbx, rdi
	pushBack rbx, r8
	pop rbx
	mpop r8
.non_zero:
	mov [r12], r8d
	add r12, 4
	add r13, 4
	jmp .sum_digits
.sum_is_done:
	mpop r12, r13, r14, r15
	jmp .finish
.copy:
	biCopy rdi, rax
	callFree rax
.finish:
	ret

; void biSub(BigInt a, BigInt b);
; a -= b
; a -- RDI
; b -- RSI
; result -- RDI
biSub:
	push r15
	mov r15, 1
 	createBigInt
	push rdi
	mov rdi, rax
	biCopy rdi, rsi
	mov rax, rdi
	pop rdi

	xor r10, r10
	xor r11, r11
	mov r10b, byte [rdi + BigInt.sign]
	mov r11b, byte [rax + BigInt.sign]
	cmp r11, 0
	je .finish
	cmp r10, 0
	je .copy
	cmp r10, 1
	je .first_positive
	cmp r11, 1
	je .first_negative_second_positive
	mov r15, -1
	biNegate rdi
	biNegate rax
	jmp .sub
.first_negative_second_positive:
	biNegate rax
	push rsi
	mov rsi, rax
	call biAdd
	pop rsi
	jmp .finish
.first_positive:
	cmp r11, 1
	jg .first_positive_second_negative
	jmp .sub
.first_positive_second_negative:
	biNegate rax
	push rsi
	mov rsi, rax
	call biAdd
	pop rsi
	jmp .finish
.sub:
	mpush rax, rsi
	mov rsi, rax
	call biCmp
	mov rcx, rax
	mpop rax, rsi

	cmp rcx, -1
	jne .are_equal

	mpush rdi, rsi
	createBigInt
	mov rsi, rdi
	mov rdi, rax
	biCopy rdi, rsi
	mov r11, rdi
	mpop rdi, rsi
	
	mpush rdi, rsi, r11
	createBigInt
	mov rdi, rax
	biCopy rdi, rsi
	mov r10, rdi
	mpop rdi, rsi, r11
	
	mpush rdi, rsi
	mov rdi, r10
	mov rsi, r11
	mpush r10, r11
	call biSub
	mpop r10, r11
	mov r10, rdi
	mpop rdi, rsi
	
	push rsi
	mov rsi, r10
	biCopy rdi, rsi
	pop rsi
	biNegate rdi
	jmp .finish
.are_equal:
	cmp rcx, 0
	jne .go_sub
	
	mov byte [rdi + BigInt.sign], 0
	mov dword [rdi + BigInt.size], 1
	mov dword [rdi + BigInt.capacity], DEFAULT_CAPACITY
	xor r11, r11
	mov r11d, [rdi + BigInt.digits]
	mov dword [r11], 0
	jmp .finish
.go_sub:
	xor r10, r10
	xor r11, r11
	xor r8, r8
	xor r9, r9
	mpush r12, r13, r14, r15
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15
	mov r12d, [rdi + BigInt.digits]
	mov r13d, [rax + BigInt.digits]
	xor rcx, rcx
	mov r14d, [rdi + BigInt.digits]
	mov r15d, [rax + BigInt.digits]
.sub_digits:
	mov r10d, [rdi + BigInt.size]
	mov r11d, [rax + BigInt.size]
	
	lea rdx, [r14 + r10 * 4]
	cmp r12, rdx
	jl .first_non_zero
	xor r8, r8
	jmp .second
.first_non_zero:
	mov r8d, [r12]
.second:
	lea rdx, [r15 + r11 * 4]
	cmp r13, rdx
	jl .second_non_zero
	xor r9, r9
	jmp .check_finish
.second_non_zero:
	mov r9d, [r13]
.check_finish:
	cmp r8, 0
	jne .ok
	cmp r9, 0
	jne .ok
	cmp rcx, 0
	jne .ok
	jmp .sub_is_done
.ok:
	sub r8, r9
	sub r8, rcx
	xor rcx, rcx
	cmp r8, 0
	jge .write_digit
	mov rcx, 1
	add r8, BASE
.write_digit:
	lea rdx, [r14 + r10 * 4]
	cmp r12, rdx
	jl .non_zero
	mpush r8
	mov r8, 0
	push rax
	mov rax, rdi
	pushBack rax, r8
	pop rax
	mpop r8
.non_zero:
	mov [r12], r8d
	add r12, 4
	add r13, 4
	jmp .sub_digits
.sub_is_done:
	mpop r12, r13, r14, r15
	jmp .finish
.copy:
	biNegate rax
	biCopy rdi, rax
	callFree rax
.finish:
	xor r8, r8
	mov r8b, byte [rdi + BigInt.sign]
	imul r8, r15
	mov byte [rdi + BigInt.sign], r8b
	pop r15
	ret 

biMul:
    ret

biDivRem:
    ret

; int biCmp(BigInt a, BigInt b);
; a -- RDI
; b -- RSI
; результат в RAX
; сравнивает два длинных числа
; возвращает 0, если a = b, < 0, если a < b, > 0, если a > b
biCmp:
    push rcx
	xor r8, r8
    xor r9, r9
	mov rdx, 1
	
    mov r8b, byte [rdi + BigInt.sign]
    mov r9b, byte [rsi + BigInt.sign]
    cmp r8, 255
	jne .ok1
	sub r8, 256
.ok1:
	cmp r9, 255
	jne .ok2
	sub r9, 256
.ok2:
	cmp r8, r9
    jl .below
    jg .above

	cmp byte [rdi + BigInt.sign], 1
	je .positive_numbers
	mov rdx, -1
.positive_numbers:
	mov r8d, [rdi + BigInt.size]
    mov r9d, [rsi + BigInt.size]
    cmp r8, r9
    jl .below
    jg .above

	push r12
	xor r12, r12
	mov r12d, [rdi + BigInt.digits]
    lea r8, [r12 + r8 * 4 - 4]
	mov r12d, [rsi + BigInt.digits]
    lea r9, [r12 + r9 * 4 - 4]
	pop r12
	xor rcx, rcx
.compare_digits:
    lea r10, [rdi + BigInt.size]
	cmp ecx, [r10]
	je .equal
    
    xor r10, r10
    xor r11, r11
    mov r10d, [r8]
    mov r11d, [r9]
    cmp r10, r11
    jl .below
    jg .above
    
    sub r8, 4
    sub r9, 4
	inc rcx
    jmp .compare_digits        
.below:
    mov rax, -1
    jmp .finish
.above:
    mov rax, 1
    jmp .finish
.equal:
    mov rax, 0
    jmp .finish
.finish:
	imul rax, rdx
	pop rcx
    ret

section .data

intFormat:    db '%d', 10, 0
intFormat2:   db '!!! %d', 10, 0
stringFormat: db '%s', 10, 0
