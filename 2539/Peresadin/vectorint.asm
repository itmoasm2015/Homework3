default rel

section .text

extern malloc
extern free

global newVector
global pushBack
global popBack
global back
global deleteVector
global copyVector
global malloc_align
global free_align

;Вектор int-ов
struc VectorInt
    sz:        resq 1;фактический размер вектора
    alignSize: resq 1;выровняный до степени двойки
    elem:      resq 1;элементы вектора
endstruc

;malloc с выравниванием
;Принимает
	;rdi - размер блока памяти
	;Cтек выровнен на 8
;Возвращает 
	;rax - указатель на адрес памяти
malloc_align:
    test rsp, 15
    jz .call_malloc
	;Выравниваем стек
	sub rsp, 8
        call malloc
        add rsp, 8
        ret
    .call_malloc
    call malloc
    ret

;free с выравниванием
;Принимает
	;rdi - удаляемая память
	;Cтек выровнен на 8
;Возвращает 
	;rax - указатель на адрес памяти
free_align:
    test rsp, 15
    jz .call_free
	;Выравниваем стек
        push rdi
        call free
        pop rdi
        ret
    .call_free
    call free
    ret

;Создает новый вектор
;Принимает
	;rdi - размер вектора
;Возвращает
	;rax - вектор заполненый нулями
newVector:
    mov rax, 1;находим выровненный размер
    .loop
        shl rax, 1
        cmp rdi, rax
        jae .loop
    push rax
    push rdi
    mov rdi, VectorInt_size
    call malloc_align;создаем структуру вектора
	;заполняем поля вектора
    pop rdi
    mov [rax + sz], rdi
    mov rdx, rax
    pop rax
    mov [rdx + alignSize], rax
    push rdx
    mov rdi, rax
    shl rdi, 2
    call malloc_align;создаем массив для данных
    pop rdx
    mov [rdx + elem], rax
    mov rax, rdx

	;заполняем массив нулями. Не используем calloc, т.к. с выравниваем это займет столько же кода
    mov rcx, [rax + sz]
    shl rcx, 2
    cmp rcx, 0
    je .size_zero
    mov rdx, [rax + elem]
    .loop_set
        mov dword [rdx + rcx - 4], 0
        sub rcx, 4
        jnz .loop_set

    .size_zero
    ret

;Переаллоцирует память вектора при сужении и расширении
;Принимает
	;rdi - вектор
	;rsi - новый выровненный размер вектора
copyElem:
	;Выделяем новую память
    push rdi
    mov [rdi + alignSize], rsi
    mov rdi, rsi
    shl rdi, 2
    call malloc_align
    pop rdi

	;Копируем старые данные в новую память
    mov rcx, [rdi + sz]
    shl rcx, 2
    cmp rcx, 0
    je .size_zero
    mov rdx, [rdi + elem]
    .loop_copy
        mov esi, [rdx + rcx - 4]
        mov [rax + rcx - 4], esi
        sub rcx, 4
        jnz .loop_copy
    .size_zero

	;Удаляем старую память
    push rdi
    push rax
    mov rdi, [rdi + elem]
    call free_align
    pop rax
    pop rdi
    mov [rdi + elem], rax;Присваиваем новую память в вектор
    ret

;Добавляет в конец вектора элемент
;Принимает
	;rdi - вектор
	;esi - элемент
pushBack:
    mov rax, [rdi + alignSize]
    cmp [rdi + sz], rax
    jne .push_back;Проверяем, если не достигли выровненного размера - просто кладем в конец, 
    ;align size
	;иначе выделяем новый кусок памяти в 2 раза больше предыдущего
        push rdi
        push rsi
        mov rsi, [rdi + alignSize]
        shl rsi, 1
        call copyElem
        pop rsi
        pop rdi
    .push_back
	;Кладем в конец вектора новый элемент, увеличиваем размер вектора
    mov rax, [rdi + sz]
    mov rdx, [rdi + elem]
    mov [rdx + 4*rax], esi
    inc qword [rdi + sz]
    ret

;Удаляет элемент из конца вектора элемент
;Принимает
	;rdi - вектор
popBack:
    dec qword [rdi + sz]
    mov rax, [rdi + sz]
    shl rax, 2
    cmp rax, [rdi + alignSize]
    ja .not_copy;Поверяем, если 4*sz=alignSize, то удаляем старую память, выделяем кусок в два раза меньше
        mov rsi, [rdi + alignSize]
        shr rsi, 1
        call copyElem
    .not_copy
    ret

;Возвращает последний элемент вектора
;Принимает
	;rdi - вектор
;Возвращает
	;esi - последний элемент
back:
    mov rax, [rdi + sz];Берем размер вектора
    dec rax
    shl rax, 2
    add rax, [rdi + elem]
    mov eax, [rax];Возвращаем sz-1 элемент
    ret

;Возвращает копию вектора
;Принимает 
	;rdi - вектор
;Возвращает
	;rax - копия исходного вектора
copyVector:
    push rdi
    mov rdi, VectorInt_size
    call malloc_align;Создаем новый вектор
    push rax
    mov rcx, [rsp + 8]
    mov rdx, [rcx + sz]
    mov [rax + sz], rdx;Копируем размер
    mov rdx, [rcx + alignSize]
    mov [rax + alignSize], rdx;Копируем выровненный размер
    mov rdi, rdx
    shl rdi, 2
    call malloc_align;Создаем память для вектора
    pop rdx
    pop rdi

	;Копируем элементы из старого в новый вектор
    mov rcx, [rdi + sz]
    shl rcx, 2
    cmp rcx, 0
    je .size_zero
    mov r8, [rdi + elem]
    .loop_copy
        mov esi, [r8 + rcx - 4]
        mov [rax + rcx - 4], esi
        sub rcx, 4
        jnz .loop_copy
    .size_zero
    mov [rdx + elem], rax;Сохраняем выделенный массив в новый вектор
    mov rax, rdx;Возвращаем новый вектор
    ret

;Удаляет вектор
;Принимает
	;rdi - вектор
deleteVector:
    push rdi
    mov rdi, [rdi + elem]
    call free_align;Удаляем массив вектора
    pop rdi
    call free_align;Удаляем структуру вектора
    ret
