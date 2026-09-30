#include "qfli_lua.h"

#include <stdio.h>
#include <string.h>

#if defined(_WIN32)
#include <direct.h>
#else
#include <sys/stat.h>
#include <unistd.h>
#endif

static int write_source(const char *path, const char *source) {
  FILE *file = fopen(path, "wb");
  if (!file) return 0;
  int okay = fputs(source, file) >= 0;
  return fclose(file) == 0 && okay;
}

int main(void) {
  const char *source = "qfli_lua_test.lua";
  const char *bytecode = "qfli_lua_test.luac";
  if (!write_source(source, "local value = { answer = 42 }\nprint(value.answer)\n"))
    return 1;

  QfliLuaResult *check = qfli_lua_check(source);
  QfliLuaResult *compile = qfli_lua_compile(source, bytecode);
  QfliLuaResult *run_source = qfli_lua_run(source, ".", 2000);
  QfliLuaResult *run_bytecode = qfli_lua_run(bytecode, ".", 2000);
  int okay = check && compile && run_source && run_bytecode &&
             check->status == 0 && compile->status == 0 &&
             run_source->status == 0 && run_bytecode->status == 0 &&
             strcmp(run_source->output, "42\n") == 0 &&
             strcmp(run_bytecode->output, "42\n") == 0;
  if (!okay) fprintf(stderr, "Lua compile/run test failed\n");
  qfli_lua_free(check);
  qfli_lua_free(compile);
  qfli_lua_free(run_source);
  qfli_lua_free(run_bytecode);

  okay &= write_source(source,
                       "io.write('out')\n"
                       "io.stdout:write('put\\n')\n"
                       "io.stderr:write('warning\\n')\n");
  QfliLuaResult *streams = qfli_lua_run(source, ".", 2000);
  okay &= streams && streams->status == 0 &&
          strcmp(streams->output, "output\n") == 0 &&
          strcmp(streams->error, "warning\n") == 0;
  qfli_lua_free(streams);

  okay &= write_source(source,
                       "io.write('left\\0right', string.char(255))\n"
                       "io.stderr:write('err\\0tail', string.char(254))\n"
                       "error('\\0failure', 0)\n");
  const char expected_output[] = "left\0right\xff";
  const char expected_error[] = "err\0tail\xfe\0failure\n";
  QfliLuaResult *binary_output = qfli_lua_run(source, ".", 2000);
  okay &= binary_output && binary_output->status != 0 &&
          binary_output->output_length == sizeof(expected_output) - 1 &&
          binary_output->error_length == sizeof(expected_error) - 1 &&
          memcmp(binary_output->output, expected_output,
                 sizeof(expected_output) - 1) == 0 &&
          memcmp(binary_output->error, expected_error,
                 sizeof(expected_error) - 1) == 0;
  qfli_lua_free(binary_output);

  okay &= write_source(source,
                       "warn('ignored by default')\n"
                       "warn('@on')\n"
                       "warn('part', 'tail')\n"
                       "warn('@off')\n"
                       "warn('ignored again')\n");
  QfliLuaResult *warning = qfli_lua_run(source, ".", 2000);
  okay &= warning && warning->status == 0 &&
          strcmp(warning->error, "Lua warning: parttail\n") == 0;
  qfli_lua_free(warning);

  okay &= write_source(source,
                       "tostring = function() error('unexpected call') end\n"
                       "local value = setmetatable({}, {\n"
                       "  __tostring = function() return 'metamethod' end\n"
                       "})\n"
                       "print(value, 42)\n");
  QfliLuaResult *custom_tostring = qfli_lua_run(source, ".", 2000);
  okay &= custom_tostring && custom_tostring->status == 0 &&
          strcmp(custom_tostring->output, "metamethod\t42\n") == 0;
  qfli_lua_free(custom_tostring);

  okay &= write_source(source,
                       "local file = assert(io.open('qfli_lua_io.txt', 'w'))\n"
                       "io.output(file)\n"
                       "assert(io.write(1.0, '|', 42) == file)\n"
                       "file:write('!')\n"
                       "file:close()\n"
                       "local input = assert(io.open('qfli_lua_io.txt', 'r'))\n"
                       "print(input:read('a'))\n"
                       "input:close()\n"
                       "io.output(io.stderr)\n"
                       "io.write('redirected\\n')\n"
                       "local out, err = io.stdout, io.stderr\n"
                       "io.stdout, io.stderr = nil, nil\n"
                       "out:write('retained\\n')\n"
                       "err:write('retained error\\n')\n");
  QfliLuaResult *redirected = qfli_lua_run(source, ".", 2000);
  okay &= redirected && redirected->status == 0 &&
          strcmp(redirected->output, "1|42!\nretained\n") == 0 &&
          strcmp(redirected->error, "redirected\nretained error\n") == 0;
  qfli_lua_free(redirected);
  remove("qfli_lua_io.txt");

  okay &= write_source(source,
                       "collectgarbage('stop')\n"
                       "print('before')\n"
                       "retained = setmetatable({}, {\n"
                       "  __gc = function() print(string.rep('x', 4096)) end\n"
                       "})\n");
  QfliLuaResult *finalizer = qfli_lua_run(source, ".", 2000);
  okay &= finalizer && finalizer->status == 0 &&
          strlen(finalizer->output) == 4104 &&
          strncmp(finalizer->output, "before\nxxx", 10) == 0 &&
          finalizer->output[4103] == '\n';
  qfli_lua_free(finalizer);

  okay &= write_source(source,
                       "io.stderr:write(string.rep('x', 1024 * 1024))\n"
                       "error('failure remains visible')\n");
  QfliLuaResult *full_error = qfli_lua_run(source, ".", 2000);
  okay &= full_error && full_error->status != 0 &&
          strlen(full_error->error) <= 1024 * 1024 &&
          strstr(full_error->error, "failure remains visible") != NULL;
  qfli_lua_free(full_error);

#if defined(_WIN32)
  okay &= _mkdir("qfli_lua_project") == 0;
#else
  okay &= mkdir("qfli_lua_project", 0700) == 0;
#endif
  okay &= write_source("qfli_lua_project/module.lua", "return 'project module'");
  okay &= write_source("qfli_lua_project/env.lua", "return answer");
  okay &= write_source("qfli_lua_project/yield.lua",
                       "coroutine.yield('yielded'); return 'resumed'");
  okay &= write_source("qfli_lua_project/main.lua",
                       "local file = assert(io.open('data.txt', 'w'))\n"
                       "file:write('project data\\n')\n"
                       "file:close()\n"
                       "io.output('redirected.txt')\n"
                       "io.write('redirected')\n"
                       "io.close()\n"
                       "io.output(io.stdout)\n"
                       "assert(os.rename('redirected.txt', 'renamed.txt'))\n"
                       "for line in io.lines('data.txt') do print(line) end\n"
                       "io.input('data.txt')\n"
                       "print(io.read('l'))\n"
                       "io.close(io.input())\n"
                       "print(dofile('module.lua'))\n"
                       "print(assert(loadfile('env.lua', 't', {answer = 42}))())\n"
                       "local co = coroutine.create(function()\n"
                       "  return dofile('yield.lua')\n"
                       "end)\n"
                       "local ok, value = coroutine.resume(co)\n"
                       "assert(ok); print(value)\n"
                       "ok, value = coroutine.resume(co)\n"
                       "assert(ok); print(value)\n"
                       "local renamed = assert(io.open('renamed.txt'))\n"
                       "print(renamed:read('a'))\n"
                       "renamed:close()\n"
                       "assert(os.remove('renamed.txt'))\n"
                       "assert(os.remove('data.txt'))\n");
  QfliLuaResult *project_files = qfli_lua_run("main.lua", "qfli_lua_project", 2000);
  okay &= project_files && project_files->status == 0 &&
          strcmp(project_files->output,
                 "project data\nproject data\nproject module\n42\n"
                 "yielded\nresumed\nredirected\n") == 0;
  if (project_files && project_files->status != 0)
    fprintf(stderr, "Project file operations failed: %s\n", project_files->error);
  qfli_lua_free(project_files);
  remove("qfli_lua_project/main.lua");
  remove("qfli_lua_project/module.lua");
  remove("qfli_lua_project/env.lua");
  remove("qfli_lua_project/yield.lua");
  remove("qfli_lua_project/data.txt");
  remove("qfli_lua_project/redirected.txt");
  remove("qfli_lua_project/renamed.txt");
#if defined(_WIN32)
  _rmdir("qfli_lua_project");
#else
  rmdir("qfli_lua_project");
#endif

  okay &= write_source(source, "print('before')\nos.exit(7)\nprint('after')\n");
  QfliLuaResult *exited = qfli_lua_run(source, ".", 2000);
  okay &= exited && exited->status == 7 &&
          strcmp(exited->output, "before\n") == 0;
  qfli_lua_free(exited);

  okay &= write_source(source,
                       "print('before')\n"
                       "pcall(os.exit, 7)\n"
                       "print('after')\n");
  QfliLuaResult *caught_exit = qfli_lua_run(source, ".", 2000);
  okay &= caught_exit && caught_exit->status == 7 &&
          strcmp(caught_exit->output, "before\nafter\n") == 0;
  qfli_lua_free(caught_exit);

  okay &= write_source(source,
                       "collectgarbage('stop')\n"
                       "retained = setmetatable({}, {\n"
                       "  __gc = function() os.exit(9) end\n"
                       "})\n");
  QfliLuaResult *finalizer_exit = qfli_lua_run(source, ".", 2000);
  okay &= finalizer_exit && finalizer_exit->status == 9;
  qfli_lua_free(finalizer_exit);

  okay &= write_source(source, "local = invalid\n");
  QfliLuaResult *syntax = qfli_lua_check(source);
  okay &= syntax && syntax->status != 0 && strstr(syntax->error, "lua") != NULL;
  qfli_lua_free(syntax);

  okay &= write_source(source, "while true do end\n");
  QfliLuaResult *timeout = qfli_lua_run(source, ".", 25);
  okay &= timeout && timeout->status != 0 &&
          strstr(timeout->error, "timed out") != NULL;
  qfli_lua_free(timeout);

  QfliLuaCancelToken *token = qfli_lua_token_new();
  okay &= token != NULL;
  qfli_lua_token_cancel(token);
  okay &= write_source(source, "print('must not run')\n");
  QfliLuaResult *cancelled = qfli_lua_run_with_token(source, ".", 2000, token);
  okay &= cancelled && cancelled->status == 130 &&
          strstr(cancelled->error, "cancelled") != NULL &&
          strcmp(cancelled->output, "") == 0;
  qfli_lua_free(cancelled);
  qfli_lua_token_free(token);

  if (!okay) fprintf(stderr, "Lua runtime behavior test failed\n");
  remove(source);
  remove(bytecode);
  return okay ? 0 : 1;
}
