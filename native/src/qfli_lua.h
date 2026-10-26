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

/*
 * Copyright line reported by `lua -v`, e.g.
 * "Lua 5.4.8  Copyright (C) 1994-2025 Lua.org, PUC-Rio".
 * The upstream interpreter prints this exact banner, so a terminal `lua -v`
 * can reproduce it instead of inventing its own version text.
 */
QFLI_API const char *qfli_lua_copyright(void);

QFLI_API QfliLuaResult *qfli_lua_run(const char *file, const char *project_dir,
                                     int timeout_ms);
QFLI_API QfliLuaResult *qfli_lua_run_with_token(const char *file,
                                                const char *project_dir,
                                                int timeout_ms,
                                                QfliLuaCancelToken *token);

/*
 * Runs `file` with a real command line, matching the upstream `lua`
 * interpreter:
 *
 *   - `argv` holds the command-line tokens as they were typed, so `argv[0]` is
 *     the interpreter name ("lua").
 *   - `script_index` is the index of `file` inside `argv`.
 *   - The global `arg` table is built exactly like upstream
 *     `createargtable()`: `arg[i - script_index] = argv[i]`, so the script name
 *     lands on index 0, script arguments on positive indices, and the
 *     interpreter name / pre-script options on negative indices.
 *   - Every token after `script_index` is passed to the main chunk as a
 *     vararg, so `local a, b = ...` sees the script arguments.
 *
 * Passing `argv == NULL` (or `argv_count <= 0`) keeps the plain
 * `qfli_lua_run_with_token` shape: `arg[0] = file` and no varargs. Every other
 * behaviour (project paths, module resolution, stdin/input.txt, output
 * capture, warnings, cancellation, time limits, exit status) is shared with
 * `qfli_lua_run_with_token`; this entry point only adds the command line.
 */
QFLI_API QfliLuaResult *qfli_lua_run_with_argv(
    const char *file, const char *project_dir, int timeout_ms,
    const char *const *argv, int argv_count, int script_index,
    QfliLuaCancelToken *token);
QFLI_API QfliLuaCancelToken *qfli_lua_token_new(void);
QFLI_API void qfli_lua_token_cancel(QfliLuaCancelToken *token);
QFLI_API void qfli_lua_token_free(QfliLuaCancelToken *token);
QFLI_API QfliLuaResult *qfli_lua_check(const char *file);
QFLI_API QfliLuaResult *qfli_lua_check_source(const char *source, size_t length,
                                              const char *chunk_name);
QFLI_API QfliLuaResult *qfli_lua_compile(const char *file, const char *output_file);
/* Source or bytecode; NULL output_file checks only, without execution. */
QFLI_API QfliLuaResult *qfli_lua_compile_ex(const char *file,
                                            const char *output_file, int strip);
QFLI_API void qfli_lua_free(QfliLuaResult *result);

/* Cooperative source debugger. Only pause/stop may run off the VM's thread. */
typedef struct QfliLuaDebugSession QfliLuaDebugSession;
typedef struct {
  const char *source;
  const char *name;
  int line;
} QfliLuaDebugFrame;
typedef struct {
  const char *name;
  const char *type;
  const char *value;
  size_t length;
} QfliLuaDebugValue;
QFLI_API QfliLuaDebugSession *qfli_lua_debug_new(
    const char *file, const char *project_dir, int timeout_ms);
/* action: 0 continue, 1 step into, 2 step over, 3 step out. */
QFLI_API int qfli_lua_debug_resume(QfliLuaDebugSession *session, int action);
QFLI_API void qfli_lua_debug_pause(QfliLuaDebugSession *session);
QFLI_API void qfli_lua_debug_stop(QfliLuaDebugSession *session);
QFLI_API int qfli_lua_debug_set_breakpoints(QfliLuaDebugSession *session,
    const char *const *paths, const int *lines, int count);
/* state: 0 ready, 1 paused, 2 terminated. */
QFLI_API int qfli_lua_debug_state(QfliLuaDebugSession *session);
QFLI_API QfliLuaResult *qfli_lua_debug_output(QfliLuaDebugSession *session);
/* Borrowed strings: copy before the next VM operation; frames are zero-based,
   local indexes one-based. Never evaluates code or invokes metamethods. */
QFLI_API int qfli_lua_debug_frame(QfliLuaDebugSession *session, int index,
                                   QfliLuaDebugFrame *frame);
QFLI_API int qfli_lua_debug_local(QfliLuaDebugSession *session, int frame,
    int index, QfliLuaDebugValue *value);
QFLI_API void qfli_lua_debug_free(QfliLuaDebugSession *session);

#endif
