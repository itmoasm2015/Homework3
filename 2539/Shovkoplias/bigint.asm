section .text

extern malloc
extern calloc
extern free

global biFromInt
global biFromString
global biToString
global biDelete
global biSign
global biAdd
global biSub
global biMul
global biDivRem ;TODO but not today:)
global biCmp
global biCopy
global biFromArray


;BigInt я буду хранить так: 4 байта (int) на знак (-1,0,1), столько же на длину, котора хотя бы 1.
;Как основание буду использовать 2^64, будет массив "цифр" этой системы, на каждую по 8 байт.
;Код на плюсах:
;struct BigInt {
;   int sign, size;
;   int64_t *digits;
;};

; Вызывает malloc с предварительным выравниванием стека на 16 байт
%macro alignedMalloc 0
    push    r12
    mov     r12, rsp
    and     rsp, ~15	; rsp & ~15 зануляет младшие 4 бита, то есть после этого rsp делится на 16
    call    malloc
    mov     rsp, r12
    pop     r12
%endmacro

; Вызывает malloc с предварительным выравниванием стека на 16 байт
%macro alignedCalloc 0
    push    r12
    mov     r12, rsp
    and     rsp, ~15	; Аналогично alignedMalloc
    call    calloc
    mov     rsp, r12
    pop     r12
%endmacro


; Вызывает free с предварительным выравниваем стека на 16 байт
%macro alignedFree 0
    push    r12
    mov     r12, rsp
    and     rsp, ~15	; Аналогично alignedMalloc
    call    free
    mov     rsp, r12
    pop     r12
%endmacro


;Создает BigInt из 64-битового знакового целого числа.
;BigInt biFromInt(int64_t x);
;rdi - x
;результат будет в rax
biFromInt:
    push    rcx
    push    rdi
    mov     rdi, 8 ;Выделим память под массив цифр. Очевидно, что цифра всего одна.
    alignedMalloc
    mov     rcx, rax ;rcx хранит указатель на массив, rax понадобится для выделенися памяти под саму структуру
    mov     rdi, 16 ;4 + 4 + 8 --- 4 байта на знак, 4 на размер и 8 на указатель на массив цифр
    push    rcx ; Ничего не работало, потому что маллок портил мне rcx :(
    alignedMalloc
    pop     rcx
    pop     rdi ; Теперь тут снова x
    ;Нужно теперь заполнить поля
    mov     dword[rax], 1 ;По умолчанию знак +
    mov     dword[rax + 4], 1 ;size = 1
    mov     [rax + 8], rcx ;Указатель на массив теперь действительно на него указывает
    cmp     rdi, 0
    je      .ifZero
        ;Знак либо + либо - если мы тут
        jnl     .finish ; x > 0
            mov     dword[rax], -1 ;Знак -
            neg     rdi ;цифры всегда положительные
            jmp     .finish
    .ifZero
        mov     dword[rax], 0 ;sign(0) = 0
    .finish
    mov     [rcx], rdi ;Положим цифру в массив
    pop     rcx
    ret

;Удаление BigInt.
;void biDelete(BigInt bi);
;rdi - bi
biDelete:
    push    rdi
    mov     rdi, [rdi + 8] ;Сначала удалим цифры
    alignedFree
    pop     rdi ;Теперь саму структуру
    alignedFree
    ret

;Возвращает знак данного BigInt.
;0 если bi = 0, 1 если bi > 0 и -1 если bi < 0
;int biSign(BigInt bi)
;rdi - bi
;результат в eax ибо 4 байта
biSign:
    xor     rax, rax ;Зануляем регистр, чтобы какой-нибудь гадости не вылезло сверху
    mov     eax, dword[rdi]
    ret

;Копирует BigInt
;Возвращает новый BigInt равный старому
;BigInt biCopy(BigInt bi)
;rdi - bi
;результат в rax
biCopy:
    push    rcx
    push    rbx
    mov     rcx, rdi ;rdi нам еще понадобится
    mov     rbx, [rcx + 8] ;Положим сюда указатель на массив цифр
    push    rdi
    xor     rdi, rdi
    mov     edi, dword[rcx + 4] ;Положим сюда сколько цифр в числе
    imul    rdi, 8 ;по 8 байт на цифру
    push    rbx
    alignedMalloc ;Выделим память под массив цифр.
    pop     rbx
    pop     rdi ; Теперь тут снова указатель на первоначальное число
    xor     rcx, rcx
    mov     ecx, dword[rdi + 4] ;количество цифр для счетчика
    push    r8 ;Использую как счетчик
    xor     r8, r8
    .loop: ;Скопируем все цифры
        push    r9
        mov     r9, qword[rbx + r8 * 8] ;Начало цифры под номером r8
        mov     [rax + r8 * 8], r9
        pop     r9
        inc     r8
        cmp     r8, rcx
        jl      .loop
    pop     r8
    push    rdi ;rdi нам еще понадобится
    mov     rcx, rax ;rcx хранит указатель на массив, rax понадобится для выделенися памяти под саму структуру
    mov     rdi, 16 ;4 + 4 + 8 - 4 байта на знак, 4 на размер и 8 на указатель на массив цифр
    push    rcx
    alignedMalloc
    pop     rcx
    pop     rdi ; Теперь тут снова указатель на первоначальное число
    ;Нужно теперь заполнить поля
    mov     ebx, dword[rdi]
    mov     dword[rax], ebx; Знак
    mov     ebx, dword[rdi + 4]
    mov     dword[rax + 4], ebx ; Размер
    mov     [rax + 8], rcx ;Указатель на массив теперь действительно на него указывает
    pop     rbx
    pop     rcx
    ret


;Вспомогательная функция
;Создает BigInt по значениям знака, длины массива цифр и массива цифр.
;BigInt biFromArray(int sign, int len, int64_t *a);
;edi - sign
;esi - len
;rdx - *a
;результат в rax
biFromArray:
    push    rdi
    push    rsi
    push    rdx
    mov     rdi, 16 ;4 + 4 + 8 - 4 байта на знак, 4 на размер и 8 на указатель на массив цифр
    alignedMalloc
    pop     rdx
    pop     rsi
    pop     rdi
    mov     dword[rax], edi ; Знак
    mov     dword[rax + 4], esi ; размер
    mov     [rax + 8], rdx ; указатель на массив цифр
    ret

;Вспомогательная функция
;Увеличивает массив цифр на короткое число
;Требует, чтобы размер массива позвалял хранить результат
;void addArrayOnShort(int64_t *a, int len, int64_t x);
; rdi - *a
; esi - len
; rdx - x
addArrayOnShort:
    push    rax
    push    r8
    mov     r8, 0 ;Cчетчик
    .loop:
        cmp     r8D, esi
        je      .return
        mov     rax, qword[rdi + r8 * 8]
        mov     qword[rdi + r8 * 8], rdx
        add     qword[rdi + r8 * 8], rax
        mov     rdx, 0
        adc     rdx, 0 ;rdx сначала то, что надо прибавить,а потом тащится как остаток
        inc     r8
        jmp     .loop
    .return:
    pop     r8
    pop     rax
    ret

;Вспомогательная функция
;Умножает массив цифр на короткое число
;Требует, чтобы размер массива позвалял хранить результат
;void mulArrayOnShort(int64_t *a, int len, int64_t x);
; rdi - *a
; esi - len
; rdx - x
mulArrayOnShort:
    push    rax
    push    rcx
    mov     rcx, rdx ;rdx нам понадобится для остатка
    push    r8
    mov     r8, 0 ;Cчетчик
    mov     rdx, 0
    .loop:
        cmp     r8D, esi
        je      .return
        mov     rax, qword[rdi + r8 * 8]
        mov     qword[rdi + r8 * 8], rdx
        mul     rcx
        add     qword[rdi + r8 * 8], rax
        adc     rdx, 0
        inc     r8
        jmp     .loop
    .return:
    pop     r8
    pop     rcx
    pop     rax
    ret


;Вспомогательная функция
;Делит массив цифр на короткое число
;void divArrayOnShort(int64_t *a, int len, int64_t x);
; rdi - *a
; esi - len
; rdx - x
; Остаток будет в rdx
divArrayOnShort:
    push    rax
    push    rcx
    mov     rcx, rdx ;rdx нам понадобится для остатка
    push    r8
    mov     r8D, esi ;Cчетчик
    mov     rdx, 0
    .loop:
        dec     r8
        cmp     r8, 0
        jl      .return
        mov     rax, qword[rdi + r8 * 8]
        div     rcx
        mov     qword[rdi + r8 * 8], rax
        jmp     .loop
    .return:
    pop     r8
    pop     rcx
    pop     rax
    ret


;Создает BigInt из строки с десятичным представлением.
;Вернет NULL если строка некорректна.
;BigInt biFromString(char const *s)
;rdi - s
;результат в rax
biFromString:
    ;Сначала проверим строку на корректность и узнаем полезные данные
    push    r8
    push    r9
    push    r10
    push    r11
    mov     r11, 0 ;Cчетчик цифр
    mov     r10, 0 ;Cчетчик ненулевых цифр. определим отлично число от нуля или нет.
    mov     r9, 1 ;сюда сохраним знак
    mov     r8, rdi
    cmp     byte[r8], '-'
    jne     .loop
    mov     r9, -1 ;если мы тут, то число отрицательно
    inc     r8 ;сдвинем указатель на строку
    inc     rdi

    .loop:
        cmp     byte[r8], 0
        je      .end_loop
        inc     r11
        cmp     byte[r8], '0'
        jl      .fail
        cmp     byte[r8], '9'
        jg      .fail
        cmp     byte[r8], '0'
        je      .continue
        inc     r10 ; r8 >= 0 && r8 <= 9 && r8 != 0 => очевидно что это ненулевая цифра
        .continue:
        inc     r8
        jmp     .loop

    .end_loop:

    ;Если мы тут, то строка корректна и мы знаем знак, размер и количество ненулувых цифр

    cmp     r10, 0
    jne     .not_zero
    ;Если мы тут, то все цифры нули, так как нет ненулевых ибо r10 = 0
        cmp     r11, 0 ;Вдруг нам дали пустую строку
        je      .fail
        ;Если это ноль, то можно вызвать конструктор от одного числа, чтобы посчитать ответ
        mov     rdi, 0
        call    biFromInt
        jmp     .return
    .not_zero:

    push    r9
    push    r11 ; Сохраним знак и длину, чтобы ничего не испортилось

    push    rdi
    mov     rdi, r11
    shr     rdi, 4
    inc     rdi ;Если число содержит n цифр, то для его представления понадобится (n/16+1) 64-битное число
    mov     rcx, rdi
    push    rcx
    push    rsi
    mov     rsi, 8
    alignedCalloc ;rax - массив цифр
    pop     rsi
    pop     rcx ;количество цифр
    pop     rdi

    mov     r8, rdi
    .loop2:
        cmp     byte[r8], 0
        je      .end_loop2

        push    r8
        push    rcx
        push    rax
        mov     rdi, rax
        mov     rsi, rcx
        mov     rdx, 10
        call    mulArrayOnShort
        pop     rax
        pop     rcx
        pop     r8

        push    r8
        push    rcx
        push    rax
        mov     rdi, rax
        mov     rsi, rcx
        mov     rdx, 0
        mov     dl, byte[r8]
        sub     dl, '0'
        call    addArrayOnShort
        pop     rax
        pop     rcx
        pop     r8

        inc     r8
        jmp     .loop2

    .end_loop2:

    pop     r11
    pop     r9

    ;Осталось удалить лидирующие нули

    .loop3:
        mov     rdi, [rax + rcx * 8 - 8]
        cmp     rdi, 0
        jne     .break
        dec     rcx
        cmp     rcx, 1
        jg      .loop3
    .break:

    ;Теперь можно просто вызвать вспомогательный конструктор
    mov     rdi, r9
    mov     rsi, rcx
    mov     rdx, rax
    call    biFromArray
    jmp     .return

    .fail:
    mov     rax, 0
    .return:
    pop     r11
    pop     r10
    pop     r9
    pop     r8
    ret


;Вспомогательная функция
;Проверяет есть ли в массиве ненулевой символ
;Возвращает количество ненулевых символов в массиве
;int arrayZeroCheck(int64_t *a, int len);
;rdi - a
;rsi - len
;результат в rax
arrayZeroCheck:
    xor     rax, rax
    .loop:
        dec     rsi
        cmp     qword[rdi + rsi * 8], 0
        je      .continue
        inc     rax
        .continue:
        cmp     rsi, 0
        jg      .loop
    ret


;Генерирует десятичную строку из BigInt.
;пишет не больше limit байтов в buffer.
;void biToString(BigInt bi, char *buffer, size_t limit);
;rdi - bi
;rsi - buffer
;rdx - limit
biToString:
    cmp     rdx, 1
    jg      .continue
        mov     [rsi], byte 0 ;Костыль на случай если limit <= 1
        ret
    .continue

    cmp     dword[rdi], 0
    jne     .not_zero
        ;Если число ноль, то сразу дадим ответ
        mov     byte[rsi], '0'
        mov     byte[rsi + 1], 0
        ret
    .not_zero:

    push    rdx
    push    rsi
    push    rdi

    xor     r8, r8
    mov     r8D, [rdi + 4]
    mov     rdi, r8
    imul    rdi, 21 ;Примерное вычисление длины строки n цифр займут около 21n char-ов
    alignedMalloc ;rax - указатель на выделенную для строки память
    pop     rdi ;в rdi снова указатель на число
    push    rdi
    push    rax
    call    biCopy ;Сделаем копию числа, чтобы можно было погадить там массив цифр
    mov     r8, rax ;В r8 теперь хранится копия
    pop     rax ; rax cнова указатель на выделенную для строки память
    pop     rdi
    pop     rsi
    pop     rdx
    mov     r9, [r8 + 8] ;r9 теперь указатель на копию массива цифр

    ;Пропишем "-" если число отрицательно
    cmp     dword[rdi], -1
    jne     .continue2
        mov     byte[rsi], '-'
        inc     rsi ;сдвинем указатель на буффер
        dec     rdx ;уменьшим лимит
    .continue2:

    xor     r10, r10 ;счетчик
    .loop:
        push    rax
        push    r8
        push    r9
        push    rdi
        push    rsi
        push    rdx
        xor     rsi, rsi
        mov     esi, [r8 + 4]
        mov     rdi, r9
        call    arrayZeroCheck
        pop     rdx
        pop     rsi
        pop     rdi
        pop     r9
        pop     r8
        cmp     rax, 0
        pop     rax
        je      .break ;Если число ноль, то цикл нужно прекратить

        push    rax
        push    r8
        push    r9
        push    rdi
        push    rsi
        push    rdx
        xor     rsi, rsi
        mov     esi, [r8 + 4]
        mov     rdi, r9
        mov     rdx, 10
        call    divArrayOnShort
        mov     r11, rdx ;сохраним остаток
        pop     rdx
        pop     rsi
        pop     rdi
        pop     r9
        pop     r8
        pop     rax

        push    rdx
        mov     rdx, r11
        add     dl, '0'
        mov     byte[rax + r10], dl ;Запишем остаток в строку
        pop     rdx

        inc     r10
        jmp     .loop
    .break:

    ;Теперь запишем limit символов из rax в buffer
    .loop2:
        cmp     rdx, 1
        je      .break2 ;Осталось место только для терминального символа

        dec     r10
        push    rdx
        mov     dl, [rax + r10]
        mov     byte[rsi], dl ;Запишем символ в буффер
        inc     rsi
        pop     rdx
        dec     rdx
        cmp     r10, 0
        je      .break2
        jmp     .loop2
    .break2:

    mov     [rsi], byte 0;Запишем терминальный символ

    ;Осталось удалить временные объекты
    push    r8
    mov     rdi, rax
    alignedFree ;Удалим строку
    pop     r8
    mov     rdi, r8
    call    biDelete ;Удалим копию числа
    ret

;Вспомогательная функция
;Записывает значение второго аргумента в первый, после чего очищает память от второго
;void biSubstitution(BigInt a, BigInt b)
;rdi - a
;rsi - b
biSubstitution:
    ;Запишем знак
    mov r8D, [rsi]
    mov [rdi], r8D
    ;Аналогично длину
    mov r8D, [rsi + 4]
    mov [rdi + 4], r8D
    ;Остались цифры
    push    rdi
    push    rsi
    mov     rdi, [rdi + 8]
    alignedFree ;Очистим старый массив
    pop     rsi
    pop     rdi
    mov     r8, [rsi + 8]
    mov     [rdi + 8], r8 ;Записали новый массив
    mov     rdi, rsi
    alignedFree  ;Удалили остатки второго
    ret

;Вспомогательная функция
;Сравнивает два массива
;int cmpArray(int64_t *a, int len_a, int64_t *b, int len_b)
;rdi - a
;rsi - len_a
;rdx - b
;rcx - len_b
;результат в rax
cmpArray:
    cmp     rsi, rcx ; Cравним длины
    je      .continue
    jl      .less
        mov     rax, 1
        ret
    .less:
        mov     rax, -1
        ret
    .continue:
    mov     r8, rsi
    .loop:
        dec     r8
        mov     r9, [rdi + r8 * 8]
        mov     r10, [rdx + r8 * 8]
        cmp     r9, r10
        je      .equals
        jl      .less2
            mov     rax, 1
            ret
        .less2:
            mov     rax, -1
            ret
        .equals:
        cmp r8, 0
        jne     .loop
    mov rax, 0
    ret

;Вспомогательная функция
;Складывает два массива
;int64_t* addArray(int64_t *a, int len_a, int64_t *b, int len_b);
;rdi - a
;rsi - len_a
;rdx - b
;rcx - len_b
;результат в rax
;длина результата в r8
addArray:
    cmp rsi, rcx
    jnl .continue ;Если первое число меньше второго swapнем их
        xchg    rdi, rdx
        xchg    rsi, rcx
    .continue:

    push    rdi
    push    rsi
    push    rdx
    push    rcx
    lea     rdi, [rsi + 1]
    imul    rdi, 8
    alignedMalloc ; Выделим память под массив с размером на единицу больше чем длина большего числа
    ;указатель на этот массив rax
    pop     rcx
    pop     rdx
    pop     rsi
    pop     rdi

    xor     r8, r8
    xor     r11, r11 ; остаток
    .loop:
        cmp     r8, rsi
        jg      .loop_end
        mov     qword[rax + r8 * 8], 0

        ;Получим первую цифру
        mov     r9, 0
        cmp     r8, rsi
        jnl     .digit_existA
        mov     r9, [rdi + r8 * 8]
        .digit_existA:

        ;Вторую
        mov     r10, 0
        cmp     r8, rcx
        jnl     .digit_existB
        mov     r10, [rdx + r8 * 8]
        .digit_existB:

        ;Запишем в ответ
        ; c[i] = a[i] + b[i] + carry
        add     [rax + r8 * 8], r11
        pushf            ;
        xor     r11, r11 ; Магия с флагами
        popf             ;
        adc     r11, 0
        add     [rax + r8 * 8], r9
        adc     r11, 0
        add     [rax + r8 * 8], r10
        adc     r11, 0
        inc     r8
        jmp     .loop
    .loop_end:

    ; Осталось удалить лидирующие нули
    lea     r8, [rsi + 1]
    .loop2
        cmp     r8, 1
        je      .break
        cmp     qword[rax + r8 * 8 - 8], 0
        jne     .break
        dec     r8
        jmp     .loop2
    .break:
    ret

;Вспомогательная функция
;Вычитает два массива
;int64_t* subArray(int64_t *a, int len_a, int64_t *b, int len_b);
;rdi - a
;rsi - len_a
;rdx - b
;rcx - len_b
;результат в rax
;длина результата в r8
;знак в r11
subArray:
    call    cmpArray
    mov     r11, 1
    cmp     rax, 0
    jne     .not_equals
    ;Если равны, то ответ ясен
        mov     rdi, 8
        alignedMalloc
        mov     qword[rax], 0
        mov     r8, 1
        mov     r11, 0
        ret
    .not_equals:

    jg .continue ;Если первое число меньше второго swapнем их
        xchg    rdi, rdx
        xchg    rsi, rcx
        mov     r11, -1
    .continue:

    push    rdi
    push    rsi
    push    rdx
    push    rcx
    push    r11
    mov     rdi, rsi
    imul    rdi, 8
    alignedMalloc ; Выделим память под массив с размером на единицу больше чем длина большего числа
    ;указатель на этот массив rax
    pop     r11
    pop     rcx
    pop     rdx
    pop     rsi
    pop     rdi

    push    r11
    xor     r8, r8
    xor     r11, r11 ; остаток
    .loop:
        cmp     r8, rsi
        jge     .loop_end
        mov     qword[rax + r8 * 8], 0

        ;Получим первую цифру
        mov     r9, 0
        cmp     r8, rsi
        jnl     .digit_existA
        mov     r9, [rdi + r8 * 8]
        .digit_existA:

        ;Вторую
        mov     r10, 0
        cmp     r8, rcx
        jnl     .digit_existB
        mov     r10, [rdx + r8 * 8]
        .digit_existB:

        ;Запишем в ответ
        ; c[i] = a[i] - b[i] - carry
        mov     [rax + r8 * 8], r9
        sub     [rax + r8 * 8], r11
        pushf            ;
        xor     r11, r11 ; Магия с флагами
        popf             ;
        adc     r11, 0
        sub     [rax + r8 * 8], r10
        adc     r11, 0
        inc     r8
        jmp     .loop
    .loop_end:
    pop     r11

    ; Осталось удалить лидирующие нули
    mov     r8, rsi
    .loop2
        cmp     r8, 1
        je      .break
        cmp     qword[rax + r8 * 8 - 8], 0
        jne     .break
        dec     r8
        jmp     .loop2
    .break:
    ret

;Вспомогательная функия
;Возвращает новое большое число являющееся суммой аргументов
;BigInt biAddNew(BigInt a, BigInt b)
;rdi - a
;rsi - b
;результат в rax
biAddNew:
    ;проверим оба слагаемых на равенство нулю, ибо тогда ответ очевиден
    cmp     dword[rdi], 0
    jne     .a_not_zero
        mov     rdi, rsi
        call    biCopy
        ret
    .a_not_zero:

    cmp     dword[rsi], 0
    jne     .b_not_zero
        call    biCopy
        ret
    .b_not_zero:

    ;Теперь сравним знаки
    mov     r8D, [rdi]
    mov     r9D, [rsi]
    cmp     r8D, r9D
    jne     .not_equals
        ;Если знаки равны, просто сложим
        push    rdi
        push    rsi

        xor     rcx, rcx
        mov     ecx, [rsi + 4]
        mov     rdx, [rsi + 8]

        xor     rsi, rsi
        mov     esi, [rdi + 4]
        mov     rdi, [rdi + 8]

        call    addArray
        pop     rsi
        pop     rdi

        ;С помощью вспомогательного конструктора получим ответ
        mov     edi, [rdi]
        mov     rsi, r8
        mov     rdx, rax
        call    biFromArray
        ret
    .not_equals:
        push    rdi
        push    rsi

        xor     rcx, rcx
        mov     ecx, [rsi + 4]
        mov     rdx, [rsi + 8]

        xor     rsi, rsi
        mov     esi, [rdi + 4]
        mov     rdi, [rdi + 8]

        call    subArray
        pop     rsi
        pop     rdi

        ;С помощью вспомогательного конструктора получим ответ
        mov     edi, [rdi]
        imul    edi, r11D
        mov     rsi, r8
        mov     rdx, rax
        call    biFromArray
        ret

;Прибавляет к первому числу второе
;void biAdd(BigInt a, BigInt b)
;rdi - a
;rsi - b
biAdd:
    push    rdi
    call    biAddNew
    pop     rdi
    mov     rsi, rax
    call    biSubstitution
    ret

;Вспомогательная функия
;Возвращает новое большое число являющееся разностью аргументов
;BigInt biSubNew(BigInt a, BigInt b)
;rdi - a
;rsi - b
;результат в rax
biSubNew:
    ;изменим знак второго числа, а потом сложим
    xor     r8, r8
    cmp     rdi, rsi
    ;костыль на случай запроса разности одного и того же числа
    jne     .not_same
        mov     r8, 1
        push    r8
        push    rdi
        push    rsi
        call    biCopy
        pop     rsi
        pop     rdi
        pop     r8
        mov     rdi, rax
    .not_same:

    push    rdi
    push    rsi
    push    r8
    mov     r8D, [rsi]
    imul    r8D, -1 ; изменяем знак второго числа на противоположный
    mov     [rsi], r8D
    push    rsi
    push    r8

    call    biAddNew ;прибавляем к первому числу минус второе

    pop     r8
    pop     rsi
    imul    r8D, -1 ; меняем знак обратно
    mov     [rsi], r8D
    pop     r8
    pop     rsi
    pop     rdi

    push    rax
    cmp     r8, 1 ;если мы создали копию удалим ее
    jne     .not_same_
        call biDelete ; we need to delete it
    .not_same_:
    pop rax
    ret

;Вычитает из первого числа второе
;void biSub(BigInt a, BigInt b)
;rdi - a
;rsi - b
biSub:
    push    rdi
    call    biSubNew
    pop     rdi
    mov     rsi, rax
    call    biSubstitution
    ret

;Сравнивает два числа
; int biCmp(BigInt a, BigInt b);
;rdi - a
;rsi - b
;результат in eax
biCmp:
    ;Сделаем Чит: вернем biSign(biSubNew(a, b))
    call    biSubNew
    mov     rdi, rax
    push    rdi
    call    biSign
    pop     rdi
    push    rax
    call    biDelete
    pop     rax
    ret

;Вспомогательная функция
;Умножает два массива
;int64_t* mulArray(int64_t *a, int len_a, int64_t *b, int len_b);
;rdi - a
;rsi - len_a
;rdx - b
;rcx - len_b
;результат в rax
;длина результата в r8
mulArray:
    cmp rsi, rcx
    jnl .continue ;Если первое число меньше второго swapнем их
        xchg    rdi, rdx
        xchg    rsi, rcx
    .continue:
    push    rbx
    mov     rbx, rdx

    push    rdi
    push    rsi
    push    rbx
    push    rcx
    mov     rdi, rsi
    add     rdi, rcx
    mov     rsi, 8
    alignedCalloc ; Выделим память под массив с размером на единицу больше чем длина большего числа
    ;указатель на этот массив rax
    pop     rcx
    pop     rbx
    pop     rsi
    pop     rdi

    push    r12

    xor     r8, r8
    ;xor     r11, r11 ; остаток
    .loopA:
        cmp     r8, rsi
        jge     .loopA_end

        xor     r9, r9
        xor     rdx, rdx
        .loopB:
            mov     r10, rsi
            add     r10, rcx
            sub     r10, r8 ; r10 = len_a + len_b - r8
            cmp     r9, r10 ; r8 + r9 < len_a + len_b
            jge     .loopB_end

            mov     r10, r8
            add     r10, r9
            add     [rax + r10 * 8], rdx
            pushf

            xor     r11, r11
            push    rax
            mov     rax, [rdi + r8 * 8] ;Получим первую цифру
            ;Вторую
            mov     r12, 0
            cmp     r9, rcx
            jnl     .digit_existB
            mov     r12, [rbx + r9 * 8]
            .digit_existB:
            mul     r12
            mov     r12, rax
            pop     rax

            ;Запишем в ответ
            add     [rax + r10 * 8], r12
            adc     rdx, 0
            popf
            adc     rdx, 0

            inc     r9
            jmp     .loopB
        .loopB_end:

        inc     r8
        jmp     .loopA
    .loopA_end:

    pop     r12

    ; Осталось удалить лидирующие нули
    lea     r8, [rsi + rcx]
    .loop2
        cmp     r8, 1
        je      .break
        cmp     qword[rax + r8 * 8 - 8], 0
        jne     .break
        dec     r8
        jmp     .loop2
    .break:
    pop     rbx
    ret

;Вспомогательная функия
;Возвращает новое большое число являющееся произведением аргументов
;BigInt biMulNew(BigInt a, BigInt b)
;rdi - a
;rsi - b
;результат в rax
biMulNew:
    ;проверим оба слагаемых на равенство нулю, ибо тогда ответ очевиден
    cmp     dword[rdi], 0
    jne     .a_not_zero
        mov     rdi, 0
        call    biFromInt
        ret
    .a_not_zero:

    cmp     dword[rsi], 0
    jne     .b_not_zero
        mov     rdi, 0
        call    biFromInt
        ret
    .b_not_zero:

    ;Вычислим знак
    xor     r8, r8
    xor     r9, r9
    mov     r8D, [rdi]
    mov     r9D, [rsi]
    imul    r8, r9
    push    r8

    push    rdi
    push    rsi

    xor     rcx, rcx
    mov     ecx, [rsi + 4]
    mov     rdx, [rsi + 8]

    xor     rsi, rsi
    mov     esi, [rdi + 4]
    mov     rdi, [rdi + 8]

    call    mulArray

    pop     rsi
    pop     rdi

    ;С помощью вспомогательного конструктора получим ответ
    mov     rsi, r8
    pop     r8
    mov     rdi, r8
    mov     rdx, rax
    call    biFromArray
    ret

;Умножает число на второе
;void biAdd(BigInt a, BigInt b)
;rdi - a
;rsi - b
biMul:
    push    rdi
    call    biMulNew
    pop     rdi
    mov     rsi, rax
    call    biSubstitution
    ret
    ret

biDivRem:
    ret
