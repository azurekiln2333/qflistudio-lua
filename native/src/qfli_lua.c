#if !defined(_WIN32)
#define _POSIX_C_SOURCE 200809L
#endif

#include "qfli_lua.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#if defined(_WIN32)
#include <windows.h>
#endif
#if !defined(_MSC_VER)
#include <stdatomic.h>
#endif

#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"

#define MAX_OUTPUT (1024 * 1024)
#define EXIT_SENTINEL "qfli_lua_script_exit"

typedef struct {
  char *data;
  size_t length;
  size_t capacity;
} OutputBuffer;

struct QfliLuaCancelToken {
#if defined(_MSC_VER)
  volatile LONG cancelled;
#else
  atomic_int cancelled;
#endif
};

typedef struct {
  OutputBuffer *output;
  OutputBuffer *error;
  double started_ms;
  int timeout_ms;
  int exit_code;
  int exit_requested;
  QfliLuaCancelToken *token;
  int warning_enabled;
  int warning_continuing;
} RunContext;

static double monotonic_ms(void) {
#if defined(_WIN32)
  LARGE_INTEGER counter, frequency;
  QueryPerformanceCounter(&counter);
  QueryPerformanceFrequency(&frequency);
  return (double)counter.QuadPart * 1000.0 / (double)frequency.QuadPart;
#else
  struct timespec time;
  clock_gettime(CLOCK_MONOTONIC, &time);
  return (double)time.tv_sec * 1000.0 + (double)time.tv_nsec / 1000000.0;
#endif
}

static int token_is_cancelled(QfliLuaCancelToken *token) {
  if (!token) return 0;
#if defined(_MSC_VER)
  return InterlockedCompareExchange(&token->cancelled, 0, 0) != 0;
#else
  return atomic_load(&token->cancelled);
#endif
}

static int append_output(OutputBuffer *buffer, const char *text, size_t length) {
  if (length > MAX_OUTPUT - buffer->length) return 0;
  size_t needed = buffer->length + length + 1;
  if (needed > buffer->capacity) {
    size_t capacity = buffer->capacity ? buffer->capacity : 256;
    while (capacity < needed) capacity *= 2;
    char *data = (char *)realloc(buffer->data, capacity);
    if (!data) return 0;
    buffer->data = data;
    buffer->capacity = capacity;
  }
  memcpy(buffer->data + buffer->length, text, length);
  buffer->length += length;
  buffer->data[buffer->length] = '\0';
  return 1;
}

static char *copy_bytes(const char *text, size_t length) {
  char *copy = (char *)malloc(length + 1);
  if (copy) {
    memcpy(copy, text, length);
    copy[length] = '\0';
  }
  return copy;
}

static char *copy_text(const char *text) { return copy_bytes(text, strlen(text)); }

static QfliLuaResult *new_result(void) {
  QfliLuaResult *result = (QfliLuaResult *)calloc(1, sizeof(QfliLuaResult));
  if (!result) return NULL;
  result->output = copy_text("");
  result->error = copy_text("");
  if (!result->output || !result->error) {
    qfli_lua_free(result);
    return NULL;
  }
  return result;
}

static void set_error_bytes(QfliLuaResult *result, const char *error,
                            size_t length) {
  if (length > MAX_OUTPUT) length = MAX_OUTPUT;
  char *message = copy_bytes(error, length);
  if (message) {
    free(result->error);
    result->error = message;
    result->error_length = length;
  }
  result->status = 1;
}

static void set_error(QfliLuaResult *result, const char *error) {
  const char *message = error ? error : "unknown Lua error";
  set_error_bytes(result, message, strlen(message));
}

static void set_lua_error(QfliLuaResult *result, lua_State *state) {
  size_t length;
  const char *message = lua_tolstring(state, -1, &length);
  if (message)
    set_error_bytes(result, message, length);
  else
    set_error(result, "unknown Lua error");
}

static void capture_warning(void *user, const char *message, int continuing) {
  RunContext *context = (RunContext *)user;
  if (!context->warning_continuing && !continuing && *message == '@') {
    if (strcmp(message, "@on") == 0) context->warning_enabled = 1;
    if (strcmp(message, "@off") == 0) context->warning_enabled = 0;
    return;
  }
  if (!context->warning_enabled) return;
  if (!context->warning_continuing)
    append_output(context->error, "Lua warning: ", 13);
  append_output(context->error, message, strlen(message));
  if (!continuing) append_output(context->error, "\n", 1);
  context->warning_continuing = continuing;
}

static int capture_print(lua_State *state) {
  RunContext *context = (RunContext *)lua_touserdata(state, lua_upvalueindex(1));
  int count = lua_gettop(state);
  for (int index = 1; index <= count; index++) {
    size_t length;
    const char *value = luaL_tolstring(state, index, &length);
    if ((index > 1 && !append_output(context->output, "\t", 1)) ||
        !append_output(context->output, value, length)) {
      return luaL_error(state, "Lua output exceeds 1 MiB or memory is exhausted");
    }
    lua_pop(state, 1);
  }
  if (!append_output(context->output, "\n", 1))
    return luaL_error(state, "Lua output exceeds 1 MiB or memory is exhausted");
  return 0;
}

static int capture_file_write(lua_State *state) {
  RunContext *context = (RunContext *)lua_touserdata(state, lua_upvalueindex(1));
  int count = lua_gettop(state);
  luaL_Stream *stream = (luaL_Stream *)luaL_checkudata(state, 1, LUA_FILEHANDLE);
  if (!stream->closef) return luaL_error(state, "attempt to use a closed file");
  int is_stdout = stream->f == stdout;
  int is_stderr = stream->f == stderr;
  if (!is_stdout && !is_stderr) {
    lua_pushvalue(state, lua_upvalueindex(2));
    lua_insert(state, 1);
    lua_call(state, count, LUA_MULTRET);
    return lua_gettop(state);
  }
  OutputBuffer *buffer = is_stdout ? context->output : context->error;
  for (int index = 2; index <= count; index++) {
    size_t length;
    const char *value;
    char number[64];
    if (lua_type(state, index) == LUA_TNUMBER) {
      int size = lua_isinteger(state, index)
                     ? snprintf(number, sizeof(number), LUA_INTEGER_FMT,
                                (LUAI_UACINT)lua_tointeger(state, index))
                     : snprintf(number, sizeof(number), LUA_NUMBER_FMT,
                                (LUAI_UACNUMBER)lua_tonumber(state, index));
      if (size < 0 || (size_t)size >= sizeof(number))
        return luaL_error(state, "Cannot format Lua number");
      length = (size_t)size;
      value = number;
    } else {
      value = luaL_checklstring(state, index, &length);
    }
    if (!append_output(buffer, value, length))
      return luaL_error(state, "Lua output exceeds 1 MiB or memory is exhausted");
  }
  lua_pushvalue(state, 1);
  return 1;
}

static int capture_write(lua_State *state) {
  lua_pushvalue(state, lua_upvalueindex(3));
  lua_call(state, 0, 1);
  lua_insert(state, 1);
  return capture_file_write(state);
}

static void install_io_capture(lua_State *state, RunContext *context) {
  lua_getglobal(state, "io");
  int io_index = lua_absindex(state, -1);
  luaL_getmetatable(state, LUA_FILEHANDLE);
  lua_getfield(state, -1, "__index");
  lua_getfield(state, -1, "write");
  lua_pushlightuserdata(state, context);
  lua_pushvalue(state, -2);
  lua_pushcclosure(state, capture_file_write, 2);
  lua_setfield(state, -3, "write");
  lua_pushlightuserdata(state, context);
  lua_pushvalue(state, -2);
  lua_getfield(state, io_index, "output");
  lua_pushcclosure(state, capture_write, 3);
  lua_setfield(state, io_index, "write");
  lua_pop(state, 4);
}

static int capture_exit(lua_State *state) {
  RunContext *context = (RunContext *)lua_touserdata(state, lua_upvalueindex(1));
  context->exit_code = lua_isboolean(state, 1)
                           ? (lua_toboolean(state, 1) ? 0 : 1)
                           : (int)luaL_optinteger(state, 1, 0);
  context->exit_requested = 1;
  lua_pushliteral(state, EXIT_SENTINEL);
  return lua_error(state);
}

static void execution_hook(lua_State *state, lua_Debug *debug) {
  (void)debug;
  RunContext *context = *(RunContext **)lua_getextraspace(state);
  if (token_is_cancelled(context->token))
    luaL_error(state, "Lua execution cancelled");
  double elapsed_ms = monotonic_ms() - context->started_ms;
  if (elapsed_ms > context->timeout_ms) luaL_error(state, "Lua execution timed out");
}

static int dump_writer(lua_State *state, const void *data, size_t size, void *user) {
  (void)state;
  return fwrite(data, 1, size, (FILE *)user) == size ? 0 : 1;
}

static int is_absolute_path(const char *path) {
  if (*path == '/') return 1;
#if defined(_WIN32)
  if (*path == '\\') return 1;
  if (((path[0] >= 'A' && path[0] <= 'Z') ||
       (path[0] >= 'a' && path[0] <= 'z')) && path[1] == ':')
    return 1;
#endif
  return 0;
}

static void push_project_file(lua_State *state, const char *file,
                              const char *project_dir) {
  if (!project_dir || !*project_dir || is_absolute_path(file))
    lua_pushstring(state, file);
  else
    lua_pushfstring(state, "%s/%s", project_dir, file);
}

static int project_call_continue(lua_State *state, int status, lua_KContext ctx) {
  (void)status;
  (void)ctx;
  return lua_gettop(state);
}

static int project_file_call(lua_State *state) {
  int count = lua_gettop(state);
  const char *project_dir = lua_tostring(state, lua_upvalueindex(2));
  int path_count = (int)lua_tointeger(state, lua_upvalueindex(3));
  for (int index = 1; index <= path_count && index <= count; index++) {
    if (lua_isstring(state, index)) {
      const char *file = lua_tostring(state, index);
      push_project_file(state, file, project_dir);
      lua_replace(state, index);
    }
  }
  lua_pushvalue(state, lua_upvalueindex(1));
  lua_insert(state, 1);
  lua_callk(state, count, LUA_MULTRET, 0, project_call_continue);
  return lua_gettop(state);
}

static void wrap_project_file(lua_State *state, int table, const char *name,
                              const char *project_dir, int path_count) {
  table = lua_absindex(state, table);
  lua_getfield(state, table, name);
  lua_pushstring(state, project_dir);
  lua_pushinteger(state, path_count);
  lua_pushcclosure(state, project_file_call, 3);
  lua_setfield(state, table, name);
}

static void install_project_files(lua_State *state, const char *project_dir) {
  if (!project_dir || !*project_dir) return;
  lua_getglobal(state, "io");
  wrap_project_file(state, -1, "open", project_dir, 1);
  wrap_project_file(state, -1, "input", project_dir, 1);
  wrap_project_file(state, -1, "output", project_dir, 1);
  wrap_project_file(state, -1, "lines", project_dir, 1);
  lua_pop(state, 1);
  lua_getglobal(state, "os");
  wrap_project_file(state, -1, "remove", project_dir, 1);
  wrap_project_file(state, -1, "rename", project_dir, 2);
  lua_pop(state, 1);
  lua_pushglobaltable(state);
  wrap_project_file(state, -1, "loadfile", project_dir, 1);
  wrap_project_file(state, -1, "dofile", project_dir, 1);
  lua_pop(state, 1);
}

static void set_project_path(lua_State *state, const char *project_dir) {
  if (!project_dir || !*project_dir) return;
  lua_getglobal(state, "package");
  lua_getfield(state, -1, "path");
  const char *old_path = lua_tostring(state, -1);
  lua_pushfstring(state,
                  "%s/?.lua;%s/?/init.lua;%s/src/?.lua;%s/src/?/init.lua;%s",
                  project_dir, project_dir, project_dir, project_dir,
                  old_path ? old_path : "");
  lua_setfield(state, -3, "path");
  lua_pop(state, 2);
}

const char *qfli_lua_version(void) { return LUA_RELEASE; }

QfliLuaCancelToken *qfli_lua_token_new(void) {
  QfliLuaCancelToken *token = (QfliLuaCancelToken *)malloc(sizeof(*token));
  if (token) {
#if defined(_MSC_VER)
    token->cancelled = 0;
#else
    atomic_init(&token->cancelled, 0);
#endif
  }
  return token;
}

void qfli_lua_token_cancel(QfliLuaCancelToken *token) {
  if (!token) return;
#if defined(_MSC_VER)
  InterlockedExchange(&token->cancelled, 1);
#else
  atomic_store(&token->cancelled, 1);
#endif
}

void qfli_lua_token_free(QfliLuaCancelToken *token) { free(token); }

QfliLuaResult *qfli_lua_run(const char *file, const char *project_dir,
                            int timeout_ms) {
  return qfli_lua_run_with_token(file, project_dir, timeout_ms, NULL);
}

QfliLuaResult *qfli_lua_run_with_token(const char *file,
                                       const char *project_dir, int timeout_ms,
                                       QfliLuaCancelToken *token) {
  QfliLuaResult *result = new_result();
  if (!result) return NULL;
  if (!file || !*file) {
    set_error(result, "Lua entry file is missing");
    return result;
  }
  if (token_is_cancelled(token)) {
    set_error(result, "Lua execution cancelled");
    result->status = 130;
    return result;
  }
  lua_State *state = luaL_newstate();
  if (!state) {
    set_error(result, "Cannot create Lua state");
    return result;
  }

  OutputBuffer output = {0};
  OutputBuffer errors = {0};
  RunContext context = {&output, &errors, monotonic_ms(),
                        timeout_ms > 0 ? timeout_ms : 10000, 0, 0, token, 0, 0};
  *(RunContext **)lua_getextraspace(state) = &context;
  lua_setwarnf(state, capture_warning, &context);
  luaL_openlibs(state);
  set_project_path(state, project_dir);
  install_project_files(state, project_dir);
  lua_pushlightuserdata(state, &context);
  lua_pushcclosure(state, capture_print, 1);
  lua_setglobal(state, "print");
  install_io_capture(state, &context);
  lua_getglobal(state, "os");
  lua_pushlightuserdata(state, &context);
  lua_pushcclosure(state, capture_exit, 1);
  lua_setfield(state, -2, "exit");
  lua_pop(state, 1);
  lua_createtable(state, 1, 0);
  lua_pushstring(state, file);
  lua_rawseti(state, -2, 0);
  lua_setglobal(state, "arg");
  lua_sethook(state, execution_hook, LUA_MASKCOUNT, 10000);

  push_project_file(state, file, project_dir);
  int status = luaL_loadfilex(state, lua_tostring(state, -1), "bt");
  if (status == LUA_OK) status = lua_pcall(state, 0, LUA_MULTRET, 0);
  if (status != LUA_OK) {
    size_t message_length;
    const char *message = lua_tolstring(state, -1, &message_length);
    if (context.exit_requested && message &&
        message_length == strlen(EXIT_SENTINEL) &&
        memcmp(message, EXIT_SENTINEL, message_length) == 0)
      result->status = context.exit_code;
    else {
      set_lua_error(result, state);
      if (token_is_cancelled(token)) result->status = 130;
    }
  }
  lua_close(state);
  if (context.exit_requested) result->status = context.exit_code;
  if (errors.data) {
    if (result->status != 0 && result->error_length > 0) {
      size_t diagnostic_length = result->error_length;
      if (diagnostic_length >= MAX_OUTPUT) diagnostic_length = MAX_OUTPUT - 1;
      /* Keep the failure diagnostic even when captured stderr fills the limit. */
      if (errors.length > MAX_OUTPUT - diagnostic_length - 1) {
        errors.length = MAX_OUTPUT - diagnostic_length - 1;
        errors.data[errors.length] = '\0';
      }
      append_output(&errors, result->error, diagnostic_length);
      append_output(&errors, "\n", 1);
    }
    free(result->error);
    result->error = errors.data;
    result->error_length = errors.length;
  }
  if (output.data) {
    free(result->output);
    result->output = output.data;
    result->output_length = output.length;
  }
  return result;
}

QfliLuaResult *qfli_lua_check(const char *file) {
  QfliLuaResult *result = new_result();
  if (!result) return NULL;
  if (!file || !*file) {
    set_error(result, "Lua source file is missing");
    return result;
  }
  lua_State *state = luaL_newstate();
  if (!state) {
    set_error(result, "Cannot create Lua state");
    return result;
  }
  int status = luaL_loadfilex(state, file, "t");
  if (status != LUA_OK) set_lua_error(result, state);
  lua_close(state);
  return result;
}

QfliLuaResult *qfli_lua_compile(const char *file, const char *output_file) {
  QfliLuaResult *result = new_result();
  if (!result) return NULL;
  if (!file || !*file || !output_file || !*output_file) {
    set_error(result, "Lua source or bytecode output file is missing");
    return result;
  }
  lua_State *state = luaL_newstate();
  if (!state) {
    set_error(result, "Cannot create Lua state");
    return result;
  }
  int status = luaL_loadfilex(state, file, "t");
  if (status != LUA_OK) {
    set_lua_error(result, state);
  } else {
    FILE *output = output_file ? fopen(output_file, "wb") : NULL;
    if (!output) {
      set_error(result, "Cannot open Lua bytecode output file");
    } else {
      int dump_status = lua_dump(state, dump_writer, output, 0);
      if (fclose(output) != 0 || dump_status != 0)
        set_error(result, "Cannot write Lua bytecode output file");
    }
  }
  lua_close(state);
  return result;
}

void qfli_lua_free(QfliLuaResult *result) {
  if (!result) return;
  free(result->output);
  free(result->error);
  free(result);
}
