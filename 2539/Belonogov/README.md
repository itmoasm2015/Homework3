Инструмент для проверки конвенции вызова
========================================

```
STUDENT_DIR=2538/Zban make
```

В результате получается библиотека libhwwrapped.a, который содержит функции с теми же именами,
в которых вызовы malloc, free и некоторых других функций обернуты в код,
проверящий выравнивание стека.

Кроме того, libhwwrapped.a содержит функцию __regcheck, которая проверяет сохранение регистров (см. regcheck.h).