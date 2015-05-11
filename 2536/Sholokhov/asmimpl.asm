default rel

section .text

	extern malloc
	extern free

	global biCopy

	global biFromInt
	global biFromString
	global biToString
	global biDelete
	global biSign
	global biAdd
	global biSub
	global biMul
	global biCmp
	global biDivRem

TEN 	equ	10		;; Это десять (с). Используется в biFromString и biToString.
BASE	equ 	100000000 	;; 10^8. Основание системы счисления.
DIG_LEN	equ	8		;; Длина одного разряда в символах

	struc	BigInt		
sign:	resq	1		;; Знак (1 если отрицательное, 0 если положительное)
elem:	resq	1		;; Массив разрядов числа
vsize:	resq	1		;; Размер вектора (количество реально существующих элементов)
limit:	resq	1		;; Capacity вектора
	endstruc


	;; Макрос для must save регистров	
	%macro syspush 0
		push	rbx
		push	rbp
		push	r12
		push	r13
		push	r14
		push	r15
	%endmacro 

	;; The same
	%macro syspop 0
		pop	r15
		pop	r14
		pop	r13
		pop	r12
		pop	rbp
		pop	rbx
	%endmacro


	;; Malloc, который проверяет выравнивание стека и, если надо, выравнивает
	;; TAKES:
	;;	RDI - необходимая память в байтах
	;; RETURNS:
	;;	RAx - саллоцированная память

alligned_malloc:
		test	rsp, 15
		jz	.malloc
		sub	rsp, 8
		call	malloc
		add	rsp, 8
		ret			
.malloc		call	malloc
		ret

	;; Free, с выравниванием
	;; TAKES:
	;;	RDI - освобождаемая память

alligned_free:
		test	rsp, 15
		jz	.free
		sub	rsp, 8
		call	free
		add	rsp, 8
		ret			
.free		call	free
		ret


	;; BigInt biInit(int64_t size)
	;; Создает BigInt с начальным capacity внутреннего вектора равым 2^size
	;; TAKES:
	;;	RDI - начальный размер внутреннего вектор
	;; RETURNS:
	;;	RAX - новосозданный BigInt
biInit:		syspush
		push	r8			;; Сохраняем все необходимое перед
		push	r9			;; вызовом внешних функций
		push	rsi
		push	rdx
		mov	r8, rdi
		mov	rdi, BigInt_size	
		push	r8	
		call 	alligned_malloc		;; Создаем структуру BigIntа
		pop	r8
		mov	r9, 1
.loop		shl	r9, 1			;; Считаем размер внутреннего вектора
		dec	r8			;; size = 2^r8
		jnz	.loop			
		mov	qword [rax + sign], 0	;; Инициализируем поля BigIntа дефолтными
		mov	qword [rax + vsize], 0	;; значениями (положительный, путой)
		mov	qword [rax + limit], r9
		mov	rdi, r9
		shl	rdi, 3			;; Считаем размер внутреннего вектора в байтах
		mov	r9, rax
		push	r9
		call	alligned_malloc		;; Выделяем память под внутренний вектор
		pop	r9
		mov	[r9 + elem], rax	
		mov	r8, [r9 + limit]
.loop2		mov	qword[rax], 0		;; Зануляем внутренный вектор
		add	rax, 8
		dec	r8
		jnz	.loop2
		mov	rax, r9	
		pop	rdx
		pop	rsi
		pop	r9
		pop	r8
		syspop
		ret

	;; void biDelete(BigInt a);
	;; Удаляет BigInt с его внутренним вектором
	;; TAKES:
	;;	RDI - BigInt a (удаляемый)
biDelete:	push	rdi
		mov	rdi, [rdi + elem]
		call	alligned_free
		pop	rdi
		call	alligned_free
		ret
	

	;; void biPush(BigInt a, int v)
	;; Добавляет новый (старший) разряд в BigInt
	;; TAKES:
	;;	RDI - BigInt a
	;;	RSI - int v - помещаемое значение
	;; USES:
	;;	R8 - size
biPush:		push 	r8
		push	r9
		mov	r8, [rdi + vsize]		;; Смотрим, поместится ли
		mov	r9, [rdi + limit]		;; еще один разряд во внутренний
		cmp	r8, r9				;; вектор BigInta,
		jl	.after				;;
		call	biEnl				;; и если нет, то расширяем
.after		mov	r9, [rdi + elem]
		lea	r9, [r9 + r8 * 8]
		mov	[r9], rsi
		inc	r8
		mov	[rdi + vsize], r8
		pop	r9
		pop	r8
		ret

	;; void biEnl(BigInt a)
	;; Увеличивает capacity внутреннего вектора BigInta в два раза
	;; TAKES:
	;;	RDI - расширяемый BigInt
biEnl: 		syspush
		push	r8
		push	r9
		push	r10
		push	rax
		push	rsi
		push	rdx
		push	rcx

		mov	rsi, rdi
		mov	rdi, [rsi + limit]
		shl	rdi, 4				;; Подсчитываем размер нового вектора
		push	rsi
		push	rdi
		call	alligned_malloc			;; Выделяем память под вектор
		pop	rdi
		pop	rsi
		shr	rdi, 3			
		mov	[rsi + limit], rdi		;; Сохраняем новое значение capacity
		mov	r8, [rsi + elem]
		mov	r10, [rsi + vsize]	
		mov	r9, rax
.enl_loop	mov	rdi, [r8]			;; Копируем содержимое старого внутреннего
		mov	[r9], rdi			;; вектора в новый
		add	r8, 8
		add	r9, 8
		dec	r10
		jnz	.enl_loop
		mov	rdi, [rsi + elem]		
		mov	[rsi + elem], rax		;; Помещаем новый вектор на место старого
		push	rsi				
		call	alligned_free				;; Удаляем старый вектор
		pop	rsi
		mov	rdi, rsi
		
		pop	rcx
		pop	rdx
		pop	rsi	
		pop	rax
		pop	r10
		pop	r9
		pop	r8
		syspop	
		ret

		;; int biPop(BigInt a)
		;; Возвращает старший разряд BigInta (на практике используется для его удаления)
		;; TAKES:
		;;	RDI - BigIn a
		;; RETURNS:
		;;	RAX - верхний разряд числа (из вектора он удаляется). Если вектор путой - возвращает -1.
biPop 		mov	r8, [rdi + vsize]
		cmp	r8, 0
		jne	.to_pop
		mov	rax, -1
		jmp	.to_pop_end
.to_pop		dec	r8
		mov	r9, [rdi + elem]
		lea	r9, [r9 + r8 * 8]
		mov	rax, [r9]
		mov	[rdi + vsize], r8
.to_pop_end	ret


		;; int biHead(BigInt a)
		;; Возвращает верхний разряд числа, не удаляя его из вектора
		;; TAKES:
		;;	RDI - BigInt a
		;; RETURNS:
		;;	RAX - Верхний разряд числа
biHead		mov	r8, [rdi + elem]
		mov	r9, [rdi + vsize]
		dec	r9
		lea	r8, [r8 + r9 * 8]
		mov	rax, [r8]
		ret

		;; BigInt biFromInt(int64_t a)
		;; Конструктор BigInta от int64_t
		;; TAKES:
		;;	RDI - начальное значение BigIntа
		;; RETURNS:
		;;	RAX - новосозданный BigInt
biFromInt:	push	rdi
		mov	rdi, 1
		call	biInit			;; Создаем пустой BigInt
		pop	rdi
		cmp	rdi, 0			;; Определяем знак
		jge	.after_sign	
		mov	qword[rax + sign], 1	
		neg	rdi
.after_sign	xchg	rdi, rax
		mov	rcx, BASE

.loop		xor 	rdx, rdx		;; Делим Int на BASE и помещаем разряды в BigInt, пока не 0.
		div	rcx
		mov	rsi, rdx
		push	rax
		push	rcx
		call	biPush
		pop	rcx
		pop	rax
		cmp	rax, 0
		jne	.loop
		
.end		mov	rax, rdi
		ret

		;; BigInt biFromString(char const* s);
		;; Конструктор BigInta от строки
		;; TAKES:
		;;	RDI - строка с начальным значение BigInta 
		;; RETURNS:
		;;	RAX - новосозданный BigInt
biFromString:	syspush
		push	rdx
		push	rcx
		push	r8
		push	r9
		push	r10

		mov	rdx, rdi
		mov	rdi, 1			;;
		call	biInit			;; Создаем пустой BigInt
		cmp	byte[rdx], '-'		;; Определяем знак: если первый символ - минус, то число отрицательное
		jne	.not_minus			
		mov	qword[rax + sign], 1
		inc	rdx			

.not_minus	xor	rcx, rcx		;; Проверяем строку на корректность: если последовательность состоит не только из цифр, то строка некорректна
.correct_check	cmp	byte[rdx], '9'	
		jg	.fail	 
		cmp	byte[rdx], '0'	
		jl	.fail		
		inc	rdx		
		inc	rcx		
		cmp	byte[rdx], 0
		jne	.correct_check
		cmp	rcx, 0
		je	.fail	
		dec	rdx		

	;; Перевод строки в число. Общий алгоритм: считываем по 8 символов из строки,
	;; формируем из них очередной разряд числа, после этого помещаем число во
	;; внутренний вектор BigInta. Начинаем с младшего разряда. И так пока строка не кончится.
		mov	rbp, rdx	
		mov	rdi, rax	
		mov	r8, TEN		
.loop_by_8	mov	r10, 1		
		xor	rsi, rsi	
		xor	rax, rax	
		mov	r9, DIG_LEN	
		cmp	rcx, DIG_LEN	
		jge	.loop_by_1
		mov	r9, rcx		
.loop_by_1	mov	al, byte[rbp]
		sub	al, '0'
		mul	r10
		add	rsi, rax
		mov	rax, r10
		mul	r8
		mov	r10, rax
		xor	rax, rax
		xor	rdx, rdx
		dec	rbp
		dec	rcx
		dec	r9
		jnz	.loop_by_1
		push	rcx
		call	biPush		
		pop	rcx	
.after_push	cmp	rcx, 0
		jg	.loop_by_8
		
.clr_zeroes	call 	biHead			;; Избавляемся от лидирующих нулей во внутреннем векторе
		cmp	rax, 0
		jne	.to_zero_sign
		call	biPop
		jmp	.clr_zeroes	
		
.to_zero_sign	cmp	qword[rdi + vsize], 0	;; Если вектор так и остался пустым - мы считали 0
		jne	.to_ret
		mov	qword[rdi + sign], 0	;; знак нуля - 0. (это обработка случая biFromString("-0")

.to_ret		mov	rax, rdi
		pop	r10
		pop	r9
		pop	r8
		pop	rcx
		pop	rdx
		syspop
		ret

.fail		mov 	rax, 0			;; Если строка некорректна - возвращаем NULL
		pop	r10
		pop	r9
		pop	r8
		pop	rcx
		pop	rdx
		syspop
		ret
					

		;; void biAddMod(BigInt dst, BigInt src)
		;; Сложение двух чисел по модулю (DST += STC). Сохраняет знак DST.
		;; TAKES:
		;;	RDI - dst
		;;	RSI - src
		;; RETURNS:
		;;	RDI - dst + src

biAddMod:	syspush
		push	rdi
		push	rsi
		mov	rdi, 2
		call 	biInit			;; Создаем пустой BigInt	
		pop	rsi
		pop	rdi
		xor	r13, r13	 	
		mov	r9, [rdi + vsize]	;; Определяем какое из чисел длиньше своим вектором
		mov	r10, [rsi + vsize]
		cmp	r9, r10
		jle	.counting
		xchg	r9, r10			;; Если RDI < RSI - меняем их местами
		xchg	rdi, rsi	
		mov	r13, 1			;; Флаг, что мы меняли местами числа
.counting	mov	rcx, r9			;; Подготовка к сложению: настраиваем флаги, указатели, итераторы, счетчики
		mov	r9, [rdi + elem]
		mov	r10, [rsi + elem]
		mov	r11, rdi
		mov 	r12, rsi
		mov	rdi, rax
		mov	r14, BASE
		xor	rax, rax
		xor	rdx, rdx
.loop		add	rax, [r9]		;; Складываем два разряда
		add	rax, [r10]
		div	r14			;; Делим на базу
		mov	rsi, rdx		
		call 	biPush			;; помещаем в новый разряд что вместилось
		xor 	rdx, rdx		;; а что не вместилось - останется в rax как перенос на следующий разряд
		add	r9, 8
		add	r10, 8
		dec	rcx
		jnz	.loop
		
		mov	rcx, [r12 + vsize]	;; Если одно число имело больший разряд чем другое -
		sub	rcx, [r11 + vsize]	;; Переносим эти разряды в новое число с учетом переполнения
		jz	.last_digit

.loop2		add	rax, [r10]
		div	r14
		mov	rsi, rdx
		call	biPush
		xor	rdx, rdx
		add	r10, 8
		dec	rcx
		jnz	.loop2	

.last_digit	cmp	rax, 0			;; Смотрим, не переполнились ли мы в последнем сложении
		je	.to_end
		mov	rsi, rax
		call 	biPush			;; если да - добавляем новый разряд

.to_end		cmp	r13, 0
		je	.end
		xchg	r11, r12
.end		mov	rsi, rdi
		mov	rdi, r11
		push	r12
		call    biCopy
		pop	rsi
		syspop
		ret



		;; void biSubMod(BigInt dst, BigInt src)
		;; Вычитает SRC из DST. DST должен быть больше SRC (обеспечивается вызывающими функциями, сама функция глобальной не является)
		;; TAKES:
		;;	RDI - dst 
		;;	RSI - src
biSubMod:	syspush
		mov	rcx, [rsi + vsize]		;; Настраиваем итераторы и счетчик перед циклом
		mov	r9, [rdi + elem]
		mov	r10, [rsi + elem]
		xor	rax, rax
		xor	rdx, rdx

.loop		add	rax, [r9]			;; отнимаем от одного разряда другой соответствующий ему
		sub	rax, [r10]
		jns	.ins_plus			;; если не переполнилось - помещаем назад как есть
		add	rax, BASE			;; если переполнилось, то 
		mov	[r9], rax			;; помещаем, прибавив базу
		mov	rax, -1				;; и оставляем перенос в rax для следующей итерации
		add	r9, 8
		add	r10, 8
		dec	rcx
		jnz	.loop
		jmp	.to_loop2		
.ins_plus	mov	[r9], rax			
		xor	rax, rax
		add	r9, 8
		add	r10, 8
		dec	rcx
		jnz	.loop
		
.to_loop2	mov	rcx, [rdi + vsize]		;; По аналогии со сложением: если одно число длиньше другого,
		sub	rcx, [rsi + vsize]		;; то проходимся по остатку числа с учетом переноса
		jz	.to_end

.loop2		add	rax, [r9]
		jns	.ins_plus2
		add	rax, BASE
		mov	[r9], rax
		mov	rax, -1
		add	r9, 8
		dec	rcx		
		jmp	.loop2		
.ins_plus2	mov	[r9], rax
		xor	rax, rax
		add	r9, 8
		dec	rcx
		jnz	.loop2		

.to_end		sub	r9, 8				;; Удаляем лидирующие нули
		cmp	qword[r9], 0
		jne	.end
		call	biPop
		jmp	.to_end
.end		syspop
		ret

		;; void biSub(BigInt a, BigInt b)
		;; Вычитает из первого числа второе. 
		;; TAKES:
		;;	RDI - BigInt a
		;; 	RSI - BigInt b
biSub:		mov	rax, [rsi + sign]
		xor	rax, 1
		mov	[rsi + sign], rax
		push	rsi
		call	biAdd
		pop	rsi
		mov	rax, [rsi + sign]
		xor	rax, 1
		mov	[rsi + sign], rax
		ret

		;; void biAdd(BigInt a, BigInt b);
		;; Складывает два числа учитывая знак
		;; TAKES:
		;;	RDI - BigInt a
		;;	RSI - BigInt b
biAdd:		cmp	qword[rsi + vsize], 0		;; Если b == 0, то ответ - a
		je	.to_ret
		cmp	qword[rdi + vsize], 0		;; Если a == 0, то скопируем b в а
		jne	.not_zeroes
		call	biCopy
		jmp	.to_ret

.not_zeroes	mov	rax, [rdi + sign]
		cmp	rax, qword[rsi + sign] 	;; если числа разного знака - отнимем одно от другого.
		jne 	.sub
		push 	rax
		call	biAddMod		;; иначе - сложим
		pop	rax
		mov	[rdi + sign], rax
.to_ret		ret
.sub		call	biCmpMod		;; Если a больше по модулю чем b - отнимаем как есть
		cmp	rax, 0
		jl	.sub_rev		;; Иначе - меняем местами
		je	.is_zero
		call 	biSubMod
		ret

.sub_rev	push	rdi		
		push	rsi
		mov	rdi, 2
		call	biInit			;; т.к. мы обязаны сохранять второй аргумент в том же виде, делаем его копию
		pop	rsi
		mov	rdi, rax
		call	biCopy
		pop	rsi
		call	biSubMod
	
		;xchg	rsi, rdi
		;call	biCopy
		;mov	rdi, rsi
		;call	biDelete	
		mov	rcx, [rsi + elem]
		mov	rax, [rdi + elem]
		mov	[rsi + elem], rax
		mov	rax, [rdi + limit]
		mov	[rsi + limit], rax
		mov	rax, [rdi + vsize]
		mov	[rsi + vsize], rax
		mov	rax, [rdi + sign]
		mov	[rsi + sign], rax
		push 	rcx
		call	alligned_free		;; удаляем раннее нами созданный вспомогательный BigInt
		pop	rdi
		call	alligned_free
		ret

.is_zero	push	rdi
		mov	rdi, 1
		call	biInit
		pop	rdi
		mov	rsi, rax
		call	biCopy
		ret
		;; void biCopy(BigInt dst, BigInt src)
		;; Копирует src в dst
		;; TAKES:
		;;	RDI - BigInt dst
		;;	RSI - BigInt src
biCopy		push	rdi
		push	rsi
		mov	rdi, [rsi + limit]
		shl	rdi, 3
		call	alligned_malloc			;; создаем новый вектор такого же размера, как внуренний вектор src
		pop	rsi
		pop	rdi
		mov	rdx, rax
		push	rdx
		push	rsi
		push	rdi
		mov	rdi, [rdi + elem]
		call 	alligned_free			;; удаляем старый вектор dst
		pop	rdi
		pop	rsi
		pop	rdx
		mov	rax, [rsi + vsize]		;; переносим все (кроме вектора) поля из src в dst
		mov	[rdi + vsize], rax
		mov	rax, [rsi + limit]
		mov	[rdi + limit], rax
		mov	rax, [rsi + sign]
		mov	[rdi + sign], rax
		mov	r8, rdx
		mov	r9, [rsi + elem]
		mov	rcx, [rsi + vsize]
.loop		cmp	rcx, 0
		jle	.to_ret
		mov	rax, [r9]			;; копируем содержимое вектора src в новосозданный вектор
		mov	[r8], rax
		add	r9, 8
		add	r8, 8
		dec	rcx
		jmp	.loop
.to_ret		mov	[rdi + elem], rdx		;; помещаем новый вектор как внутренний вектор dst
		ret
		

		;; void biMulSc(BigInt a, int k, int shift)
		;; Скалярный Mul. Умножает BigInt a на Int k. Использовался в предыдущей версии biMul. Сейчас не используется, посему не прокомментированно.
		;; TAKES:
		;;	RDI - BigInt a
		;;	RSI - int k; 0 < k < BASE
		;;	RDX - int shift; < a.size
biMulSc:	syspush
		mov	rcx, [rdi + vsize]
		sub	rcx, rdx
		mov	r8, [rdi + elem]
		lea	r8, [r8 + rdx * 8]
		mov	r9, BASE
		xor	rax, rax
		xor	rdx, rdx
		xor	rbx, rbx

.loop		mov	rax, [r8]
		mul	rsi
		add	rax, rbx
		div	r9
		mov	[r8], rdx 
		mov	rbx, rax
		xor	rdx, rdx
		add	r8, 8
		dec	rcx
		jnz	.loop
		
		cmp	rbx, 0
		je	.to_end	
		mov	rsi, rbx
		call	biPush
.to_end		syspop
		ret

		;; void BiMul(BigInt dst, BigInt src);
		;; Умножает dst на BigInt src (dst *= src)
		;; TAKES:
		;;	RDI - BigInt dst
		;;	RSI - BigInt src
biMul:		syspush
		mov	r8, 0
		cmp	rdi, rsi		;; Проверяем, не ссылаются ли dst и src на один и тот жее BigInt
		jne	.to_size		;; если они разные - работаем как есть
		push	rdi			;; если нет - копируем.
		mov	rdi, 1
		call	biInit			;; создаем пустой BigInt
		pop	rsi
		mov	rdi, rax
		call	biCopy			;; копируем туда src
		xchg	rdi, rsi
		mov	r8, 1			;; поднимаем флаг, что мы создали фиктивный BigInt
		push	rsi

.to_size	push	r8			;; Сохраняем флаг
		mov	rax, [rdi + vsize]
		add	rax, [rsi + vsize]
		push	rax			;; Считаем максимальный размер результата (сумма размеров исходных чисел) и сохраняем его
		xor	rcx, rcx
.lencount	inc	rcx			;; Берем логарифм по основанию 2 от длинны (для вызова конструктора)
		shr	rax, 1
		jnz	.lencount
		inc	rcx
		
		push	rsi
		push	rdi
		mov	rdi, rcx
		call	biInit			;; Создаем BigInt под результат
		pop	rdi
		pop	rsi
		mov	r10, rax		
		pop	rax
		mov	[r10 + vsize], rax		

		mov	r8, [rdi + sign]	;; Определяем знак результата
		xor	r8, [rsi + sign]
		mov	[r10 + sign], r8

		xor 	rax, rax		;; Настраиваем итераторы, счетчики и константы
		xor	rdx, rdx
		mov	r13, BASE
		mov	r8, [rdi + vsize]
		mov	r9, [rsi + vsize]
	
	;; Вычисляем результат используя алгоритм быстрого перемноженя двух длинных чисел
		mov	r11, 0	
.loop1		mov	r12, 0
		xor	rcx, rcx
					
.loop2		mov	r14, [rdi + elem]
		mov	rax, [r14 + r11*8]
		mov	r14, [rsi + elem]
		mul	qword[r14 + 8 * r12]
		add	rax, rcx
		lea	rbx, [r11 + r12]
		mov	r14, [r10 + elem]
		add	rax, [r14 + 8 * rbx]
		div	r13
		mov	rcx, rax
		mov	[r14 + 8 * rbx], rdx
		xor	rdx, rdx
		inc	r12
		cmp	r12, r9
		jne	.loop2

		lea	rbx, [r11 + r9]
		mov	r14, [r10 + elem]
		mov	[r14 + 8*rbx], rcx
		inc	r11
		cmp	r11, r8
		jne	.loop1
		

		push	rdi
		mov	rdi, r10		
.clr_zeroes	call	biHead				;; Удаляем лидирующие нули
		cmp	rax, 0
		jne	.to_copy
		call	biPop
		jmp	.clr_zeroes	
	
.to_copy	mov	rsi, rdi			;; Копируем в DST результат вычислений
		pop	rdi
		push	rsi
		call	biCopy
		pop	rdi
		call	biDelete			;; Удаляем BigInt, в котором считали результат
		
		pop	r8				;; Воскрешаем флаг
		cmp	r8, 1				;; Смотрим, создавали ли мы фиктивный BigInt (случай biMul(a, a))
		jne	.to_ret
		pop	rdi			
		call	biDelete			;; Если да, то удаляем его
.to_ret		syspop	
		ret


		;; void biToStringAsIs(BigInt src, char* buf)
		;; Выводит BigInt как строку в buf.
		;; TAKES:
		;;	RDI - BigInt src
		;;	RSI - выходной буфер buf
		;;	RDX - лимит на число выводимых знаков (с учетом минуса, если он есть)
biToString:	syspush
		push	rdi
		push 	rsi
		push	rdx
		mov	rdi, [rdi + vsize]		;; Хоть у нас и хранятся числа в десячином виде по 8 разрядов,	
		inc	rdi				;; если мы будем выводить как есть, то получим обратную запись.
		shl	rdi, 4				;; Поэтому нам необходим промежуточный буфер,
		call	alligned_malloc			;; который мы и создаем.
		pop	rdx
		pop	rsi
		pop	rdi
		mov	r11, rax
		push	rsi
		push	rax
		push 	rdx
		mov	rcx, [rdi + vsize]		;; Настраиваем счетчик
		mov	r10, [rdi + elem]		;; Настраиваем итератор
		
.to_module	mov	r8, 10				;; Настраиваем константы
		xor	rbx, rbx
.get_new	mov	rax, [r10]			
		mov	r9, DIG_LEN	
		cmp	rcx, 1
		jg	.div_loop
		mov	r9, 0	
.div_loop	xor 	rdx, rdx			;; Выводим посимвольно каждый разряд в буфер
		div	r8
		add	rdx, '0'
		mov	[r11], dl
		inc	r11
		inc	rbx
		dec	r9
		cmp	rax, 0
		jg	.div_loop
		
.zero_out	cmp	r9, 0				;; Если в очередном разряде меньше символов, чем надо (лидирующие нули), то выводим нули до DIG_LEN
		jle	.after_div
		mov	rdx, '0'
		mov	[r11], dl
		inc	r11
		inc	rbx
		dec	r9
		jmp	.zero_out

.after_div	add	r10, 8				;; Проверяем, дошли до конца или нет, и если нет - берем новый разряд
		dec	rcx
		cmp	rcx, 0
		jg	.get_new

		cmp	qword[rdi + sign], 1		;; если число отрицательное - выводим '-'
		jne	.to_rev_out	
		mov	byte [r11], '-'
		inc	r11
		inc	rbx		
		
.to_rev_out	dec	r11				;; сравниваем limit и длинну числа. Берем то, что меньше и выводим ровно столько символов
		pop	rdx
		cmp	rbx, rdx
		jle	.reverse_loop
		xchg	rbx, rdx
		
.reverse_loop	cmp	rbx, 0				;; проходимся по промежуточному буферу в обратном порядке и копируем посимвольно в buf.
		jle	.to_end
		mov	al, byte[r11]
		mov	[rsi], al
		dec	r11
		inc	rsi
		dec	rbx
		jmp	.reverse_loop

.to_end		mov	byte[rsi], 0
		pop	rdi
		call 	alligned_free			;; удаляем промежуточный буфер
		pop	rsi
		mov	al, byte[rsi]
		syspop	
		ret		


		;; Int biSign(BigInt a)
		;; Возвращает знак числа
		;; TAKES:
		;;	RDI - BigInt a
		;; RETURNS:
		;;	RAX - 1 if a > 0; 0 if a == 0; else -1
biSign:		mov	rax, [rdi + sign]
		cmp	rax, 0
		jg	.to_minus
		mov	r8, [rdi + elem]
		mov	r9, [rdi + vsize]
.loop		mov	rdx, [r8]
		cmp	rdx, 0
		jg	.to_plus
		add	r8, 8
		dec	r9
		cmp	r9, 0
		jg	.loop
		mov	rax, 0
		jmp	.to_ret
.to_plus	mov	rax, 1
		jmp	.to_ret
.to_minus	mov	rax, -1
.to_ret		ret


		;; int biCmp(BigInt a, BigInt b)
		;; TAKES:
		;;	RDI - BigInt a
		;;	RSI - BigInt b
		;; RETURNS:
		;;	RAX - 0 if a == b; 1 if a > b; else -1
biCmp:		mov	r8, [rdi + sign]		;; сравниваем знаки чисел. Если разные - выводим ответ
		mov	r9, [rsi + sign]		
		cmp	r8, r9
		jg	.smaller
		jl	.bigger
		mov	r8, [rdi + vsize]		;; сравниваем размеры векторов чисел. Если разные - выводим ответ.
		mov	r9, [rsi + vsize]
		cmp	r8, r9
		jg	.bigger
		jl	.smaller
		mov	rcx, [rdi + vsize]
		mov	r8, [rdi + elem]		;; Проходимся по вектору числа от старших разрядов к младшим
		mov	r9, [rsi + elem]		;; если находим разные разряды - выводим ответ
		lea	r8, [r8 + 8 * rcx]
		lea	r9, [r9 + 8 * rcx]
.loop		sub	r8, 8
		sub	r9, 8
		mov	rax, [r8]
		cmp	rax, qword[r9]
		jg	.bigger
		jl	.smaller
		dec	rcx
		cmp	rcx, 0
		jg 	.loop
		mov	rax, 0				;; Если мы оказались здесь - числа равны
		jmp	.to_ret
.bigger		mov	rax, 1
		jmp	.to_ret
.smaller	mov	rax, -1
.to_ret		ret


biDivRem:	mov	rax, 0
		ret

		;; int biCmpMod(BigInt a, BigInt b)
		;; Сравнивает два числа по модулю. То же самое, что biCmp, но без учета знака
		;; TAKES:
		;;	RDI - BigInt a
		;;	RSI - BigInt b
		;; RETURNS:
		;;	RAX - 0 if a == b; 1 if a > b; else -1
biCmpMod:	mov	r8, [rdi + vsize]		;; сравниваем размеры векторов чисел. Если разные - выводим ответ.
		mov	r9, [rsi + vsize]
		cmp	r8, r9
		jg	.bigger
		jl	.smaller
		mov	rcx, [rdi + vsize]
		mov	r8, [rdi + elem]		;; Проходимся по вектору числа от старших разрядов к младшим
		mov	r9, [rsi + elem]		;; если находим разные разряды - выводим ответ
		lea	r8, [r8 + 8 * rcx]
		lea	r9, [r9 + 8 * rcx]
.loop		sub	r8, 8
		sub	r9, 8
		mov	rax, [r8]
		cmp	rax, qword[r9]
		jg	.bigger
		jl	.smaller
		dec	rcx
		cmp	rcx, 0
		jg 	.loop
		mov	rax, 0				;; Если мы оказались здесь - числа равны
		jmp	.to_ret
.bigger		mov	rax, 1
		jmp	.to_ret
.smaller	mov	rax, -1
.to_ret		ret

	

	
