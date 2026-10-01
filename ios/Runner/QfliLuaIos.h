#ifndef QFLI_LUA_IOS_H
#define QFLI_LUA_IOS_H

// iOS forbids shell subprocesses. Override Lua's POSIX fallback without changing upstream.
#define l_popen(L, command, mode) \
  ((void)(command), (void)(mode), \
   luaL_error((L), "'popen' is not supported on iOS"), (FILE *)0)
#define l_pclose(L, file) ((void)(L), (void)(file), -1)

#endif
