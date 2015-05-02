#ifndef _REGCHK_H
#define _REGCHK_H

#ifdef __cplusplus
extern "C"
#endif
size_t __regchk(void *f, ...);

#define regchk(f, ...) __regchk(reinterpret_cast<void*>(f), ##__VA_ARGS__)

#endif
