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

  QfliLuaResult *parse_bytecode = qfli_lua_compile_ex(bytecode, NULL, 0);
  QfliLuaResult *strip_bytecode = qfli_lua_compile_ex(bytecode, bytecode, 1);
  QfliLuaResult *run_stripped = qfli_lua_run(bytecode, ".", 2000);
  okay &= parse_bytecode && parse_bytecode->status == 0 &&
          strip_bytecode && strip_bytecode->status == 0 &&
          run_stripped && run_stripped->status == 0 &&
          strcmp(run_stripped->output, "42\n") == 0;
  qfli_lua_free(parse_bytecode);
  qfli_lua_free(strip_bytecode);
  qfli_lua_free(run_stripped);

  const char *valid_buffer = "error('must not execute')";
  QfliLuaResult *buffer_ok = qfli_lua_check_source(valid_buffer,
                                                   strlen(valid_buffer),
                                                   "@unsaved.lua");
  const char *invalid_buffer = "local = invalid";
  QfliLuaResult *buffer_error = qfli_lua_check_source(invalid_buffer,
                                                      strlen(invalid_buffer),
                                                      "@unsaved.lua");
  const char nul_buffer[] = "return 1\0return 2";
  QfliLuaResult *buffer_nul = qfli_lua_check_source(nul_buffer,
                                                    sizeof(nul_buffer) - 1,
                                                    "@unsaved.lua");
  okay &= buffer_ok && buffer_ok->status == 0 &&
          buffer_ok->output_length == 0 && buffer_ok->error_length == 0 &&
          buffer_error && buffer_error->status == 3 &&
          strstr(buffer_error->error, "unsaved.lua:1:") != NULL &&
          buffer_nul && buffer_nul->status == 3;
  qfli_lua_free(buffer_ok);
  qfli_lua_free(buffer_error);
  qfli_lua_free(buffer_nul);

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
  okay &= write_source("qfli_lua_project/main.lua",
                       "local path = os.tmpname()\n"
                       "assert(path:find('qfli_lua_project', 1, true))\n"
                       "local named = assert(io.open(path, 'r+b'))\n"
                       "assert(named:read('a') == '')\n"
                       "assert(named:close())\n"
                       "assert(os.remove(path))\n"
                       "local file = assert(io.tmpfile())\n"
                       "assert(file:write('temporary'))\n"
                       "assert(file:seek('set', 0) == 0)\n"
                       "print(file:read('a'))\n"
                       "assert(file:close())\n"
                       "retained_temp = assert(io.tmpfile())\n");
  QfliLuaResult *project_temps = qfli_lua_run("main.lua", "qfli_lua_project", 2000);
  okay &= project_temps && project_temps->status == 0 &&
          strcmp(project_temps->output, "temporary\n") == 0;
  if (project_temps && project_temps->status != 0)
    fprintf(stderr, "Project temporary files failed: %s\n", project_temps->error);
  qfli_lua_free(project_temps);
  okay &= write_source("qfli_lua_host_input.txt", "host input must stay unread\n");
  okay &= freopen("qfli_lua_host_input.txt", "rb", stdin) != NULL;
  okay &= write_source("qfli_lua_project/input.txt", "first\nsecond\n");
  okay &= write_source("qfli_lua_project/main.lua",
                       "print(io.read('l'))\n"
                       "print(io.stdin:read('l'))\n"
                       "assert(io.read('l') == nil)\n");
  QfliLuaResult *project_input = qfli_lua_run("main.lua", "qfli_lua_project", 2000);
  okay &= project_input && project_input->status == 0 &&
          strcmp(project_input->output, "first\nsecond\n") == 0;
  qfli_lua_free(project_input);
  okay &= fgetc(stdin) == 'h';
  remove("qfli_lua_project/input.txt");
  okay &= write_source("qfli_lua_project/main.lua",
                       "assert(io.read('a') == '')\n"
                       "assert(io.stdin:read('l') == nil)\n"
                       "print('EOF')\n");
  QfliLuaResult *missing_input = qfli_lua_run("main.lua", "qfli_lua_project", 2000);
  okay &= missing_input && missing_input->status == 0 &&
          strcmp(missing_input->output, "EOF\n") == 0;
  qfli_lua_free(missing_input);
#if defined(_WIN32)
  okay &= _mkdir("qfli_lua_project/input.txt") == 0;
#else
  okay &= mkdir("qfli_lua_project/input.txt", 0700) == 0;
#endif
  QfliLuaResult *invalid_input = qfli_lua_run("main.lua", "qfli_lua_project", 2000);
  okay &= invalid_input && invalid_input->status != 0 &&
          strstr(invalid_input->error, "regular file") != NULL &&
          strcmp(invalid_input->output, "") == 0;
  qfli_lua_free(invalid_input);
#if defined(_WIN32)
  _rmdir("qfli_lua_project/input.txt");
#else
  rmdir("qfli_lua_project/input.txt");
#endif
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

  /* The copyright banner is what `lua -v` prints; it must be the upstream one. */
  okay &= strstr(qfli_lua_copyright(), "Lua 5.4") != NULL &&
          strstr(qfli_lua_copyright(), "Copyright") != NULL &&
          strcmp(qfli_lua_version(), "Lua 5.4.8") == 0;

  /* `arg` and varargs mirror the upstream interpreter for a real command line. */
  okay &= write_source(source,
                       "print(arg[0], arg[1], arg[2], arg[-1], select('#', ...))\n"
                       "print((...))\n");
  const char *argv[] = {"lua", source, "first", "second"};
  const char *argv_expected =
      "qfli_lua_test.lua\tfirst\tsecond\tlua\t2\nfirst\n";
  QfliLuaResult *with_argv = qfli_lua_run_with_argv(
      source, ".", 2000, argv, 4, 1, NULL);
  okay &= with_argv && with_argv->status == 0 &&
          strcmp(with_argv->output, argv_expected) == 0;
  if (with_argv && strcmp(with_argv->output, argv_expected) != 0)
    fprintf(stderr, "argv run output: %s", with_argv->output);
  qfli_lua_free(with_argv);

  /* No argv keeps the historical shape: arg[0] is the file, no varargs. */
  okay &= write_source(source,
                       "print(arg[0], arg[1], select('#', ...))\n");
  QfliLuaResult *no_argv = qfli_lua_run_with_argv(source, ".", 2000, NULL, 0, 0,
                                                 NULL);
  okay &= no_argv && no_argv->status == 0 &&
          strcmp(no_argv->output, "qfli_lua_test.lua\tnil\t0\n") == 0;
  qfli_lua_free(no_argv);

  /* Real source pauses expose primitives without executing the next line. */
  okay &= write_source(source, "local n = 40\nn = n + 2\nprint(n)\n");
  QfliLuaDebugSession *debug = qfli_lua_debug_new(source, ".", 2000);
  QfliLuaDebugFrame frame;
  QfliLuaDebugValue local;
  okay &= debug && qfli_lua_debug_resume(debug, 1) == 1 &&
          qfli_lua_debug_frame(debug, 0, &frame) && frame.line == 1;
  okay &= qfli_lua_debug_resume(debug, 1) == 1 &&
          qfli_lua_debug_frame(debug, 0, &frame) && frame.line == 2 &&
          qfli_lua_debug_local(debug, 0, 1, &local) &&
          strcmp(local.name, "n") == 0 && strcmp(local.value, "40") == 0;
  const char *breakpoint_files[] = {source};
  const int breakpoint_lines[] = {3};
  okay &= qfli_lua_debug_set_breakpoints(debug, breakpoint_files,
                                           breakpoint_lines, 1) &&
          qfli_lua_debug_resume(debug, 0) == 1 &&
          qfli_lua_debug_frame(debug, 0, &frame) && frame.line == 3;
  qfli_lua_debug_stop(debug);
  okay &= qfli_lua_debug_resume(debug, 0) == 2;
  QfliLuaResult *debug_stopped = qfli_lua_debug_output(debug);
  okay &= debug_stopped && debug_stopped->status == 130 &&
          debug_stopped->output_length == 0;
  qfli_lua_free(debug_stopped);
  qfli_lua_debug_free(debug);

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
  fclose(stdin);
  remove("qfli_lua_host_input.txt");
  return okay ? 0 : 1;
}
