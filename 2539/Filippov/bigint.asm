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

; Обнуляет все регистры, переданные в аргументах
%macro mzero 1-*
	%rep %0
		xor %1, %1
		%rotate 1
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
	mov r14, r13						; R14 -- указатель на новый вектор, его не меняем
%%fill_zeroes:     
	cmp r12, rdi
	je %%finish
	mov dword [r13], 0					; записываем в цифру 0
	add r13, 4							; переходим к следующей цифре
	add r12, 4						
	jmp %%fill_zeroes
%%finish:
	mov [%1 + BigInt.digits], r14d		; указатель на вектор с цифрами -- R14, который мы запомнили
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
    mov rdi, DEFAULT_CAPACITY			; вызываем функцию создания вектора по вместимости с DEFAULT_CAPACITY
	mov r9, rdi							; 
    createBigIntWithCapacity r9			; 
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

    mzero rdi, rsi
	mov edi, [%1 + BigInt.size] 	; RDI -- размер числа
    mov esi, [%1 + BigInt.capacity] ; RSI -- вместимость числа
    mov rdx, %1                 	; RDX -- само длинное число
                                	; можем вызвать ensureCapacity, он все сделает, что нам надо
	mpush %2, rax
	call ensureCapacity				
    mpop %2, rax

	mpush r12
	xor r12, r12
	mov r12d, [%1 + BigInt.digits]	; 
    mov dword [r12 + rdi * 4], %2d 	; добавляем в конец числа новую цифру

   	inc rdi                     	; увеличиваем на один RDI -- размер числа
    mov [%1 + BigInt.size], edi    	; и изменяем размер в указателе, конец

	mpop r12
	mpop rdi, rsi, rdx, rcx
%endmacro

; переводит int в строку длиной ровно BASE_LENGTH символов (дополняет нулями)
; %1 -- число, которое нужно перевести в строку
; результат в RAX
%macro intToStr 1
    push %1
    push %1    
    mov rdi, BASE_LENGTH			; 
	inc rdi							;
    push rdi						; выделяем BASE_LENGTH + 1 байтов для строки (+1 для \0)
    call malloc						;
    pop rdi							;
    pop %1
       
    mov r8, %1						; R8 -- текущее число
    xor rcx, rcx					; RCX -- длина числа
%%write_decimal_digit:
    cmp r8, 0
    je %%get_string

    mpush rax, rcx					
    mov rax, r8						;
    xor rdx, rdx					;
    mov r9, 10						; Делим текущее число (R8) на 10, получаем остаток -- новую цифру
    div r9							; R8 /= 10
    mov r8, rax						; R9 = R8 % 10
    mov r9, rdx
    mpop rax, rcx

    push r9							; кладем цифру на стек, потом мы соберем их в обратном порядке и получим исходное число
    inc rcx							; увеличиваем длину числа на 1
    jmp %%write_decimal_digit
%%get_string:
    xor rdx, rdx					; RDX -- номер текущего символа, который мы пишем в строку
%%write_digits_to_string:
    cmp rcx, 0						; Если больше нет цифр, переходим к фазе добавления нулей в начало числа
    je %%add_zeroes

    pop r9							; забираем со стека цифру числа
    add r9, '0'						; делаем из нее символ
    mov byte [rax + rdx], r9b		; добавляем новый символ в конец строки
    inc rdx							; 
    dec rcx							; уменьшаем количество цифр в числе, двигаем указатель в строке
    jmp %%write_digits_to_string
%%add_zeroes:
    mov r8, BASE_LENGTH				; количество нулей, которые нужно добавить, равно BASE_LENGTH - RDX (чтобы длина была ровно BASE_LENGTH) 
    sub r8, rdx						;
    dec rdx
%%loop:								; переносим все цифры в конец строки, чтобы потом в начало добавить нули
    cmp rdx, 0						; RDX = 0 => все цифры перенесены, начинаем добавлять нули
    jl %%add_to_begin
    lea r9, [rax + rdx]				
    push r11
    xor r11, r11					;
    mov r11b, byte [r9]				; [RAX + RDX] переходит в [RAX + RDX + R8]
    mov byte [r9 + r8], r11b		;
    pop r11							; 
    dec rdx							; Уменьшаем RDX -- переходим к предыдущей цифре
    jmp %%loop
%%add_to_begin:
    cmp r8, 0						
    je %%finish
    mov byte [rax + r8 - 1], '0'	; записываем ноль в начало строки, пока длина не станет BASE_LENGTH
    dec r8							;
    jmp %%add_to_begin
%%finish
    mov byte [rax + BASE_LENGTH], 0 ; добавляем \0 в конец строки
    mov rcx, BASE_LENGTH			; RCX -- длина итоговой строки
    pop %1
%endmacro

; удаляет нули из начала строки
; %1 -- строка
; %2 -- ее длина
%macro deleteZeroesFromString 2
    push r12
    xor r12, r12
%%loop:								; считаем количество нулей в начале строки
    cmp byte [%1 + r12], '0'		;
    jne %%delete_zeroes
    inc r12
    jmp %%loop
%%delete_zeroes:
    push r13
    mov r13, r12					; R13 -- текущий индекс в строке
%%write_digit:
    cmp r13, %2						; Если конец строки, выходим
    jg %%finish
    push r14
    lea r14, [%1 + r13]				; R14 -- указатель на текующую цифру
    push r11						;
    xor r11, r11					;
    mov r11b, byte [r14]			; R11 -- текущая цифра
    sub r14, r12					; переносим ее в начало
    mov byte [r14], r11b			; 
    mpop r14, r11
	inc r13
    jmp %%write_digit
%%finish:
    sub %2, r12						; новая длина меньше на количество нулей в строке
	mpop r12, r13
%endmacro

; удаляет нули из начала длинного числа
; %1 -- длинное число
%macro deleteZeroesFromBigInt 1
    mpush rdi, rcx
    xor rdi, rdi
    mov edi, [%1 + BigInt.size]		; RDI -- текущий индекс в векторе цифр

	push r12
	xor r12, r12
	mov r12d, [%1 + BigInt.digits]	; 
    lea rcx, [r12 + rdi * 4 - 4]	; RCX -- указатель на текущую цифру
	pop r12
%%while_zero:
	cmp rdi, 0						; Если индекс равен 0, то все число состоит из нулей
	je %%set_zero					;
    cmp dword [rcx], 0				; Если нулей больше нет, переходим к изменению размера
    jne %%change_size
    sub rcx, 4						; Переходим к предыдущей цифре
    dec rdi							; Уменьшаем указатель на текущую цифру на один
	jmp %%while_zero
%%set_zero:
	mov byte [%1 + BigInt.sign], 0	; Число равно 0 -- знак равен 0, размер равен 1
    mov rdi, 1						;
%%change_size:
    mov [%1 + BigInt.size], edi		; Записываем в длинное число новый размер
    mpop rdi, rcx
%endmacro

; копирует длинное число
; %1 -- длинное число, в которое надо скопировать
; %2 -- длинное число, которое надно скопировать
%macro biCopy 2
	xor r8, r8
	mov r8b, byte [%2 + BigInt.sign]	; Копируем знак
	mov byte [%1 + BigInt.sign], r8b	; 

	mov r8d, [%2 + BigInt.size]			; Копируем размер
	mov [%1 + BigInt.size], r8d			;

	mov r8d, [%2 + BigInt.capacity]		; Копируем вместимость
	mov [%1 + BigInt.capacity], r8d		;

	mov r8d, [%2 + BigInt.size]			; R8 -- длина длинного числа

	mpush r15, %2, r8					
	mov r15, %1							; Создаем новый вектор для нового числа 
	newVector r15, r8					;
	mpop r15, %2, r8

	push rcx
	mzero rcx, r10, r11					; RCX -- индекс текущей цифры
	mov r10d, [%2 + BigInt.digits]		; R10 -- указатель на цифру в копируемом числе
	mov r11d, [%1 + BigInt.digits]		; R11 -- указатель на цифру в числе, в которое мы копируем
%%copy_digits:
	cmp rcx, r8
	je %%finish
	push r12
	xor r12, r12						; Копируем одну цифру
	mov r12d, [r10]						;
	mov [r11], r12d						;
	pop r12
	add r10, 4							; И переходим к следующей
	add r11, 4							;
	inc rcx								;
	jmp %%copy_digits
%%finish:
	pop rcx
%endmacro

; Унарный минус длинного числа
; %1 -- длинное число
%macro biNegate 1
	mpush r15
	xor r15, r15
	mov r15b, byte [%1 + BigInt.sign]	; Делаем neg к знаку, и все правильно сработает (-1 -> 1, 0 -> 0, 1 -> -1)
	neg r15								;
	mov byte [%1 + BigInt.sign], r15b	;
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
    createBigInt							; Создаем длинное число -- ответ (хранится в RAX)
    mov byte [rax + BigInt.sign], 1			; Изначально скажем, что оно положительное
    xor rcx, rcx
    cmp byte [rdi], '-'						; Разбираем случай минуса в начале
    jne .positive_number
    mov byte [rax + BigInt.sign], -1		; Если есть, значит число отрицательное
    inc rcx
.positive_number:							; Теперь считаем, что число положительное -- знак мы уже поставили
    cmp byte [rdi + rcx], 0					; Если строка равна "-", то кидаем ошибку
    je .error_occurred
    mov r9, rcx								; R9 -- текущий индекс в строке
    xor r10, r10							; R10 -- количество нулей
.count_zeroes:								; Считаем количество нулей в начале строки
    cmp byte [rdi + r9], '0'				
    jne .not_zero_digit
    inc r9
    inc r10
    jmp .count_zeroes
.not_zero_digit:							; Проверяем, правда ли, что строка состоит из одних нулей
    cmp byte [rdi + r9], 0					
    jne .number_is_not_zero					
    mov byte [rax + BigInt.sign], 0			; Если да, записываем в знак 0, в длину числа -- 1, выходим
	mov dword [rax + BigInt.size], 1		;
    jmp .finish								;
.number_is_not_zero:
    mpush rax, rdx
    xor rdx, rdx							; Делим количество нулей на BASE_LENGTH -- узнаем, сколько цифр-нулей будет в начале
    mov rax, r10							; И пропускаем их
    mov r10, BASE_LENGTH					
    div r10
    imul rax, BASE_LENGTH					; RAX = [R10 / 10] * 10 -- на столько можно подвинуть указатель на цифру, все эти нули нам не нужны
    add rcx, rax							;
    mpop rax, rdx

    mpush rax, rdi, rcx 
    xor rax, rax
    call strlen								; узнаем длину строки
    mov r8, rax
    mpop rax, rdi, rcx
    lea rdx, [rdi + r8 - 1]					; RDX -- указатель на текущий символ строки (изначально на последний)
    add rcx, rdi							; Теперь RCX -- указатель на первый символ строки, который нас интересует (нас интересуют символы [RCX..RDX])
    xor r8, r8								; R8 -- текущая цифра (R8 < BASE)
    mov r10, 1								; R10 -- степень десятки
.process_digits:
    cmp rdx, rcx							; Если RDX < RCX, нам больше нечего рассматривать, заканчиваем
    jl .finally
    
    cmp byte [rdx], '0'						; Если цифра < '0' или > '9', она неккоректна, кидаем ошибку
    jl .error_occurred						;
    cmp byte [rdx], '9'						;
    jg .error_occurred						;
    xor r9, r9								
    mov r9b, byte [rdx]						; R9 -- цифра из строки
    sub r9, '0'								;
    dec rdx									; уменьшаем указатель на цифру в строке на один

    cmp r10, BASE							; Если R10 == BASE, значит цифру надо добавить в конец вектора длинного числа
    je .push_back
    imul r9, r10							; R9 * R10 -- то, что надо добавить к текущей цифре
    add r8, r9								; Добавляем
    imul r10, 10							; Увеличиваем степень десятки
    jmp .process_digits
.push_back:
    mov r11, r9								; Запоминаем текущую цифру в R11
    mpush r11				
    pushBack rax, r8						; Добавляем R8 в конец массива цифр ответа
    mpop r11
    mov r10, 10								; Степень десятки теперь равна 10, а R8 = R11 -- запомненной цифре
    mov r8, r11								;
    
    jmp .process_digits
.finally:
    cmp r8, 0								; Если в конце R8 != 0, надо его тоже добавить в вектор
    je .finish
    pushBack rax, r8
    jmp .finish
.error_occurred:
    ;callFree rax							; Если произошла ошибка, возвращаем NULL
    xor rax, rax
.finish:
    ret

; void biToString(BigInt bi, char *buffer, size_t limit);
; bi -- RDI
; buffer -- RSI
; limit -- RDX
biToString:
    xor rcx, rcx
    dec rdx									; Вычитаем из limit единицу -- в конце мы просто запишем \0
    cmp rdx, 0								; Если limit теперь стал равным 0, значит можно заканчивать
    je .add_zero
    cmp byte [rdi + BigInt.sign], 0			; Проверяем, равно ли длинное число нулю
    jne .non_zero_number
    mov byte [rsi + rcx], '0'				; Если да, просто записываем в строку ноль и выходим (выходим = записываем \0 в конец строки)
    inc rcx
    jmp .add_zero
.non_zero_number:
    cmp byte [rdi + BigInt.sign], -1		; Проверяем, отрицательное ли число
    jne .positive_number
    mov byte [rsi + rcx], '-'				; Если да, записываем в строку '-' и дальше считаем, что оно положительное
    inc rcx									;
    dec rdx									;
.positive_number:
    xor r8, r8								; R8 -- длина числа
    mov r8d, [rdi + BigInt.size]			;
	push r12
	xor r12, r12
	mov r12d, [rdi + BigInt.digits]			; R9 -- указатель на текущую цифру (изначально последнюю)
    lea r9, [r12 + r8 * 4 - 4]				; 
	pop r12

.write_digits:
    cmp rdx, 0  							; Проверяем, что либо лимит закончился, либо строка
    je .add_zero							; Если хотя бы одно из двух, выходим
    cmp r8, 0
    je .add_zero

    mpush rcx, rdx, r8, r9, rdi, rsi, r12
    xor r12, r12
    mov r12d, [r9]							; Переводим текущую цифру в строку с ровно BASE_LENGTH символами с помощью intToStr
    intToStr r12							;
    
    mov r11, rcx							; R11 -- новая длина строки
    mpop rcx, rdx, r8, r9, rdi, rsi, r12

    cmp r8d, [rdi + BigInt.size]			; Узнаем, последнюю ли мы цифру сейчас записываем
    jne .continue							; Если да, нужно удалить все лидирующие нули -- число с нуля начинаться не может
    deleteZeroesFromString rax, r11			;
.continue; 
    cmp rdx, r11							; Сравниваем лимит и длину числа
    jge .write_one_digit					; Если limit >= длины, просто пишем число
    mov r11, rdx							; Если limit < длины, пишет первые limit символов
    jmp .write_one_digit					; В итоге R11 -- количество первых символов строки, которые нам надо вывести
.write_one_digit:
    xor r10, r10
.write_decimal_digit:						; Записываем первые R11 символов в строку-результат
    cmp r10, r11							; Если R10 == R11, все записали
    je .prepare_for_next_iteration
    push r11
    xor r11, r11
    mov r11b, byte [rax + r10]				; Добавляем один символ
    mov byte [rsi + rcx], r11b				;
    pop r11
    inc r10
    inc rcx
    dec rdx
    jmp .write_decimal_digit
.prepare_for_next_iteration:
    sub r9, 4								; Переходим к следующей цифре длинного числа
    dec r8									;

    callFreeVector rax						; Удаляем строку, она нам больше не нужна

    jmp .write_digits
.add_zero:
    mov byte [rsi + rcx], 0					; В самом конце добавляем в конец строки \0
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
    xor rax, rax						; Если знак равен -1, то byte [rdi + BigInt.sign] = 255, нас это не устраивает
    cmp byte [rdi + BigInt.sign], -1	; Если знак не равен -1, то пишем просто его
    jne .write_non_negative
    mov rax, -1							; Иначе записываем в rax -1
.write_non_negative:
    mov al, byte [rdi + BigInt.sign]	; Число >= 0, записываем в RAX его знак
    ret

; void biAdd(BigInt a, BigInt b);
; a += b
; a -- RDI
; b -- RSI
; result in RDI
biAdd:
	createBigInt						; второе число не должно измениться, создадим новое и скопируем в него второе число
	push rdi
	mov rdi, rax
	biCopy rdi, rsi						; копируем второе число в RAX
	mov rax, rdi
	pop rdi

	mzero r10, r11
	mov r10b, byte [rdi + BigInt.sign]	; R10 -- знак первого числа
	mov r11b, byte [rax + BigInt.sign]	; R11 -- знак второго числа
	
	cmp r11, 0							; Если второе число -- ноль, ничего не делаем (a + 0 = a)
	je .finish
	cmp r10, 0							; Если первое число -- ноль, копируем второе число в первое
	je .copy
	cmp r10, 1							
	je .first_positive					
	cmp r11, 1							; a < 0
	je .first_negative_second_positive	
	jmp .add							; a < 0, b < 0, просто складываем числа как положительные, все будет правильно
.first_negative_second_positive:		; a < 0, b > 0
	biNegate rax						; делаем унарный минус к b, вычитаем (a + b = a - (-b))

	push rsi
	mov rsi, rax
	call biSub
	pop rsi
	jmp .finish
.first_positive:						; a > 0
	cmp r11, 1
	jg .first_positive_second_negative  
	jmp .add							; a > 0, b > 0, просто складываем
.first_positive_second_negative:
	biNegate rax						; a > 0, b < 0
										; Делаем унарный минус к b, вычитаем
	push rsi
	mov rsi, rax	
	call biSub
	pop rsi
	jmp .finish
.add:									; Разобрались со всеми случаями, теперь просто складываем два длинных положительных числа
	mpush r12, r13, r14, r15
	mzero rcx, r8, r9, r10, r11, r12, r13, r14, r15
	mov r12d, [rdi + BigInt.digits]		; R12 -- указатель на цифры первого числа
	mov r13d, [rax + BigInt.digits]		; R13 -- указатель на цифры второго числа
	mov r14, r12						; R14 -- указатель на цифры первого числа (не меняется)
	mov r15, r13						; R15 -- указатель на цифры второго числа (не меняется)
										; RCX -- перенос
.sum_digits:
	mov r10d, [rdi + BigInt.size]		; R10 -- длина первого числа
	mov r11d, [rax + BigInt.size]		; R11 -- длина второго числа
	
	lea rdx, [r14 + r10 * 4]			; RDX -- указатель на конец вектора цифра первого числа
	cmp r12, rdx						; Если R12 < RDX, то текущая цифра первого числа не 0
	jl .first_non_zero
	xor r8, r8							; Иначе -- она ноль
	jmp .second
.first_non_zero:
	mov r8d, [r12]						; Пишем в R8 текущую цифру первого числа
.second:
	lea rdx, [r15 + r11 * 4]			; Аналогично находим текущую цифру второго числа -- R9
	cmp r13, rdx						;
	jl .second_non_zero
	xor r9, r9							; Тут она 0
	jmp .check_finish
.second_non_zero:
	mov r9d, [r13]						; А тут нет, записываем ее в R9
.check_finish:
	cmp r8, 0							; Если обе цифры равны 0 и перенос тоже, заканчиваем сложение
	jne .ok
	cmp r9, 0
	jne .ok
	cmp rcx, 0
	jne .ok
	jmp .sum_is_done
.ok:
	add r8, r9							; R8 = R8 + R9 + RCX
	add r8, rcx
	xor rcx, rcx
	cmp r8, BASE						; Если R8 >= BASE, записываем 1 в перенос, вычитаем BASE из R8
	jl .write_digit
	mov rcx, 1
	sub r8, BASE
.write_digit:
	lea rdx, [r14 + r10 * 4]			; Иначе цифра нормальная и можно просто записать ее в конец ответа
	cmp r12, rdx
	jl .non_zero
	mpush r8							; Если в числе не хватает цифр, добавим 0 в конец и запишем новую цифру вместо него
	mov r8, 0
	push rbx
	mov rbx, rdi
	pushBack rbx, r8
	pop rbx
	mpop r8
.non_zero:
	mov [r12], r8d						; Записываем в конец новую цифру
	add r12, 4							; И переходим к следующим цифрам
	add r13, 4
	jmp .sum_digits
.sum_is_done:
	mpop r12, r13, r14, r15
	jmp .finish
.copy:
	biCopy rdi, rax						; В случае a = 0 копируем b в а и удаляем скопированное число b
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
	mov r15, 1								; R15 -- число, на которое надо домножить знак ответа (в некоторых случаях в конце знак ответа нам надо будет изменить)
 	createBigInt							; Второе число не должно измениться, поэтому создаем новое длинное число
	push rdi								; И копируем в него второе число (RSI)
	mov rdi, rax
	biCopy rdi, rsi
	mov rax, rdi
	pop rdi

	mzero r10, r11
	mov r10b, byte [rdi + BigInt.sign]		; R10 -- знак первого числа
	mov r11b, byte [rax + BigInt.sign]		; R11 -- знак второго числа
	cmp r11, 0								; Если b = 0, ничего не делаем (a - 0 = a)
	je .finish
	cmp r10, 0								; Если a = 0, копируем b в a и выходим
	je .copy
	cmp r10, 1
	je .first_positive
	cmp r11, 1								; a < 0
	je .first_negative_second_positive
	neg r15									; a < 0, b < 0, применяем унарный минус к обоим числам, вычитаем их
	biNegate rdi							; При этом записываем в R15 -1 -- запоминаем, что в конце у результата надо изменить знак
	biNegate rax
	jmp .sub
.first_negative_second_positive:			; a < 0, b > 0
	biNegate rax							; Применяем унарный минус ко второму числу, складываем (a - b = a + (-b))
	push rsi
	mov rsi, rax
	call biAdd
	pop rsi
	jmp .finish
.first_positive:							; a > 0
	cmp r11, 1
	jg .first_positive_second_negative
	jmp .sub								; a > 0, b > 0, просто вычитаем
.first_positive_second_negative:
	biNegate rax							; a > 0, b < 0, применяем унарный минус ко второму числу, складываем (a - b = a + (-b))
	push rsi
	mov rsi, rax
	call biAdd
	pop rsi
	jmp .finish
.sub:										; Разобрали все случаи, осталось реализовать вычитание двух положительных чисел
	mpush rax, rsi
	mov rsi, rax
	call biCmp								; Сравниваем a и b (вычитать мы будем только из большего меньшее)
	mov rcx, rax
	mpop rax, rsi

	cmp rcx, -1								
	jne .are_equal
											; a < b
	mpush rdi, rsi							; Поменяем a и b местами, а потом вычтем
	createBigInt
	mov rsi, rdi
	mov rdi, rax
	biCopy rdi, rsi							; R11 -- a
	mov r11, rdi
	mpop rdi, rsi
	
	mpush rdi, rsi, r11
	createBigInt
	mov rdi, rax
	biCopy rdi, rsi
	mov r10, rdi							; R10 -- b
	mpop rdi, rsi, r11
	
	mpush rdi, rsi
	mov rdi, r10
	mov rsi, r11
	mpush r10, r11							; Считаем R10 - R11 = b - a, это посчитается корректно (т.к. b > a)
	call biSub
	mpop r10, r11
	mov r10, rdi
	mpop rdi, rsi
	
	push rsi
	mov rsi, r10
	biCopy rdi, rsi							; Копируем результат в a, вызываем от него унарный минус (т.к. a - b = -(b - a)), выходим
	pop rsi
	biNegate rdi
	jmp .finish
.are_equal:									
	cmp rcx, 0								
	jne .go_sub
											; a = b => a - b = 0
	mov byte [rdi + BigInt.sign], 0			; Записываем в знак результата 0
	mov dword [rdi + BigInt.size], 1		; В длину -- 1
	mov dword [rdi + BigInt.capacity], DEFAULT_CAPACITY	; В вместимость -- дефолтную вместимость
	xor r11, r11
	mov r11d, [rdi + BigInt.digits]			; В первую цифру -- 0
	mov dword [r11], 0						; В a теперь записан 0, все правильно, выходим
	jmp .finish					
.go_sub:									; Основная часть процедуры: a > 0, b > 0, a > b
	mpush r12, r13, r14, r15
	mzero rcx, r8, r9, r10, r11, r12, r13, r14, r15
	mov r12d, [rdi + BigInt.digits]			; R12 -- указатель на цифры первого числа
	mov r13d, [rax + BigInt.digits]			; R13 -- указатель на цифры второго числа
	mov r14, r12							; R14 -- указатель на цифры первого числа (не изменяется)
	mov r15, r13							; R15 -- указатель на цифры второго числа (не изменяется)
											; RCX -- перенос
.sub_digits:			
	mov r10d, [rdi + BigInt.size]			; R10 -- длина первого числа
	mov r11d, [rax + BigInt.size]			; R11 -- длина второго числа
	
	lea rdx, [r14 + r10 * 4]				; RDX -- указатель на конец первого числа
	cmp r12, rdx							
	jl .first_non_zero
	xor r8, r8								; R8 -- первая цифра, если R12 >= RDX, она равна 0, иначе -- цифре по данному адресу (R12)
	jmp .second
.first_non_zero:
	mov r8d, [r12]							; Записываем в R8 цифру по адресу R12
.second:
	lea rdx, [r15 + r11 * 4]			  	; Аналогично поступаем со второй цифрой -- R9
	cmp r13, rdx
	jl .second_non_zero
	xor r9, r9								; R13 >= RDX => R9 = 0
	jmp .check_finish
.second_non_zero:
	mov r9d, [r13]							; R13 < RDX => R9 -- цифра по адресу R13
.check_finish:
	cmp r8, 0								; Если обе цифры равны нулю и перенос тоже, вычитание закончено
	jne .ok
	cmp r9, 0
	jne .ok
	cmp rcx, 0
	jne .ok
	jmp .sub_is_done
.ok:										; Продолжаем вычитание
	sub r8, r9								; R8 = R8 - R9 - RCX
	sub r8, rcx
	xor rcx, rcx
	cmp r8, 0								; Если R8 < 0, записываем в перенос 1 и прибавляем к R8 BASE
	jge .write_digit
	mov rcx, 1
	add r8, BASE
.write_digit:								; Теперь R8 >= 0, можно записать ее в ответ
	lea rdx, [r14 + r10 * 4]
	cmp r12, rdx							; Если в a не хватает цифр, чтобы записать просто по адресу R12, делаем pushBack 0, а потом записываем
	jl .non_zero
	mpush r8
	mov r8, 0
	push rax
	mov rax, rdi
	pushBack rax, r8						; Делаем pushBack 0, теперь цифр хватает
	pop rax
	mpop r8
.non_zero:
	mov [r12], r8d							; Теперь можно спокойно записать новую цифру в ответ (число а)
	add r12, 4								; И перейти к следующим цифрам
	add r13, 4								;
	jmp .sub_digits
.sub_is_done:
	mpop r12, r13, r14, r15
	callFree rax
	jmp .finish
.copy:
	biNegate rax							; Если a = 0, копируем число b в число а, удаляем RAX (копия RSI нам не нужна) и выходим
	biCopy rdi, rax
	callFree rax
.finish:
	xor r8, r8
	mov r8b, byte [rdi + BigInt.sign]		; В конце умножаем знак ответа на R15 -- возможная несовместимость, которую мы запомнили
	imul r8, r15
	mov byte [rdi + BigInt.sign], r8b
	pop r15
	ret 

; void biMul(BigInt a, BigInt b);
; a *= b
; a -- RDI
; b -- RSI
biMul:
	mzero r8, r9
	mov r8b, byte [rdi + BigInt.sign]
	mov r9b, byte [rsi + BigInt.sign]
	cmp r8, 0
	jne .first_sign_not_zero
	mov byte [rdi + BigInt.sign], 0
	mov dword [rdi + BigInt.size], 1
	xor r8, r8
	mov r8d, [rdi + BigInt.digits]
	mov dword [r8], 0
	jmp .zero_finish 
.first_sign_not_zero:
	cmp r9, 0
	jne .second_sign_not_zero
	mov byte [rdi + BigInt.sign], 0
	mov dword [rdi + BigInt.size], 1
	xor r8, r8
	mov r8d, [rdi + BigInt.digits]
	mov dword [r8], 0
	jmp .zero_finish
.second_sign_not_zero:
	cmp r8, 255
	jne .ok1
	sub r8, 256
.ok1:
	cmp r9, 255
	jne .ok2
	sub r9, 256
.ok2:
	cmp r8, r9
	jne .write_minus_sign
	mov byte [rdi + BigInt.sign], 1
	jmp .multiply
.write_minus_sign:
	mov byte [rdi + BigInt.sign], -1
.multiply:
	mov r8d, dword [rdi + BigInt.size]
	mov r9d, dword [rsi + BigInt.size]
	lea r8, [r8 + r9]
	mpush rdi, rsi
	createBigIntWithCapacity r8
	mov [rax + BigInt.size], r8d
	mpop rdi, rsi
	xor r8, r8
	mov r8b, byte [rdi + BigInt.sign]
	mov byte [rax + BigInt.sign], r8b
	
	mpush r12, r13, r14, r15
	mzero r8, r12
	mov r12d, [rdi + BigInt.digits]
.fori:
	cmp r8d, [rdi + BigInt.size]
	je .finish
	mzero r9, rcx, r13
	mov r13d, [rsi + BigInt.digits]
.forj:
	cmp r9d, [rsi + BigInt.size]
	jl .mul_digits
	cmp rcx, 0
	je .next_iteration
.mul_digits:
	xor r14, r14
	mov r14d, [rax + BigInt.digits]
	lea r14, [r14 + r8 * 4]
	lea r14, [r14 + r9 * 4]
	
	mzero r10, r11
	mov r10d, [r12]

	cmp r9d, [rsi + BigInt.size]
	jne .second_not_zero
	mov r11, 0
	jmp .mul
.second_not_zero:
 	mov r11d, [r13]
.mul:
	xor r15, r15
	mov r15d, [r14]
	imul r10, r11
	add r15, r10
	add r15, rcx
	mpush rax, rdx, r8, r9, rdi, rsi
	mov rax, r15
	xor r9, r9
	mov r9, BASE
	xor rdx, rdx
	div r9
	mov [r14], edx
	mov rcx, rax
	mpop rax, rdx, r8, r9, rdi, rsi

	inc r9
	add r13, 4	
	jmp .forj
.next_iteration:
	inc r8
	add r12, 4
	jmp .fori
.finish:
	deleteZeroesFromBigInt rax
	push rsi
	mov rsi, rax
	
	biCopy rdi, rsi
	pop rsi
	mpop r12, r13, r14, r15
.zero_finish:
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
	mzero r8, r9
	mov rdx, 1								; RDX -- знак ответа (из-за того, что a < b, но -a > -b иногда ответ надо домножить на -1)
	
    mov r8b, byte [rdi + BigInt.sign]		; R8 -- знак первого числа
    mov r9b, byte [rsi + BigInt.sign]		; R9 -- знак второго числа
    cmp r8, 255								; R8 = 255 => R8 = -1 (потому что byte -- беззнаковый)
	jne .ok1
	sub r8, 256
.ok1:
	cmp r9, 255								; R9 = 255 => R9 = -1
	jne .ok2
	sub r9, 256
.ok2:
	cmp r8, r9								; Теперь знаки правильные, сравниваем их
    jl .below
    jg .above
											; Теперь знаки одинаковые
	cmp byte [rdi + BigInt.sign], 1			; Если оба числа не положительные, скажем, что они положительные, но потом умножим ответ на -1
	je .positive_numbers					;					
	mov rdx, -1								;
.positive_numbers:
	mov r8d, [rdi + BigInt.size]			; R8 -- длина первого числа
    mov r9d, [rsi + BigInt.size]			; R9 -- длина второго числа
    cmp r8, r9								; Сравниваем длины
    jl .below
    jg .above
											; Теперь длины обоих чисел равны
	push r12
	xor r12, r12
	mov r12d, [rdi + BigInt.digits]			; R12 -- указатель на вектор с цифрами первого числа
    lea r8, [r12 + r8 * 4 - 4]				; R8 -- указатель на текущую цифру первого числа (изначально последнюю)
	mov r12d, [rsi + BigInt.digits]			; 
    lea r9, [r12 + r9 * 4 - 4]				; R9 -- указатель на текущую цифру второго числа (изначально последнюю)
	pop r12
	xor rcx, rcx							; RCX -- количество обработанных цифр
.compare_digits:
    lea r10, [rdi + BigInt.size]			; R10 -- длина числа
	cmp ecx, [r10]							; RCX == R10 => все цифры обработаны, числа равны
	je .equal
    
    mzero r10, r11
	mov r10d, [r8]							; R10 -- текущая цифра первого числа
    mov r11d, [r9]							; R11 -- текущая цифра второго числа
    cmp r10, r11							; Если цифры не равны, возвращаем ответ
    jl .below
    jg .above
    
    sub r8, 4								; Переходим к следующим цифрам
    sub r9, 4								;
	inc rcx									; Увеличиваем количество обработанных цифр
    jmp .compare_digits        
.below:										; первое число меньше второго
    mov rax, -1
    jmp .finish
.above:										; первое чисто больше второго
    mov rax, 1
    jmp .finish
.equal:										; числа равны
    mov rax, 0
    jmp .finish
.finish:
	imul rax, rdx							; домножаем ответ на RDX -- его знак, теперь ответ правильный
    ret

section .data

intFormat:    db '%d', 10, 0
intFormat2:   db '!!! %d', 10, 0
stringFormat: db '%s', 10, 0

