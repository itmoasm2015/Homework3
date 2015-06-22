extern malloc
extern free

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


; Умножаем BigInt(%1) на quadword(%2) и кладем результат в (%3).
%macro  MULTIPLY 2-3
        mov     rcx, [%1 + bi.len]
        mov     r11, [%1 + bi.data]
        xor     rdx, rdx
        %%loop:
                mov     r8, rdx                
                mov     rax, [r11]
                mul     %2
                add     rax, r8
                adc     rdx, 0                 
                %if %0 == 3
                        mov     [%3], rax
                %else
                        mov     [r11], rax
                %endif
                %if %0 == 3
                        add     %3, 8
                %endif
                add     r11, 8
                sub     rcx, 8
                jnz     %%loop
        %if %0 == 3
                mov     [%3], rdx
        %endif
%endmacro

; Меняем знак данного BigInt (%1).
%macro  NEGATE 1
        push    %1
        mov     rcx, [%1 + bi.len]
        mov     %1, [%1 + bi.data]
        lahf
        or      ah, 1                          
            %%loop:                            
                mov     rdx, [%1]
                not     rdx
                sahf
                adc     rdx, 0
                lahf
                mov     [%1], rdx
                add     %1, 8
                sub     rcx, 8
                jnz     %%loop
        pop     %1
%endmacro
           

%macro  STACKANDCALL 1
        test    rsp, 0xf
        jz      %%allright
        sub     rsp, 8
        call    %1
        add     rsp, 8
        jmp     %%complete
    %%allright:
        call    %1
    %%complete:
%endmacro

section .text

;BigInt biFromInt(int64_t x);
;
; возвращает rax - адресс нового BigInt
biFromInt:
        push    rdi
        mov     rsi, 8
        mov     rdi, rsi
        push    rsi
        STACKANDCALL    malloc              
        push    rax
        mov     rdi, bi_size
        STACKANDCALL    malloc              
        pop     rdx
        pop     rsi
        mov     [rax + bi.len], rsi
        mov     [rax + bi.data], rdx
        pop     rdi
        mov     [rdx], rdi
        ret

;BigInt biFromString(char const *s);
; 
; Создает новый BigInt, по строке и ее длине
biFromString:
        push    rbx
        mov     al, byte [rdi]                  
        cmp     al, '-'
        jne     .pos
        inc     rdi
        push    0
        jmp     .neg
    .pos:
        push    1
    .neg:
        mov     al, byte [rdi]
        cmp     al, 0
        je      .fail_                          ; пустая строка
        mov     rsi, rdi
        .loop1:
                lodsb
                cmp     al, '0'
                je      .loop1
        dec     rsi
        mov     rdi, rsi
        xor     rcx, rcx
        .loop2:                                 ; считаем длину нового BigInt - считаем длину входной строки без знака и нулей
                inc     rcx                     
                lodsb
                cmp     al, 0
                jne     .loop2
        dec     rsi
        mov     rax, rcx
        mov     rcx, 18
        xor     rdx, rdx
        div     rcx                             ; умножаем результат на 8
        lea     rax, [rax * 8 + 8]              ; делим на 18
        push    rdi                             ; конец строки
        push    rsi                             
        mov     rdi, rax
        push    rdi
        STACKANDCALL    malloc
        push    rax
        mov     rdi, bi_size
        STACKANDCALL    malloc
        pop     r9
        pop     rdi
        mov     [rax + bi.len], rdi
        mov     [rax + bi.data], r9
        mov     rcx, [rax + bi.len]
        .loop3:                                 ; инициализируем нулями
                mov     qword [r9], 0
                add     r9, 8
                sub     rcx, 8
                jnz     .loop3
        pop     rsi
        pop     rdi
        mov     r9, rax                         ; создаем новый BigInt
        cmp     rdi, rsi
        je      .done                           ; ноль
        xor     rax, rax
        mov     rbx, 10
        .loop4:                                 ; умножаем на 10 и добавляем еще цифру
                MULTIPLY r9, rbx
                xor     rax, rax
                mov     al, byte [rdi]
                sub     al, '0'
                cmp     rax, 9                
                ja      .fail                 
                mov     rdx, [r9 + bi.data]
				mov     rcx, [r9 + bi.len]
				mov     r8, [rdx]
				add     r8, rax
				mov     [rdx], r8
				pushf
				add     rdx, 8
				.aloop:
                popf
                mov     r8, [rdx]
                adc     r8, 0
                mov     [rdx], r8
                pushf
                jnc     .adone
                add     rdx, 8
                sub     rcx, 8
                jnz     .aloop
				.adone:
				popf
                inc     rdi
                cmp     rsi, rdi
                jne     .loop4
    .done:
        pop     rdx
        test    rdx, 1
        jnz     .return
        NEGATE  r9
    .return:
        mov     rcx, [r9 + bi.len]
        sub     rcx, 16                         
        cmp     rcx, -8
        je      .sdone                          ; больше нечего уменьшать
        mov     rdx, [r9 + bi.data]
        .sloop:
                mov     rax, [rdx + rcx + 8]
                cmp     rax, 0
                jne     .sneg                   
                mov     rax, [rdx + rcx]
                test    rax, [MSB]
                jz      .scontinue              
                jmp     .sdone
            .sneg:
                cmp     rax, -1
                jne     .sdone                  
                mov     rax, [rdx + rcx]
                test    rax, [MSB]
                jz      .sdone                  
            .scontinue:
                sub     rcx, 8
                cmp     rcx, -8
                jne     .sloop
        .sdone:
        add     rcx, 16
        mov     [r9 + bi.len], rcx
        mov     rax, r9        
        pop     rbx
        ret
    .fail:
        push    r9
        mov     rdi, [r9 + bi.data]
        STACKANDCALL    free
        pop     rdi
        STACKANDCALL    free
    .fail_:
        mov     rax, 0
        pop     rbx                             
        pop     rbx
        ret


;void biDelete(BigInt bi);
biDelete:
        push    rdi
        mov     rdi, [rdi + bi.data]
        STACKANDCALL    free
        pop     rdi
        STACKANDCALL    free
        ret

;int biSign(BigInt bi);
;
; Возвращает -1, 0 , 1 в зависимости от знака bi.
biSign:        
        mov     rcx, [rdi + bi.len]
        mov     rdx, [rdi + bi.data]
        mov     rdx, [rdx + rcx - 8]            
        test    rdx, [MSB]                      ; если MSB установлен возвращаем 0
        jnz     .neg
        cmp     rcx, 8                          ; если 8 байт - одно число=0, то возвращаем 0
        jne     .pos                          
        cmp     rdx, 0                         
        jne     .pos
        mov     rax, 0
        ret
    .pos:
        mov     rax, 1
        ret
    .neg:
        mov     rax, -1
        ret

;void biAdd(BigInt dst, BigInt src);
;
; Складываем два BigInt
biAdd:
        push    r13                             
        push    r12                             
        push    rdi                             
        mov     rdx, [rdi + bi.len]
        cmp     rdx, [rsi + bi.len]
        jae     .done_swap
        xchg    rdi, rsi
     .done_swap:                                ; наибольшее в rdi
        mov     rcx, [rdi + bi.len]
        add     rcx, 8                          
        push    rdi
        push    rsi                             
        STACKANDCALL    malloc
        mov     r8, rax
        pop     rsi
        pop     rdi
        push    r8                             
        mov     r12, [rdi + bi.data]        
        mov     r13, [rsi + bi.data]        
        mov     rcx, [rsi + bi.len]
        clc
        lahf
        .loop1:                                 ; первый цикл - пока не закончится наименьшее
                sahf                            ; восстанавливаем флажок
                mov     r9, [r12]
                adc     r9, [r13]
                mov     [r8], r9
                lahf                            ; сохраняем флажок
                add     r8, 8
                add     r12, 8
                add     r13, 8
                sub     rcx, 8
                jnz     .loop1
        push    rax						
        mov     rax, [rsi + bi.len]
        mov     r11, [rsi + bi.data]
        mov     r11, [r11 + rax - 8]
        test    r11, [MSB]             			;последнее число
        jnz     .nneg
        mov     r10, 0
        jmp     .ddone
     .nneg:
        mov     r10, -1
     .ddone:
        pop     rax
        mov     rcx, [rdi + bi.len]
        sub     rcx, [rsi + bi.len]
        jz      .loop2_end
        .loop2:                                 ; второй цикл - пока не закончится наибольшее
                sahf
                mov     r9, [r12]
                adc     r9, r10
                mov     [r8], r9
                lahf
                add     r8, 8
                add     r12, 8
                sub     rcx, 8
                jnz     .loop2
    .loop2_end:
        push    rax						
        mov     rax, [rdi + bi.len]
        mov     r11, [rdi + bi.data]
        mov     r11, [r11 + rax - 8]
        test    r11, [MSB]             
        jnz     .nnneg
        mov     r9, 0
        jmp     .dddone
     .nnneg:
        mov     r9, -1
     .dddone:
        pop     rax
        sahf
        adc     r9, r10                         
        mov     [r8], r9
        mov     rax, [rdi + bi.len]         ; max(dst.size, src.size)
        add     rax, 8
        mov     rdi, [rsp + 8]                  
        mov     [rdi + bi.len], rax
        mov     rdi, [rdi + bi.data]
        STACKANDCALL    free
        pop     r8                              
        pop     rdi                             
        mov     [rdi + bi.data], r8
        mov     rcx, [rdi + bi.len]
        sub     rcx, 16                         
        cmp     rcx, -8
        je      .sdone                          
        mov     rdx, [rdi + bi.data]
        .sloop:
                mov     rax, [rdx + rcx + 8]
                cmp     rax, 0
                jne     .sneg                   
                mov     rax, [rdx + rcx]
                test    rax, [MSB]
                jz      .scontinue              
                jmp     .sdone
            .sneg:
                cmp     rax, -1
                jne     .sdone                  
                mov     rax, [rdx + rcx]
                test    rax, [MSB]
                jz      .sdone                  
            .scontinue:
                sub     rcx, 8
                cmp     rcx, -8
                jne     .sloop
        .sdone:
        add     rcx, 16
        mov     [rdi + bi.len], rcx
        pop     r12                            
        pop     r13
        ret

;void biSub(BigInt dst, BigInt src);
;
; Копируем src, делаем его отрицательным и складываем
biSub:
        push    rdi
        push    rsi
        mov     rcx, [rsi + bi.len]
		; new BigInt
        mov     rdi, rcx
        push    rcx
        STACKANDCALL    malloc            
        push    rax
        mov     rdi, bi_size
        STACKANDCALL    malloc             
        pop     rdx
        pop     rcx
        mov     [rax + bi.len], rcx
        mov     [rax + bi.data], rdx
        pop     rsi
        mov     r8, [rsi + bi.data]
        .llloop:
                mov     r9, [r8]
                mov     [rdx], r9
                add     r8, 8
                add     rdx, 8
                sub     rcx, 8
                jnz     .llloop
        pop     rdi
        mov     rsi, rax
        push    rsi
        NEGATE  rsi
        call    biAdd
        pop     rsi
        push    rsi
        mov     rdi, [rsi + bi.data]
        STACKANDCALL    free
        pop     rdi
        STACKANDCALL    free
        ret

;void biMul(BigInt dst, BigInt src);
; 
; Делаем dst и src не отрицательными и запоминаем знак. умножаем.
biMul:
        push    rbx
        push    r12
        push    r13
        push    rax						; делаем dst и src не отрицательными
        mov     rax, [rdi + bi.len]
        mov     r11, [rdi + bi.data]
        mov     r11, [r11 + rax - 8]
        test    r11, [MSB]             
        jnz     .nnneg
        mov     r8, 0
        jmp     .dddone
     .nnneg:
        mov     r8, -1
     .dddone:
        pop     rax
        cmp     r8, 0                  
        je      .dst_pos
        NEGATE  rdi
    .dst_pos:
        push    rax
        mov     rax, [rsi + bi.len]
        mov     r11, [rsi + bi.data]
        mov     r11, [r11 + rax - 8]
        test    r11, [MSB]             
        jnz     .nneg
        mov     r9, 0
        jmp     .ddone
     .nneg:
        mov     r9, -1
     .ddone:
        pop     rax
        push    r9                     
        cmp     r9, 0
        je     .src_pos
        NEGATE rsi
    .src_pos:
        xor     r8, r9                          ; знак результата
        push    r8                              
        push    rdi                             ; выделяем память dst.size + src.size + 8
        push    rsi
        mov     rdi, [rdi + bi.len]
        add     rdi, [rsi + bi.len]
        add     rdi, 8
        push    rdi
        STACKANDCALL    malloc
        push    rax
        mov     rdi, [rsp + 24]
        mov     rdi, [rdi + bi.len]         
        add     rdi, 8
        STACKANDCALL    malloc
        mov     r10, rax                        ; массиы tmp
        pop     rbx                             ; новый BigInt
        pop     r13                             ; размер нового BigInt
        pop     rsi                             ; src
        pop     rdi                             ; dst
        push    r13                             ; заполняем результат нулями
        sub     r13, 8
        xor     r9, r9
        .zero_loop:
                mov     [rbx + r13], r9
                sub     r13, 8
                jnz     .zero_loop
        mov     [rbx + r13], r9
        pop     r13
        xor     r12, r12                        ; счетчик
        mov     r9, [rsi + bi.data]
        .loop:
                push    rbx
                mov     rbx, [r9 + r12]
                push    r10
                MULTIPLY rdi, rbx, r10
                pop     r10
                lahf
                and     rax, -2                 
                mov     rbx, [rsp]
                push    r10
                mov     r11, [rdi + bi.len]
                lea     r11, [r10 + r11 + 8]    ; конец tmp
                .loop2:
                        mov     r8, [r10]
                        sahf
                        adc     r8, [rbx + r12] 
                        lahf
                        mov     [rbx + r12], r8
                        add     rbx, 8
                        add     r10, 8
                        cmp     r10, r11
                        jne     .loop2
                pop     r10
                pop     rbx
                add     r12, 8
                cmp     r12, [rsi + bi.len]
                jne     .loop
        mov     [rdi + bi.len], r13         ; выставляем dst новый размер
        push    rbx
        push    rsi
        push    rdi
        mov     rdi, r10
        STACKANDCALL    free                            ; чистим tmp
        mov     rdi, [rsp]                      ; создаем новый массив вместо dst
        mov     rdi, [rdi + bi.data]
        STACKANDCALL    free
        pop     rdi
        pop     rsi
        pop     rbx
        mov     [rdi + bi.data], rbx
        ; восстанавливаем знаки
        pop     rax                             
        cmp     rax, 0
        je      .src_pos_
        NEGATE  rdi
    .src_pos_:
        pop     rax                             
        cmp     rax, 0
        je      .result_pos
        NEGATE  rsi
    .result_pos:
        mov     rcx, [rdi + bi.len]
        sub     rcx, 16                         
        cmp     rcx, -8
        je      .sdone                          
        mov     rdx, [rdi + bi.data]
        .sloop:
                mov     rax, [rdx + rcx + 8]
                cmp     rax, 0
                jne     .sneg                   
                mov     rax, [rdx + rcx]
                test    rax, [MSB]
                jz      .scontinue              
                jmp     .sdone
            .sneg:
                cmp     rax, -1
                jne     .sdone                  
                mov     rax, [rdx + rcx]
                test    rax, [MSB]
                jz      .sdone                  
            .scontinue:
                sub     rcx, 8
                cmp     rcx, -8
                jne     .sloop
        .sdone:
        add     rcx, 16
        mov     [rdi + bi.len], rcx
        pop     r13
        pop     r12
        pop     rbx
        ret

;void biDivRem(BigInt *quotient, BigInt *remainder, BigInt numerator, BigInt denominator);
biDivRem:
        ret
        
;void biToString(BigInt bi, char *buffer, size_t limit);
; 
; Делим копию bi на 10, пока не получим ноль,
; добавляем остаток от деления в буфер на каждой итерации.
biToString:
        push    r13
        push    r12
        push    rbx                             
        push    rsi                            
        push    rdx                             
        push    rdi
        mov     rcx, [rdi + bi.len]
		; new BigInt
        mov     rdi, rcx
        push    rcx
        STACKANDCALL    malloc              ; data - выделяем память
        push    rax
        mov     rdi, bi_size
        STACKANDCALL    malloc              ; headers - выделяем память
        pop     rdx
        pop     rcx
        mov     [rax + bi.len], rcx
        mov     [rax + bi.data], rdx
        pop     rdi
        mov     r8, [rdi + bi.data]
        .lloop:
                mov     r9, [r8]
                mov     [rdx], r9
                add     r8, 8
                add     rdx, 8
                sub     rcx, 8
                jnz     .lloop
        mov     rdi, rax
        mov     rax, [rdi + bi.len]         ; выделяем память для tmp
        shr     rax, 3                         
        mov     rdx, 19                         
        mul     rdx
        inc     rax
        push    rdi                             
        mov     rdi, rax
        STACKANDCALL    malloc
        mov     rbx, rax                        ; tmp
        xor     r13, r13                        ; счетчик записанных чаров
        pop     rdi
        pop     r8                             
        pop     rsi                            
        push    rax								; проверяем если отрицательный
        mov     rax, [rdi + bi.len]
        mov     r11, [rdi + bi.data]
        mov     r11, [r11 + rax - 8]
        test    r11, [MSB]             			; последнее число
        jnz     .nneg
        mov     r12, 0
        jmp     .ddone
     .nneg:
        mov     r12, -1
     .ddone:
        pop     rax
        cmp     r12, 0
        je      .pos
        push    1
        NEGATE  rdi
        jmp     .neg
    .pos:
        push    0                           
    .neg:
        mov     r11, 10
        .loop:
                mov     r9, [rdi + bi.data]
                mov     r10, [rdi + bi.len]
                xor     rdx, rdx
                xor     rcx, rcx               
                .div_loop:                      ; когда rcx будет 0 - BigInt тоже 0
                        mov     rax, [r9 + r10 - 8] 
                        div     r11
                        mov     [r9 + r10 - 8], rax
                        or      rcx, rax
                        sub     r10, 8
                        jnz     .div_loop
                add     rdx, '0'
                mov     byte [rbx + r13], dl
                inc     r13
                or      rcx, rcx
                jnz     .loop
        pop     r9
        cmp     r9, 0
        je      .pos_
        mov     al, '-'
        mov     byte [rsi], al
        inc     rsi
        dec     r8
    .pos_;
        dec     r8                              ; место для байта '\0'
        .move_loop:
                mov     al, byte [rbx + r13 - 1]
                mov     byte [rsi], al
                inc     rsi
                dec     r13
                jz      .done
                dec     r8
                jnz     .move_loop

    .done:
        xor     rax, rax
        mov     byte [rsi], al                  ; конец строки
        push    rbx       
        push    rdi
        mov     rdi, [rdi + bi.data]
        STACKANDCALL    free
        pop     rdi
        STACKANDCALL    free
        pop     rdi
        STACKANDCALL    free                            ; освобождаем tmp
        pop     rbx
        pop     r12
        pop     r13
        ret

;int biCmp(BigInt a, BigInt b);
;
; Возвращаем -1, 0, 1 в зависимости от a <>= b
biCmp:
        push    rsi
        push    rdi
        mov     rcx, [rdi + bi.len]
		; new BigInt
        mov     rdi, rcx
        push    rcx
        STACKANDCALL    malloc              ; data - выделяем память
        push    rax
        mov     rdi, bi_size
        STACKANDCALL    malloc              ; headers - выделяем память
        pop     rdx
        pop     rcx
        mov     [rax + bi.len], rcx
        mov     [rax + bi.data], rdx
        pop     rdi
        mov     r8, [rdi + bi.data]
        .lloop:
                mov     r9, [r8]
                mov     [rdx], r9
                add     r8, 8
                add     rdx, 8
                sub     rcx, 8
                jnz     .lloop
        mov     rdi, rax
        pop     rsi
        push    rdi
        call    biSub
        mov     rdi, [rsp]
        call    biSign
        pop     rdi
        push    rax
        push    rdi
        mov     rdi, [rdi + bi.data]
        STACKANDCALL    free
        pop     rdi
        STACKANDCALL    free
        pop     rax
        ret

struc   bi
        .len    resb    8           ; размер в байтах
        .data   resb    8           ; big-endian
endstruc

section .rodata
        align   8
    MSB:
        dq      0x8000000000000000   
