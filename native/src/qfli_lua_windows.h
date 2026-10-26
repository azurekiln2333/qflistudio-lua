#ifndef QFLI_LUA_WINDOWS_H
#define QFLI_LUA_WINDOWS_H

#include <stdio.h>

FILE *qfli_utf8_fopen(const char *filename, const char *mode);
FILE *qfli_utf8_freopen(const char *filename, const char *mode, FILE *stream);
int qfli_utf8_remove(const char *filename);
int qfli_utf8_rename(const char *source, const char *destination);
int qfli_utf8_regular_file(const char *filename);
char *qfli_utf8_absolute_path(const char *filename);
FILE *qfli_utf8_create_exclusive(const char *filename);

#define fopen qfli_utf8_fopen
#define freopen qfli_utf8_freopen
#define remove qfli_utf8_remove
#define rename qfli_utf8_rename

#endif
