#ifndef QFLI_LUA_H
#define QFLI_LUA_H

#include <stddef.h>

#ifdef _WIN32
#define QFLI_API __declspec(dllexport)
#elif defined(__APPLE__)
#define QFLI_API __attribute__((used, visibility("default")))
#else
#define QFLI_API __attribute__((visibility("default")))
#endif

typedef struct {
  int status;
  char *output;
  char *error;
  size_t output_length;
  size_t error_length;
} QfliLuaResult;

typedef struct QfliLuaCancelToken QfliLuaCancelToken;

QFLI_API const char *qfli_lua_version(void);
QFLI_API QfliLuaResult *qfli_lua_run(const char *file, const char *project_dir,
                                     int timeout_ms);
QFLI_API QfliLuaResult *qfli_lua_run_with_token(const char *file,
                                                const char *project_dir,
                                                int timeout_ms,
                                                QfliLuaCancelToken *token);
QFLI_API QfliLuaCancelToken *qfli_lua_token_new(void);
QFLI_API void qfli_lua_token_cancel(QfliLuaCancelToken *token);
QFLI_API void qfli_lua_token_free(QfliLuaCancelToken *token);
QFLI_API QfliLuaResult *qfli_lua_check(const char *file);
QFLI_API QfliLuaResult *qfli_lua_compile(const char *file, const char *output_file);
QFLI_API void qfli_lua_free(QfliLuaResult *result);

#endif
