default rel

section .text

extern malloc_align
extern free_align

extern newVector
extern pushBack
extern popBack
extern back
extern deleteVector
extern copyVector

global biFromInt
global biFromString
global biDelete
global biAdd
global biSub
global biMul
global biCmp
global biSign
global biMul
global biToString

;Структура вектора еще раз для обращения к его полям
struc VectorInt
    sz:        resq 1
    alignSize: resq 1
    elem:      resq 1
endstruc

TEN equ 10;Константа 10
BASE equ 100000000;Основание системы счисления = 10^8
BASE_LEN equ 8;Длина в цифрах одной ячейки длинной арифметики

;Структура длинного числа
struc BigInt
    sign:     resq 1;Знак - если sign == 0 - число меньше нуля, если sign == 1 - число >= 0 нуля
    vec:      resq 1;Вектор, хранящий цифры числа
endstruc

;Макрос для получения значения i-й цифры длинного числа
;Принимает
	;%1 - куда записать результат
	;%2 - длинное число
	;%3 - i-я цифра
%macro element 3;to vec index
    push r15
    mov r15, [%2 + vec];Узнаем вектор длинного числа
    mov r15, [r15 + elem];Узнаем массив вектора, хранящий данные
    mov %1, dword [r15 + 4*%3];Записываем в %1 цифру с индексом %3
    pop r15
%endmacro

;Макрос для получения длины числа
	;%1 - куда записать результат
	;%2 - длинное число
%macro length 2;to vec
    push r15
    mov r15, [%2 + vec];Узнаем вектор длинного числа
    mov %1, [r15 + sz];Записываем в %1 длину числа
    pop r15
%endmacro

;Удаляет длинное число
;Принимает
	;rdi - длинное число
biDelete:
    push rdi
    mov rdi, [rdi + vec]
    call deleteVector;Удаляем вектор этого длинного числа
    pop rdi
    call free_align;Удаляем структуру длинного числа
    ret

;Создает "пустое" длинное число
newBi:
    mov rdi, BigInt_size
    call malloc_align;Создаем структуру числа
    push rax
    xor rdi, rdi
    call newVector;Создаем вектор для длинного числа
    pop rdx
    mov [rdx + vec], rax
    mov rax, rdx
    ret

;Создает длинное число из строки
;Принимает
	;rdi - указатель на строку
;Возвращает - новое длинное число
biFromString:
    push rbx;Сохраняем rbx
    mov rbx, 1
    cmp byte [rdi], '-' 
    jne .not_minus;Проверяем, что первый знак минус и запоминаем в rbx
        xor rbx, rbx
        inc rdi
    .not_minus
    
    xor rcx, rcx
    .loop_end_line;Проверяем, что строка состоит из цифр
        cmp byte [rdi], '0'
        jb .error
        cmp byte [rdi], '9'
        ja .error
        inc rdi
        inc rcx
        cmp byte [rdi], 0
        jne .loop_end_line
	;rcx после цикла содержит количество цифр в числе
    cmp rcx, 0
    je .error;Если число пустое - выходим с ошибкой
    push rdi
    push rcx
    call newBi;Создаем новое пустое число
    pop rcx
    pop rdi
    mov rsi, rax
    sub rdi, rcx
    add rcx, rdi
    .loop_num;Идем с конца по числу и кладем по 8 цифр в вектор
        xor eax, eax
        mov r8, rcx;Начиная с r8-символа очередные 8 цифр числа
        sub r8, BASE_LEN
        cmp r8, rdi
        ja .calc_dig_loop
            mov r8, rdi;Если осталось меньше 8 цифр, сдвинем границы
        .calc_dig_loop
            mov edx, TEN
            mul edx
            xor edx, edx
            mov dl, [r8];В dl очередная цифра
            sub dl, '0'
            add eax, edx;eax = eax * 10 + dl
            inc r8
            cmp r8, rcx
            jne .calc_dig_loop
	;В eax после выполнения цикла очередные 8 цифр числа
        push rcx;Сохраняем регистры перед вызовом pushBack
        push rdi
        push rsi
        mov rdi, [rsi + vec]
        mov esi, eax
        call pushBack;Кладем в вектор очередные 8 цифр
        pop rsi
        pop rdi;Восстанавливаем регистры
        pop rcx
        sub rcx, BASE_LEN;Сдвигаем rcx, который указывает на конец текущей подстроки из 8 цифр
        cmp rcx, rdi
        ja .loop_num
    mov rax, rsi
    mov [rax + sign], rbx;Записывем знак числа
    length rdx, rsi
    cmp rdx, 1 
    jne .not_zero;Если строка "-0" - сохраним число как 0
        element edx, rsi, 0
        cmp edx, 0
        jne .not_zero
            mov qword [rax + sign], 1
    .not_zero
    pop rbx;Восстанавливаем rbx

	push r12
	push rax
    length r12, rax
    mov rdi, [rax + vec]
    .pop_back_zeroes_loop;Выкидываем ведущие нули
        call back
        cmp eax, 0
        jne .break
        cmp r12, 1
        je .break
        call popBack
        dec r12
        jmp .pop_back_zeroes_loop
    .break
	pop rax
    pop r12
    ret

    .error;Если ввели некорректное число - вернем NULL
    xor rax, rax
    pop rbx;Восстанавливаем rbx
    ret

;Создает длинное число из числа
;Принимает
	;rdi - указатель на строку
;Возвращает - новое длинное число

biFromInt:
    push rdi;Сохраняем число
    call newBi;Создаем новое пустое число
    pop rdi

    cmp rdi, 0
    js .minus;Выставляем знак длинного числа
        mov qword [rax + sign], 1;Знак = 1, если число >= 0
        jmp .sign_done
    .minus
        mov qword [rax + sign], 0;Знак = 0, если число < 0
        imul rdi, -1;Делаем число беззнаковым
    .sign_done

    push rax;Сохраняем регистры, чтобы не затереть вызовами функций
    push r12
    push rbx
    mov rbx, BASE;Сохраняем основание системы, чтобы оперировать с ним
    xchg rdi, rax
    mov rdi, [rdi + vec];Достаем вектор из длинного числа
    mov r12, rdi
    .push_long_long;Делим число на 10^8, кладем в результирующий вектор о статок, до тех пор, пока число не станет равным 0
        xor rdx, rdx;Обнуляем старшую часть делимого
        div rbx
        mov rsi, rdx
        push rax;В rax число, сохраняем его перед вызовом pushBack
        call pushBack
        pop rax
        mov rdi, r12
        cmp rax, 0
        jne .push_long_long
    pop rbx;Восстанавливаем регистры
    pop r12
    pop rax
    ret

;Сравнивает числа без учета знака
;Принимает
	;rdi - первое длинное число
	;rsi - второе длинное число
;Возвращает
	;1 - если числа равны
	;0 - если первое число больше второго
	;-1 - если первое число меньше второго
cmpData:
    push rbx;Сохраняем rbx
    length rax, rdi
    length rbx, rsi;Узнаем количество цифр в обоих длинных числах
    cmp rax, rbx;Сравниваем длины чисел
    ja .more;Если длина первого числа больше, чем длина второго - первое число больше
    jb .less;Если длина второго числа больше, чем длина первого - второе число больше
    ;Если длины равны
        mov rcx, rax
        dec rcx
        mov rax, [rdi + vec]
        mov rax, [rax + elem]
        lea rax, [rax + 4*rcx]

        mov rbx, [rsi + vec]
        mov rbx, [rbx + elem]
        lea rbx, [rbx + 4*rcx]
	;Записали в rax и rbx указатели на последние (в векторе) цифры чисел
        .cmp_loop;
            mov edx, [rax]
            cmp edx, [rbx];Сравниваем цифры чисел
            ja .more
            jb .less
            sub rax, 4
            sub rbx, 4
		sub rcx, 1;Уменьшаем указатели
            jns .cmp_loop
        jmp .equals
    .more;Первое число больше
        xor rax, rax
        jmp .cmpData_done
    .less;Второе число больше
        mov rax, 1
        jmp .cmpData_done
    .equals;Равны
        mov rax, -1
    .cmpData_done
    pop rbx;Восстанавливаем rbx
    ret

;Сравнивает два длинных числа
;Принимает
	;rdi - первое длинное число
	;rsi - второе длинное число
;Возвращает результат сравнения	
biCmp:
    mov rax, [rsi + sign]
    cmp [rdi + sign], rax;Сравниваем знаки чисел
    ja .more;Если знак первого числа больше - значит оно больше
    jb .less;Если знак второго числа больше - значит оно больше
    ;Знаки равны, сравниваем без учета знаков
        call cmpData
        cmp rax, 0
        js .equals;Рассматриваем результат вызова функци
        xor rax, [rdi + sign]
        cmp rax, 0
        je .less
        jmp .more
    .more;Метки для случаев сравнения
        mov eax, 1
        jmp .cmp_done
    .less
        mov eax, -1
        jmp .cmp_done
    .equals
        xor eax, eax
    .cmp_done
    ret

;Возвращает знак числа
;Принимает
	;rdi - длинное число
;Возвращает - знак длинного числа
biSign:
    cmp qword [rdi + sign], 0;Если бит знака равен нулю - число отрицательное
    je .minus
        mov rdi, [rdi + vec]
        cmp qword [rdi + sz], 1
        je .len_eq1;Если знак числа = 1 и длина числа > 1 то число положительное
            mov eax, 1
            jmp .sign_done
        .len_eq1;Если знак числа = 1 и длина числа = 1 и в векторе лежит 0 - то число нулевое, иначе положительное
            mov rax, [rdi + elem]
            cmp dword [rax], 0
            je .zero
                mov rax, 1
                jmp .sign_done
        .zero
            xor rax, rax
            jmp .sign_done
    .minus
        mov rax, -1
    .sign_done
    ret

;Складывает цифры длинного числа без учета знака
;Принимает
	;rdi - первое длинное число
	;rsi - второе длинное число
;Сохраняет результат в первом числе
addData:
    push rbx
    length r9, rdi
    length rax, rsi;Узнаем длины чисел (r9 - длина первого, rax - длина второго)
    mov r11, rax
    cmp r9, rax
    ja .ok_max
        mov r9, rax;r9 = max(r9, rax)
    .ok_max
    length r8, rdi
    cmp r8, r9
    je .not_push
	;Если длина первого числа меньше длины второго - дополним его ведущими нулями
        push rsi;Сохраняем регистры
        push rdi
        mov rdi, [rdi + vec]
        xor rsi, rsi;Будем класть нули - присваем rsi ноль
        mov rbx, r9
        .loop_push;Цикл бежит до max(len1, len2) - len1
            push r8
            call pushBack;Добавляем нули в начало числа
            pop r8
            inc r8
            cmp r8, rbx
            jb .loop_push
        pop rdi;Восстанавливаем регистры
        pop rsi
        mov r9, rbx
    .not_push

    xor r8, r8;Индекс цифры первого числа
    mov rcx, r9
    xor rax, rax;В rax будет перенос при сложении
    mov rbx, BASE;Сохраняем модуль арифметики в rbx, чтобы работать с ним
    mov r9, [rdi + vec]
    mov r9, [r9 + elem]
    mov r10, [rsi + vec]
    mov r10, [r10 + elem];Сохраняем указатели на массивы цифр длинных чисел
    .loop
        add eax, [r9 + 4*r8];Добавляем к переносу очердную цифру первого числа
        cmp r8, r11
        jnb .not_add;Если второе число еще не закончилось - добавляем его цифру в eax
            add eax, [r10 + 4*r8]
        .not_add
        xor edx, edx
        div rbx;Делим накопленную сумму в rax на основание системы счисления
        mov [r9 + 4*r8], edx;Сохраняем результат
        inc r8
        cmp r8, rcx
        jne .loop
    cmp rax, 0;Если перенос не нулевой - добавим его в конец длинного числа
    je .done
        mov rdi, [rdi + vec]
        mov rsi, rax
        call pushBack
    .done
    pop rbx;Восстанавливаем rbx
    ret

;Вычитает цифры длинного числа без учета знака
;Принимает
	;rdi - первое длинное число
	;rsi - второе длинное число
;Предполагается, что в первом числе не меньше цифр, чем во втором
;Сохраняет результат в первом числе
subData:
    length rcx, rsi;Узнаем длину меньшего числа
    xor r8, r8
    xor rax, rax;В rax будет заем из предыдущего разярад
    mov r9, [rdi + vec]
    mov r9, [r9 + elem]
    mov r10, [rsi + vec]
    mov r10, [r10 + elem];Получаем указатели на массивы с цифрами каждого числа
    .loop
        imul eax, -1
        add eax, [r9 + 4*r8]
        sub eax, [r10 + 4*r8]
	;eax = a[r8] - b[r8] - eax
        jns .pos_carry
		;Если eax < 0, то записываем результат и устанавливаем бит заема в единицу
            add eax, BASE
            mov [r9 + 4*r8], eax
            mov eax, 1
            jmp .done_sub
        .pos_carry
            mov [r9 + 4*r8], eax;Если eax >= 0 записываем результат и устанавливаем бит заема в ноль
            xor eax, eax
        .done_sub
        inc r8;Сдвигаем указатель
        cmp r8, rcx
        jne .loop

    cmp eax, 0;Если остался заем - нужно отнять его от числа
    je .done
    .sub_carry_loop;Отнимаем от числа, то что осталось от вычитания
        imul eax, -1
        add eax, [r9 + 4*r8]
        jns .pos_carry_2;Если есть заем в следующий разряд - продолжаем цикл, иначе останавливаемся
            add eax, BASE
            mov [r9 + 4*r8], eax
            mov eax, 1
            jmp .sub_carry_loop
    .pos_carry_2
    mov [r9 + 4*r8], eax

    .done
    push r12
    length r12, rdi
    mov rdi, [rdi + vec]
    .pop_back_zeroes_loop;Выкидываем из начала образовавшиеся нули
        call back
        cmp eax, 0
        jne .break
        cmp r12, 1
        je .break
        call popBack
        dec r12
        jmp .pop_back_zeroes_loop
    .break
    pop r12
    ret

;Складывает два длинных числа
;Принимает
	;rdi - первое длинное число
	;rsi - второе длинное число
;Результат сохраняет в первом числе
biAdd:
    mov rax, [rsi + sign]
    cmp rax, [rdi + sign]
    jne .not_eq_sign;Если знаки чисел равны, просто складываем их цифры
        call addData
        jmp .done
    .not_eq_sign
	;Если знаки чисел неравны
        call cmpData;Сравниваем значения чисел без учета знака
        cmp rax, 0
        je .a_more_b
            cmp rax, -1
            je .res_zero
                push rdi
                push rsi
                xchg rdi, rsi
                mov rdi, [rdi + vec]
                call copyVector;Скопируем цифры первого числа
                pop rdi
                pop rsi;Достали из стека оба числа, поменяв их местами
		;Будем вычитать из второго числа первое, затем просто поменяем вектора с цифрами местами

                push rax;Сохраняем регистры, чтобы не затереть их вызовами функций
                push rdi
                push rsi
                call subData;Вычитаем из второго числа первое
                mov rax, [rsp]
                mov rdi, [rax + vec]
                call deleteVector;Удаляем вектор первого числа
                pop rsi
                pop rdi
                mov rax, [rdi + vec];Достаем вектор из второго числа
                mov [rsi + vec], rax;И записываем его в первое
		;Восстанавливаем ветор второго числа и записываем его обратно
                pop rax
                mov [rdi + vec], rax
                mov rax, [rdi + sign]
                mov qword [rsi + sign], rax
                jmp .done
            .res_zero
                push rdi
                call subData
                pop rdi
                mov qword [rdi + sign], 1
                jmp .done
        .a_more_b
		;Если первое число больше второго (без учета знака)
            push rdi
            push rsi
            call subData;Просто вычитаем из первого второе
            pop rsi
            pop rdi
            mov rax, [rsi + sign]
            cmp [rdi + sign], rax
            ja .b_neg
		;Если первое число отрицательное, то результат будет отрицательный
                mov qword [rdi + sign], 0
            .b_neg
            jmp .done
    .done
    ret

;Вычитает два длинных числа
;Принимает
	;rdi - первое длинное число
	;rsi - второе длинное число
;Результат сохраняет в первом числе
biSub:
    push rdi
    push rsi;Сохраняем регистры, чтобы не потерять при вызове функций
    xchg rdi, rsi
    call biSign
    cmp rax, 0
    je .zero;Если второе число 0 - никак не меняем первое
        mov rsi, [rsp]
        xor qword [rsi + sign], 1;Меняем знак второго числа
        mov rdi, [rsp + 8]
        call biAdd;Вычисляем a-b как a+(-b)
        mov rsi, [rsp]
        xor qword [rsi + sign], 1;Возвращаем знак числа
    .zero
    add rsp, 16;Выкидываем сохраненные регистры
    ret

;Умножает два длинных числа
;Принимает
	;rdi - первое длинное число
	;rsi - второе длинное число
;Результат сохраняет в первом числе
biMul:
    push rbx
    push r12
    push r13;Сохраняем регистры

	;Узнаем знак числа и запоминаем его. Проверяем, если какое-то из чисел равно нулю - возвращаем ноль
    push rdi
    push rsi
    call biSign
    push rax
    mov rdi, [rsp + 8]
    call biSign
    mul qword [rsp]
    add rsp, 8
    cmp rax, 0
    je .res_zero
	
	;Находим сумму длин чисел и выделяем новый вектор такой длины
    push rax
    mov rax, [rsp + 8]
    length r13, rax;Нашли длину первого числа
    mov rsi, [rsp + 16]
    length r12, rsi;Нашли длину второго чисал
    mov rdi, r12
    add rdi, r13
    call newVector;Создали вектора такой длины
    mov rsi, [rsp + 8]
    mov rdi, [rsp + 16];Восстановили rdi и rsi
    push rax

    xor r8, r8;r8 - индекс цифры первого числа
    .loop1
        xor r9, r9;r9 - индекс цифры второго числа
        mov rcx, [rsp]
        mov rcx, [rcx + elem]
        lea rcx, [rcx + 4*r8];Считаем указатель на результирующий вектор, который указывает в позицию r8
        xor rax, rax;В rax перенос в следующий разряд
        .loop2
            xor rdx, rdx
            mov edx, [rcx]
            add rax, rdx;rax = rax + [rcx]
            mov r10, rax
            xor rax, rax
            xor rbx, rbx
            element eax, rdi, r8
            element ebx, rsi, r9;Узнаем сотвествующий элементы из вектора
            mul rbx;Умножаем их
            add rax, r10;Прибавляем предыдущий перенос
            xor rdx, rdx
            mov rbx, BASE
            div rbx;Берем по модулю
            mov [rcx], edx

            add rcx, 4;Сдвигаем указатель на результат и на цифру второго числа
            inc r9
            cmp r9, r13
            jne .loop2

            .loop_carry;Если остался какой-то перенос - сохраним его в результат
                cmp rax, 0
                je .break_loop_carry
                xor rdx, rdx
                mov edx, [rcx]
                add rax, rdx;Складываем перенос с текущей цифрой результата
                mov rbx, BASE;Берем по модулю
                div rbx;Находим остаток
                mov dword [rcx], edx;Записываем в результат
                add rcx, 4;Сдвигаем указатель на цифру результат
                jmp .loop_carry
            .break_loop_carry
        inc r8
        cmp r8, r12
        jne .loop1
    pop rax
    pop rdx
    add rsp, 16
    cmp rdx, -1;Достаем знак из стека и записываем в результат соотвествующий знак
    je .less_zero
        mov qword [rdi + sign], 1
        jmp .sign_done
    .less_zero
        mov qword [rdi + sign], 0
    .sign_done
    push rax
    push rdi
    mov rdi, [rdi + vec]
    call deleteVector;Удаляем вектор первого числа

    mov rdi, [rsp + 8]
    call back
    cmp eax, 0
    jne .no_pop_zero;Выкидываем лидирующий ноль из результирующего вектора
        call popBack
    .no_pop_zero
    pop rdi
    pop rax
    mov [rdi + vec], rax;Сохраняем результирующий вектор в первое число
    jmp .done

    .res_zero;Если результат ноль, удаляем вектор старого числа, записываем новый знак, создаем вектор с нулем
        pop rsi
        pop rdi
        mov qword [rdi + sign], 1
        push rdi
        mov rdi, [rdi + vec]
        call deleteVector
        mov rdi, 1
        call newVector
        pop rdi
        mov [rdi + vec], rax
    .done
    pop r13;Восстанавливаем регистры
    pop r12
    pop rbx
    ret


;Макрос для проверки достижения limit в biToString. Проверяет, что %1 + 1 < %2, иначе переходит к метке конца biToString
%macro check_limit 2
    mov r11, %1
    inc r11
    cmp r11, %2
    je .done_biToString
%endmacro

;Переводит число в строку и записывает в buffer
;Принимает
	;rdi - чиcло
writeToBuffer:
    push rbx;Сохраняем rbx
    mov rbx, TEN
    mov rcx, BASE_LEN
    dec rcx
    mov rax, rdi
    .loop_write_dig;Цикл вызывается 8 раз, каждый раз число делится на 10, и очередная цифра записывается в buffer
        xor rdx, rdx
        div qword rbx;Делим число на 10
        add dl, '0'
        mov [buffer + rcx], dl;Записываем цифру в buffer
        dec rcx;Уменьшаем указатель на позицию в buffer
        jns .loop_write_dig
    pop rbx;Восстанавливаем rbx
    ret

;Переводит длинное число в строку
;Принимает
	;rdi - число
	;rsi - строку
	;rdx - limit
;Строковое представление числа записывает в rsi
biToString:
    push rdi
    push rsi
    push rdx
    push rbx;Сохраняем регистры
    xor rbx, rbx
    check_limit rbx, rdx;Если передали limit = 1 - сразу выходим
    call biSign;Узнаем знак числа
    mov rdi, [rsp + 24]
    cmp rax, 0
    je .zero
    jns .not_minus;Записываем знак числа в строку
        mov rsi, [rsp + 16]
        mov byte [rsi], '-'
        inc rbx;rbx - длина уже записанных данных в строку

    .not_minus

	;Находим длину числа, записываем в результирующую строку первую цифру числа без ведущих нулей
    length rax, rdi
    mov rdi, [rdi + vec]
    mov rdi, [rdi + elem];Узнали указатель на массив с цифрами
    mov [rsp + 24], rdi;Перезаписали сохраненное длинное число вектором
    dec rax
    xor r9, r9
    mov r9d, [rdi + 4*rax]
    mov rdi, r9;Узнали первую цифру числа
    push rax
    call writeToBuffer;Записываем ее в buffer
    pop rax
    mov rdx, [rsp + 8]

    xor r8, r8
    .loop_skip_zero;Пропускаем ведущие нули
        cmp byte [buffer + r8], '0'
        jne .break_loop_skip_zero
        inc r8 
        jmp .loop_skip_zero
    .break_loop_skip_zero
	;В r8 указатель на первую ненулевую цифру в buffer

    .loop_write_first_digit;Переносим цифры из buffer в результирующую строку
	check_limit rbx, rdx
        mov cl, [buffer + r8]
        mov [rsi + rbx], cl;Записываем очередную цифру в из буфера в результирующую строку
        inc rbx
        inc r8;Сдвигаем указатели 
        cmp r8, BASE_LEN
        jne .loop_write_first_digit

    dec rax
    .loop_to_string
        cmp rax, 0
        js .break_loop_to_string
        xor r8, r8

        mov rdi, [rsp + 24]
        xor r9d, r9d
        mov r9d, [rdi + 4*rax];Достаем очередную цифру длинного числа
        mov rdi, r9
        push rax
        call writeToBuffer;Переводим ее в buffer
        pop rax

        mov rdx, [rsp + 8]
        .write_dig;Записываем из буфера в результирующую строку
            check_limit rbx, rdx
            mov cl, [buffer + r8];Достаем очередную цифру из буфера
            mov [rsi + rbx], cl;Записуем в результирующую строку
            inc rbx
            inc r8;Сдвигаем указатели
            cmp r8, BASE_LEN
            jne .write_dig
         dec rax
         jmp .loop_to_string
    .break_loop_to_string
    jmp .done_biToString

    .zero;Если число равно нулю - обработаем это отдельно
        mov rsi, [rsp + 16]
        mov byte [rsi], '0'
        inc rbx
    .done_biToString
    mov byte [rsi + rbx], 0;Записуем терминальный символ
    pop rbx;Восстанавливаем rbx
    add rsp, 24;Выкидываем из стека элементы
    ret

section .bss
    buffer: resb 10;Буфер для сохранения строкового представления каждой цифры длинного числа
