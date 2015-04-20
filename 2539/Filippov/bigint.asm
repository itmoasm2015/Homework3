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
; мы можем в этом длинной числе хранить. Изначально вместимость равна 2
; Следующие группы по 4 байта -- цифры числа
; Одна цифра -- число от 0 до BASE - 1
; Число хранится перевернутым, то есть x = digits[0] * BASE^0 + digits[1]*BASE^1 + ...
; Число хранится в десятичной системе счисления, BASE = 10^9

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
    mov rdi, %1
    call free
    popAll
%endmacro

; BigInt createBigIntWithCapacity(size_t capacity);
; создает длинное число по вместимости массива для цифр
; capacity -- RDI
; RAX -- результат
; сохраняет RDI
%macro createBigIntWithCapacity 1
    mov r9, %1                  ; R9 -- вместимость

    mpush rdi, r9
    lea rdi, [r9 * 4 + 9]       ; RDI -- количество байтов, которое надо выделить
    push rdi                    ; Сохраняем его, чтобы не поменялось, вызываем malloc
    call malloc 
    pop rdi                     ; Возвращаем RDI
    pop r9
    mov byte [rax], 0           ; По умолчанию знак числа равен 0
    mov rsi, 1                  ; RSI -- текущая позиция в длинном числе
%%fill_zeroes:
    cmp rsi, rdi                ; RSI = RDI => все заполнили
    je %%finish
    mov dword [rax + rsi], 0    ; Все цифры делаем равными 0
    add rsi, 4                  ; И переходим к следующей цифре
    jmp %%fill_zeroes
%%finish:
    mov [rax + 5], r9d          ; Устанавливаем в числе вместимость, которая лежит в R9
    pop rdi                     
%endmacro

; BigInt createBigInt();
; создает длинное число с вместимостью по умолчанию (DEFAULT_CAPACITY)
; RAX -- результат
; сохраняет RDI
%macro createBigInt 0
    push rdi
    mov rdi, DEFAULT_CAPACITY
    createBigIntWithCapacity rdi
    pop rdi
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
    mpush rbx, rdx, rdi, rsi        ; RBX -- новый указатель на длинное число, RBX надо сохранять
    shl rsi, 1                      ; RSI -- новая вместимость, RSI = RSI_OLD * 2
    push rax
    createBigIntWithCapacity rsi
    mov rbx, rax                    ; RBX -- новое длинное число с новой вместимостью
    mpop rdx, rdi, rsi, rax

    push r11
    xor r11, r11
    mov r11b, byte [rdx]            ; 
    mov byte [rbx], r11b            ; устанавливаем знак RBX
    xor r11, r11                    
    mov r11d, [rdx + 1]             ;    
    mov [rbx + 1], r11d             ; устанавливаем размер длинного числа RBX
    pop r11
    mov r8, 0                       ; R8 -- индекс текущей цифры
.fill_values:                       ; копируем в RBX цифры из RDX
    cmp r8, rdi                     ; R8 = RDI (размер числа) => закончили
    je .before_simple_push_back         
    push r11
    xor r11, r11
    mov r11d, [rdx + r8 * 4 + 9]    ; [RDX + r8 * 4 + 9] -- цифра с индексом R8 числа RDX
    mov [rbx + r8 * 4 + 9], r11d    ; копируем это значение в соответствующую цифру RBX
    pop r11
    inc r8                          ; следующая цифра
    jmp .fill_values
.before_simple_push_back:
    callFree rdx                    ; теперь RDX нам не нужен, можем его удалить

    mov rdx, rbx                    ; а теперь RDX = RBX, то есть новое число
    pop rbx
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
    mov edi, [%1 + 1]           ; RDI -- размер числа
    xor rsi, rsi
    mov esi, [%1 + 5]           ; RSI -- вместимость числа
    mov rdx, %1                 ; RDX -- само длинное число
                                ; можем вызвать ensureCapacity, он все сделает, что нам надо
    mpush r8, %2
    call ensureCapacity
    mpop r8, %2
    mov %1, rdx
    
    mov dword [%1 + rdi * 4 + 9], %2d ; добавляем в конец цифру

    inc rdi                     ; увеличиваем на один RDI -- размер числа
    mov [%1 + 1], edi           ; и изменяем размер в указателе, конец

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
    mov edi, [%1 + 1]
    lea rcx, [%1 + rdi * 4 + 5]
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
    mov [%1 + 1], edi
    mpop rdi, rcx
%endmacro

%macro reverseBigInt 1
    xor rdi, rdi
    mov edi, [%1 + 1]
    lea r8, [%1 + 9]
    lea r9, [%1 + rdi * 4 + 5]
%%process_reverse:
    cmp r8, r9
    jge %%finish
    xor r10, r10
    xor r11, r11
    mov r10d, [r8]
    mov r11d, [r9]
    mov [r9], r10d
    mov [r8], r11d
    inc r8
    dec r9
    jmp %%process_reverse
%%finish:
%endmacro

; BigInt biFromInt(int64_t number);
; number -- RDI
; возвращает RAX
; создает длинное число по короткому
biFromInt:
    createBigInt                ; создаем число с дефолтной вместимостью
    mov byte [rax], 1           ; изначально его знак равен 1
    cmp rdi, 0
    jge .non_negative           
    mov byte [rax], -1          ; число отрицательное, пишем в его знак -1
    neg rdi                     ; RDI = -RDI, теперь число можно парсить как положительное
    jmp .positive_number
.non_negative:
    cmp rdi, 0                  
    jg .positive_number         
    mov byte [rax], 0           ; число равно 0
    mov dword [rax + 1], 1      ; количество цифр -- 1
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
    mov byte [rax], 1
    xor rcx, rcx
    cmp byte [rdi], '-'
    jne .positive_number
    mov byte [rax], -1
    inc rcx
.positive_number:
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
    mov byte [rax], 0
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
    callFree rax
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
    cmp byte [rdi], 0
    jne .non_zero_number
    mov byte [rsi + rcx], '0'
    inc rcx
    jmp .add_zero
.non_zero_number:
    cmp byte [rdi], -1
    jne .positive_number
    mov byte [rsi + rcx], '-'
    inc rcx
    dec rdx
.positive_number:
    xor r8, r8
    mov r8d, [rdi + 1]
    lea r9, [rdi + r8 * 4 + 5]

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

    cmp r8d, [rdi + 1]
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

    callFree rax

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
    cmp byte [rdi], -1
    jne .write_non_negative
    mov rax, -1
.write_non_negative:
    mov al, byte [rdi]
    ret

biAdd:
    ret

biSub:
    ret

biMul:
    ret

biDivRem:
    ret

biCmp:
    ret

section .data

intFormat:    db '%d', 10, 0
stringFormat: db '%s', 10, 0
