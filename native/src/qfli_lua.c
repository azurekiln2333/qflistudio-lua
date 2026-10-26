#if !defined(_WIN32)
#define _POSIX_C_SOURCE 200809L
#define _XOPEN_SOURCE 700
#endif

#include "qfli_lua.h"

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#if !defined(_WIN32)
#include <fcntl.h>
#include <unistd.h>
#endif

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
  /* A non-positive limit means "no limit": the upstream interpreter has no
     timer either, so an interactive terminal run is stopped by cancellation. */
  if (context->timeout_ms <= 0) return;
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

/* Never rely on a process-global /tmp or TEMP inside a mobile sandbox. Names
   are exclusive-created in this VM's project. os.tmpname retains the standard
   precreated file; io.tmpfile owns its path until close/GC/state shutdown. */
static FILE *project_temp_file(lua_State *state) {
  const char *root = lua_tostring(state, lua_upvalueindex(1));
  if (!root || !*root) {
    errno = ENOENT;
    return NULL;
  }
  for (int attempt = 0; attempt < 128; attempt++) {
    unsigned long process;
    unsigned long sequence;
#if defined(_WIN32)
    static volatile LONG serial = 0;
    sequence = (unsigned long)InterlockedIncrement(&serial);
    process = (unsigned long)GetCurrentProcessId();
#else
    static atomic_ulong serial = 0;
    sequence = atomic_fetch_add(&serial, 1) + 1;
    process = (unsigned long)getpid();
#endif
    char name[128];
    snprintf(name, sizeof(name), ".qfli_tmp_%lu_%.0f_%lu", process,
             monotonic_ms(), sequence);
    lua_pushfstring(state, "%s/%s", root, name);
    const char *path = lua_tostring(state, -1);
    FILE *file;
#if defined(_WIN32)
    file = qfli_utf8_create_exclusive(path);
#else
    int descriptor = open(path, O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC, 0600);
    file = descriptor < 0 ? NULL : fdopen(descriptor, "w+b");
    if (descriptor >= 0 && !file) {
      int saved_errno = errno;
      close(descriptor);
      remove(path);
      errno = saved_errno;
    }
#endif
    if (file) return file; /* path stays on Lua's stack */
    int saved_errno = errno;
    lua_pop(state, 1);
    errno = saved_errno;
    if (saved_errno != EEXIST) return NULL;
  }
  errno = EEXIST;
  return NULL;
}

static int project_tmpname(lua_State *state) {
  FILE *file = project_temp_file(state);
  if (!file)
    return luaL_error(state, "Cannot create a temporary file in the Lua project: %s",
                      strerror(errno));
  if (fclose(file) != 0) {
    int saved_errno = errno;
    remove(lua_tostring(state, -1));
    return luaL_error(state, "Cannot close a temporary file in the Lua project: %s",
                      strerror(saved_errno));
  }
  return 1;
}

static int close_project_temp(lua_State *state) {
  luaL_Stream *stream = luaL_checkudata(state, 1, LUA_FILEHANDLE);
  int okay = fclose(stream->f) == 0;
  int saved_errno = errno;
  lua_getiuservalue(state, 1, 1);
  const char *path = lua_tostring(state, -1);
  if (path && remove(path) != 0 && errno != ENOENT && okay) {
    okay = 0;
    saved_errno = errno;
  }
  lua_pop(state, 1);
  errno = saved_errno;
  return luaL_fileresult(state, okay, NULL);
}

static int project_tmpfile(lua_State *state) {
  luaL_Stream *stream = lua_newuserdatauv(state, sizeof(*stream), 1);
  stream->f = NULL;
  stream->closef = NULL;
  luaL_setmetatable(state, LUA_FILEHANDLE);
  FILE *file = project_temp_file(state);
  if (!file) return luaL_fileresult(state, 0, "Lua project temporary file");
  lua_setiuservalue(state, -2, 1); /* retain absolute path without C allocation */
  stream->f = file;
  stream->closef = close_project_temp;
  return 1;
}

static void install_project_temps(lua_State *state, const char *project_dir) {
  char *root = NULL;
  if (project_dir && *project_dir) {
#if defined(_WIN32)
    root = qfli_utf8_absolute_path(project_dir);
#else
    root = realpath(project_dir, NULL);
#endif
  }
  lua_getglobal(state, "os");
  lua_pushstring(state, root ? root : "");
  lua_pushcclosure(state, project_tmpname, 1);
  lua_setfield(state, -2, "tmpname");
  lua_pop(state, 1);
  lua_getglobal(state, "io");
  lua_pushstring(state, root ? root : "");
  lua_pushcclosure(state, project_tmpfile, 1);
  lua_setfield(state, -2, "tmpfile");
  lua_pop(state, 1);
  free(root);
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

static int close_run_input(lua_State *state) {
  luaL_Stream *stream = (luaL_Stream *)luaL_checkudata(state, 1, LUA_FILEHANDLE);
  return luaL_fileresult(state, fclose(stream->f) == 0, NULL);
}

static int install_run_input(lua_State *state, const char *project_dir,
                             QfliLuaResult *result) {
  push_project_file(state, "input.txt", project_dir);
  const char *path = lua_tostring(state, -1);
  int regular;
#if defined(_WIN32)
  regular = qfli_utf8_regular_file(path);
#else
  struct stat info;
  regular = stat(path, &info) == 0 ? (S_ISREG(info.st_mode) ? 1 : 0) : -1;
#endif
  if (regular != 1 && !(regular < 0 && errno == ENOENT)) {
    set_error(result, regular == 0
                          ? "Lua project input.txt must be a regular file"
                          : "Cannot inspect Lua project input.txt");
    lua_pop(state, 1);
    return 0;
  }
  int missing = regular < 0;
  lua_getglobal(state, "io");
  luaL_Stream *stream = (luaL_Stream *)lua_newuserdatauv(state, sizeof(*stream), 0);
  stream->f = NULL;
  stream->closef = NULL;
  luaL_setmetatable(state, LUA_FILEHANDLE);
  FILE *input;
  if (missing) {
#if defined(_WIN32)
    input = fopen("NUL", "rb");
#else
    input = fopen("/dev/null", "rb");
#endif
  } else {
    input = fopen(path, "rb");
  }
  if (!input) {
    set_error(result, "Cannot open Lua project input stream");
    lua_pop(state, 3);
    return 0;
  }

  // This state owns its input descriptor; host stdin remains untouched.
  stream->f = input;
  stream->closef = close_run_input;
  lua_remove(state, -3);
  lua_pushvalue(state, -1);
  lua_setfield(state, -3, "stdin");
  lua_getfield(state, -2, "input");
  lua_pushvalue(state, -2);
  lua_call(state, 1, 0);
  lua_pop(state, 2);
  return 1;
}

const char *qfli_lua_version(void) { return LUA_RELEASE; }

const char *qfli_lua_copyright(void) { return LUA_COPYRIGHT; }

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
  return qfli_lua_run_with_argv(file, project_dir, timeout_ms, NULL, 0, 0,
                                 token);
}

/* Builds the global `arg` table exactly like upstream `createargtable()`. */
static void install_arg_table(lua_State *state, const char *file,
                              const char *const *argv, int argv_count,
                              int script_index) {
  if (!argv || argv_count <= 0) {
    lua_createtable(state, 1, 0);
    lua_pushstring(state, file);
    lua_rawseti(state, -2, 0);
    lua_setglobal(state, "arg");
    return;
  }
  int positive = argv_count - (script_index + 1);
  if (positive < 0) positive = 0;
  lua_createtable(state, positive, script_index + 1);
  for (int index = 0; index < argv_count; index++) {
    lua_pushstring(state, argv[index]);
    lua_rawseti(state, -2, index - script_index);
  }
  lua_setglobal(state, "arg");
}

QfliLuaResult *qfli_lua_run_with_argv(const char *file,
                                      const char *project_dir, int timeout_ms,
                                      const char *const *argv, int argv_count,
                                      int script_index,
                                      QfliLuaCancelToken *token) {
  QfliLuaResult *result = new_result();
  if (!result) return NULL;
  if (!file || !*file) {
    set_error(result, "Lua entry file is missing");
    return result;
  }
  if (argv_count < 0 || argv_count > INT_MAX - 2 ||
      (argv_count > 0 && (!argv || script_index < 0 || script_index >= argv_count))) {
    set_error(result, "Invalid Lua command line");
    return result;
  }
  for (int index = 0; index < argv_count; index++) {
    if (!argv[index]) {
      set_error(result, "Invalid Lua command-line argument");
      return result;
    }
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
  if (!lua_checkstack(state, argv_count + 2)) {
    set_error(result, "Too many Lua command-line arguments");
    lua_close(state);
    return result;
  }

  OutputBuffer output = {0};
  OutputBuffer errors = {0};
  /* timeout_ms > 0 is a real limit; 0 keeps the historical 10 s default and a
     negative value disables the time limit entirely. */
  int effective_timeout = timeout_ms > 0 ? timeout_ms : (timeout_ms < 0 ? 0 : 10000);
  RunContext context = {&output, &errors, monotonic_ms(), effective_timeout,
                        0, 0, token, 0, 0};
  *(RunContext **)lua_getextraspace(state) = &context;
  lua_setwarnf(state, capture_warning, &context);
  luaL_openlibs(state);
  set_project_path(state, project_dir);
  install_project_files(state, project_dir);
  install_project_temps(state, project_dir);
  if (!install_run_input(state, project_dir, result)) {
    lua_close(state);
    return result;
  }
  lua_pushlightuserdata(state, &context);
  lua_pushcclosure(state, capture_print, 1);
  lua_setglobal(state, "print");
  install_io_capture(state, &context);
  lua_getglobal(state, "os");
  lua_pushlightuserdata(state, &context);
  lua_pushcclosure(state, capture_exit, 1);
  lua_setfield(state, -2, "exit");
  lua_pop(state, 1);
  install_arg_table(state, file, argv, argv_count, script_index);
  lua_sethook(state, execution_hook, LUA_MASKCOUNT, 10000);

  int vararg_count = 0;
  if (argv && argv_count > 0) {
    vararg_count = argv_count - (script_index + 1);
    if (vararg_count < 0) vararg_count = 0;
  }

  push_project_file(state, file, project_dir);
  int status = luaL_loadfilex(state, lua_tostring(state, -1), "bt");
  if (status == LUA_OK) {
    /* Upstream passes the script arguments to the chunk as varargs. */
    if (argv && argv_count > 0) {
      for (int index = script_index + 1; index < argv_count; index++)
        lua_pushstring(state, argv[index]);
    }
    status = lua_pcall(state, vararg_count, LUA_MULTRET, 0);
  }
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

QfliLuaResult *qfli_lua_check_source(const char *source, size_t length,
                                     const char *chunk_name) {
  QfliLuaResult *result = new_result();
  if (!result) return NULL;
  if (!source) {
    set_error(result, "Lua source is missing");
    return result;
  }
  lua_State *state = luaL_newstate();
  if (!state) {
    set_error(result, "Cannot create Lua state");
    return result;
  }
  int status = luaL_loadbufferx(state, source, length,
                                chunk_name ? chunk_name : "@editor.lua", "t");
  if (status != LUA_OK) {
    set_lua_error(result, state);
    result->status = status;
  }
  lua_close(state);
  return result;
}

static QfliLuaResult *compile_file(const char *file, const char *output_file,
                                  int strip, const char *mode) {
  QfliLuaResult *result = new_result();
  if (!result) return NULL;
  if (!file || !*file || (output_file && !*output_file)) {
    set_error(result, "Lua source or bytecode output file is missing");
    return result;
  }
  lua_State *state = luaL_newstate();
  if (!state) {
    set_error(result, "Cannot create Lua state");
    return result;
  }
  int status = luaL_loadfilex(state, file, mode);
  if (status != LUA_OK) {
    set_lua_error(result, state);
  } else if (output_file) {
    FILE *output = fopen(output_file, "wb");
    if (!output) {
      set_error(result, "Cannot open Lua bytecode output file");
    } else {
      int dump_status = lua_dump(state, dump_writer, output, strip != 0);
      if (fclose(output) != 0 || dump_status != 0)
        set_error(result, "Cannot write Lua bytecode output file");
    }
  }
  lua_close(state);
  return result;
}

QfliLuaResult *qfli_lua_compile(const char *file, const char *output_file) {
  if (!output_file) {
    QfliLuaResult *result = new_result();
    if (result) set_error(result, "Lua source or bytecode output file is missing");
    return result;
  }
  return compile_file(file, output_file, 0, "t");
}

QfliLuaResult *qfli_lua_compile_ex(const char *file, const char *output_file,
                                   int strip) {
  return compile_file(file, output_file, strip, "bt");
}

void qfli_lua_free(QfliLuaResult *result) {
  if (!result) return;
  free(result->output);
  free(result->error);
  free(result);
}

/* All VM access belongs to one worker. UI requests touch only atomic controls. */
struct QfliLuaDebugSession {
  RunContext context; /* first member: extraspace also serves existing capture */
  OutputBuffer output;
  OutputBuffer errors;
  lua_State *main_state;
  lua_State *thread;
  QfliLuaCancelToken *token;
#if defined(_MSC_VER)
  volatile LONG pause_requested;
#else
  atomic_int pause_requested;
#endif
  char **breakpoint_paths;
  int *breakpoint_lines;
  int breakpoint_count;
  int state;
  int status;
  int action;
  int paused_depth;
  int target_depth;
  int pause_deferred;
  double remaining_ms;
  char number[96];
};

static int debug_take_pause(QfliLuaDebugSession *session) {
#if defined(_MSC_VER)
  return InterlockedExchange(&session->pause_requested, 0) != 0;
#else
  return atomic_exchange(&session->pause_requested, 0);
#endif
}

static int debug_depth(lua_State *state) {
  lua_Debug frame;
  int depth = 0;
  while (lua_getstack(state, depth, &frame)) depth++;
  return depth;
}

static int debug_same_path(const char *left, const char *right) {
  while (*left && *right) {
    unsigned char a = (unsigned char)*left++, b = (unsigned char)*right++;
    if (a == '\\') a = '/';
    if (b == '\\') b = '/';
#if defined(_WIN32)
    if (a >= 'A' && a <= 'Z') a += 'a' - 'A';
    if (b >= 'A' && b <= 'Z') b += 'a' - 'A';
#endif
    if (a != b) return 0;
  }
  return *left == *right;
}

static void debug_hook(lua_State *state, lua_Debug *frame) {
  RunContext *context = *(RunContext **)lua_getextraspace(state);
  QfliLuaDebugSession *session = (QfliLuaDebugSession *)context;
  if (token_is_cancelled(session->token))
    luaL_error(state, "Lua execution cancelled");
  if (session->remaining_ms > 0 &&
      monotonic_ms() - context->started_ms >= session->remaining_ms)
    luaL_error(state, "Lua execution timed out");
  int pause = debug_take_pause(session);
  int depth = 0;
  if (frame->event == LUA_HOOKLINE) {
    depth = debug_depth(state);
    lua_getinfo(state, "S", frame);
    for (int index = 0; index < session->breakpoint_count; index++) {
      if (frame->source && frame->source[0] == '@' &&
          frame->currentline == session->breakpoint_lines[index] &&
          debug_same_path(frame->source + 1, session->breakpoint_paths[index])) {
        pause = 1;
        break;
      }
    }
    if (session->action == 1 ||
        (session->action == 2 && depth <= session->target_depth) ||
        (session->action == 3 && depth < session->target_depth))
      pause = 1;
  }
  if (pause && lua_isyieldable(state)) {
    session->pause_deferred = 0;
    session->paused_depth = depth ? depth : debug_depth(state);
    session->state = 1;
    /* Lua skips the yielded hook once on resume; the instruction runs once. */
    lua_yield(state, 0);
  } else if (pause) {
    /* A C callback may not yield. Keep the request until Lua is resumable. */
    if (!session->pause_deferred) {
      const char *warning =
          "Lua debugger: stop deferred across a non-yieldable native callback "
          "(including require module initialization)\n";
      append_output(&session->errors, warning, strlen(warning));
      session->pause_deferred = 1;
    }
    qfli_lua_debug_pause(session);
  }
}

static int debug_unsupported_coroutine(lua_State *state) {
  return luaL_error(state,
      "User coroutines are unavailable in the source debugger; use normal Run");
}

static int debug_unsupported_hook(lua_State *state) {
  return luaL_error(state,
      "Replacing debugger hooks or interactive debug input is unavailable");
}

static void debug_error(QfliLuaDebugSession *session, const char *text,
                         size_t length) {
  if (length >= MAX_OUTPUT) length = MAX_OUTPUT - 1;
  if (session->errors.length > MAX_OUTPUT - length - 1) {
    session->errors.length = MAX_OUTPUT - length - 1;
    if (session->errors.data) session->errors.data[session->errors.length] = '\0';
  }
  append_output(&session->errors, text, length);
  append_output(&session->errors, "\n", 1);
  session->status = 1;
}

static void debug_close_vm(QfliLuaDebugSession *session) {
  if (session->thread) {
    /* lua_close(main) does not close a suspended coroutine's <close> locals.
       Unwind it explicitly, without yielding/cancellation hooks in finalizers.
       Keep any existing error alive while close callbacks may trigger GC. */
    lua_State *thread = session->thread;
    int old_status = lua_status(thread);
    const char *old_error = NULL;
    size_t old_length = 0;
    if (old_status != LUA_OK && old_status != LUA_YIELD && lua_gettop(thread)) {
      lua_pushvalue(thread, -1);
      lua_xmove(thread, session->main_state, 1);
      old_error = lua_tolstring(session->main_state, -1, &old_length);
    }
    lua_sethook(thread, NULL, 0, 0);
    int close_status = lua_closethread(thread, session->main_state);
    if (close_status != LUA_OK) {
      size_t length = 0;
      const char *error = lua_tolstring(thread, -1, &length);
      if (error && (!old_error || length != old_length ||
                    memcmp(error, old_error, length) != 0)) {
        int prior_status = session->status;
        debug_error(session, error, length);
        if (prior_status != 0) session->status = prior_status;
      }
    }
  }
  if (session->main_state) lua_close(session->main_state);
  if (session->context.exit_requested)
    session->status = session->context.exit_code;
  session->main_state = NULL;
  session->thread = NULL;
  session->state = 2;
}

QfliLuaDebugSession *qfli_lua_debug_new(const char *file,
                                       const char *project_dir, int timeout_ms) {
  QfliLuaDebugSession *session = calloc(1, sizeof(*session));
  if (!session) return NULL;
#if !defined(_MSC_VER)
  atomic_init(&session->pause_requested, 0);
#endif
  session->token = qfli_lua_token_new();
  session->remaining_ms = timeout_ms > 0 ? timeout_ms : 10000;
  session->context.output = &session->output;
  session->context.error = &session->errors;
  session->context.token = session->token;
  if (!session->token || !file || !*file) {
    debug_error(session, "Cannot create Lua debug session", 31);
    debug_close_vm(session);
    return session;
  }
  lua_State *state = session->main_state = luaL_newstate();
  if (!state) {
    debug_error(session, "Cannot create Lua state", 23);
    debug_close_vm(session);
    return session;
  }
  *(RunContext **)lua_getextraspace(state) = &session->context;
  lua_setwarnf(state, capture_warning, &session->context);
  luaL_openlibs(state);
  set_project_path(state, project_dir);
  install_project_files(state, project_dir);
  install_project_temps(state, project_dir);
  QfliLuaResult *setup = new_result();
  if (!setup || !install_run_input(state, project_dir, setup)) {
    const char *message = setup ? setup->error : "Out of memory";
    debug_error(session, message, strlen(message));
    qfli_lua_free(setup);
    debug_close_vm(session);
    return session;
  }
  qfli_lua_free(setup);
  lua_pushlightuserdata(state, &session->context);
  lua_pushcclosure(state, capture_print, 1);
  lua_setglobal(state, "print");
  install_io_capture(state, &session->context);
  lua_getglobal(state, "os");
  lua_pushlightuserdata(state, &session->context);
  lua_pushcclosure(state, capture_exit, 1);
  lua_setfield(state, -2, "exit");
  lua_pop(state, 1);
  lua_getglobal(state, "coroutine");
  const char *operations[] = {"create", "resume", "wrap", "yield"};
  for (int index = 0; index < 4; index++) {
    lua_pushcfunction(state, debug_unsupported_coroutine);
    lua_setfield(state, -2, operations[index]);
  }
  lua_pop(state, 1);
  lua_getglobal(state, "debug");
  lua_pushcfunction(state, debug_unsupported_hook);
  lua_setfield(state, -2, "sethook");
  lua_pushcfunction(state, debug_unsupported_hook);
  lua_setfield(state, -2, "debug");
  lua_pop(state, 1);
  install_arg_table(state, file, NULL, 0, 0);
  session->thread = lua_newthread(state); /* pinned on the main state's stack */
  lua_sethook(session->thread, debug_hook, LUA_MASKLINE | LUA_MASKCOUNT, 1000);
  int status = luaL_loadfilex(session->thread, file, "t");
  if (status != LUA_OK) {
    size_t length = 0;
    const char *message = lua_tolstring(session->thread, -1, &length);
    debug_error(session, message ? message : "Lua load failed",
                 message ? length : 15);
    debug_close_vm(session);
  }
  return session;
}

int qfli_lua_debug_resume(QfliLuaDebugSession *session, int action) {
  if (!session || session->state == 2) return 2;
  if (action < 0 || action > 3) return session->state;
  if (token_is_cancelled(session->token)) {
    debug_error(session, "Lua execution cancelled", 23);
    session->status = 130;
    debug_close_vm(session);
    return 2;
  }
  session->action = action;
  session->target_depth = session->paused_depth;
  session->state = 0;
  session->context.started_ms = monotonic_ms();
  int results = 0;
  int status = lua_resume(session->thread, NULL, 0, &results);
  double elapsed = monotonic_ms() - session->context.started_ms;
  session->remaining_ms -= elapsed;
  if (session->remaining_ms <= 0 && status == LUA_YIELD) {
    debug_error(session, "Lua execution timed out", 23);
    debug_close_vm(session);
  } else if (status == LUA_YIELD && session->state == 1) {
    return 1;
  } else {
    if (status != LUA_OK) {
      size_t length = 0;
      const char *message = lua_tolstring(session->thread, -1, &length);
      if (!session->context.exit_requested) {
        debug_error(session, message ? message : "Lua execution failed",
                     message ? length : 20);
      }
    }
    if (session->context.exit_requested)
      session->status = session->context.exit_code;
    else if (token_is_cancelled(session->token))
      session->status = 130;
    debug_close_vm(session);
  }
  return session->state;
}

void qfli_lua_debug_pause(QfliLuaDebugSession *session) {
  if (!session) return;
#if defined(_MSC_VER)
  InterlockedExchange(&session->pause_requested, 1);
#else
  atomic_store(&session->pause_requested, 1);
#endif
}

void qfli_lua_debug_stop(QfliLuaDebugSession *session) {
  if (session) qfli_lua_token_cancel(session->token);
}

static void debug_clear_breakpoints(QfliLuaDebugSession *session) {
  for (int index = 0; index < session->breakpoint_count; index++)
    free(session->breakpoint_paths[index]);
  free(session->breakpoint_paths);
  free(session->breakpoint_lines);
  session->breakpoint_paths = NULL;
  session->breakpoint_lines = NULL;
  session->breakpoint_count = 0;
}

int qfli_lua_debug_set_breakpoints(QfliLuaDebugSession *session,
    const char *const *paths, const int *lines, int count) {
  if (!session || count < 0 || count > 256 ||
      (count > 0 && (!paths || !lines))) return 0;
  for (int index = 0; index < count; index++) {
    if (!paths[index] || !*paths[index] || lines[index] < 1) return 0;
  }
  char **new_paths = count ? calloc((size_t)count, sizeof(char *)) : NULL;
  int *new_lines = count ? calloc((size_t)count, sizeof(int)) : NULL;
  if (count && (!new_paths || !new_lines)) {
    free(new_paths);
    free(new_lines);
    return 0;
  }
  for (int index = 0; index < count; index++) {
    new_paths[index] = copy_text(paths[index]);
    if (!new_paths[index]) {
      for (int previous = 0; previous < index; previous++) free(new_paths[previous]);
      free(new_paths);
      free(new_lines);
      return 0;
    }
    new_lines[index] = lines[index];
  }
  debug_clear_breakpoints(session);
  session->breakpoint_paths = new_paths;
  session->breakpoint_lines = new_lines;
  session->breakpoint_count = count;
  return 1;
}

int qfli_lua_debug_state(QfliLuaDebugSession *session) {
  return session ? session->state : 2;
}

QfliLuaResult *qfli_lua_debug_output(QfliLuaDebugSession *session) {
  if (!session) return NULL;
  QfliLuaResult *result = new_result();
  if (!result) return NULL;
  char *output = copy_bytes(session->output.data ? session->output.data : "",
                             session->output.length);
  char *errors = copy_bytes(session->errors.data ? session->errors.data : "",
                             session->errors.length);
  if (!output || !errors) {
    free(output);
    free(errors);
    qfli_lua_free(result);
    return NULL;
  }
  free(result->output);
  free(result->error);
  result->output = output;
  result->error = errors;
  result->output_length = session->output.length;
  result->error_length = session->errors.length;
  result->status = session->status;
  return result;
}

int qfli_lua_debug_frame(QfliLuaDebugSession *session, int index,
                         QfliLuaDebugFrame *frame) {
  if (!session || session->state != 1 || !frame || index < 0 || index >= 64)
    return 0;
  lua_Debug info;
  if (!lua_getstack(session->thread, index, &info) ||
      !lua_getinfo(session->thread, "nSl", &info)) return 0;
  frame->source = info.source ? info.source : "";
  frame->name = info.name ? info.name : (info.what ? info.what : "?");
  frame->line = info.currentline;
  return 1;
}

int qfli_lua_debug_local(QfliLuaDebugSession *session, int frame, int index,
                         QfliLuaDebugValue *value) {
  if (!session || session->state != 1 || !value || frame < 0 || frame >= 64 ||
      index < 1 || index > 128) return 0;
  lua_State *state = session->thread;
  lua_Debug info;
  if (!lua_getstack(state, frame, &info)) return 0;
  const char *name = lua_getlocal(state, &info, index);
  if (!name) return 0;
  value->name = name;
  int type = lua_type(state, -1);
  value->type = lua_typename(state, type);
  if (type == LUA_TSTRING) {
    value->value = lua_tolstring(state, -1, &value->length);
  } else {
    const char *text = value->type;
    if (type == LUA_TNUMBER) {
      if (lua_isinteger(state, -1))
        snprintf(session->number, sizeof(session->number), LUA_INTEGER_FMT,
                   (LUAI_UACINT)lua_tointeger(state, -1));
      else
        snprintf(session->number, sizeof(session->number), "%.17g",
                   (double)lua_tonumber(state, -1));
      text = session->number;
    } else if (type == LUA_TBOOLEAN) {
      text = lua_toboolean(state, -1) ? "true" : "false";
    }
    value->value = text;
    value->length = strlen(text);
  }
  lua_pop(state, 1);
  return 1;
}

void qfli_lua_debug_free(QfliLuaDebugSession *session) {
  if (!session) return;
  debug_close_vm(session);
  debug_clear_breakpoints(session);
  qfli_lua_token_free(session->token);
  free(session->output.data);
  free(session->errors.data);
  free(session);
}
