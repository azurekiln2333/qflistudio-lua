#ifndef QFLI_SCRIPT_H
#define QFLI_SCRIPT_H
#include <stddef.h>
#if defined(_WIN32)
#define QFLI_SCRIPT_API __declspec(dllexport)
#elif defined(__APPLE__)
#define QFLI_SCRIPT_API __attribute__((used,visibility("default")))
#else
#define QFLI_SCRIPT_API __attribute__((visibility("default")))
#endif

typedef struct QfliScriptToken QfliScriptToken;
typedef struct {
  int status;
  char *output;
  char *error;
  char *diagnostics;
  size_t output_length;
  size_t error_length;
  size_t diagnostics_length;
} QfliScriptResult;
QFLI_SCRIPT_API const char *qfli_script_version(void);
QFLI_SCRIPT_API QfliScriptToken *qfli_script_token_new(void);
QFLI_SCRIPT_API void qfli_script_token_cancel(QfliScriptToken *token);
QFLI_SCRIPT_API void qfli_script_token_free(QfliScriptToken *token);
/* language:0 JavaScript,1 TypeScript. action:0 run,1 check,2 transpile.
 * UTF8 byte lengths exclude the accessible trailing NUL. Checks never execute
 * user chunks/jobs/imports; the only evaluated code is the trusted TS compiler.
 * Documents map absolute normalized POSIX paths to exact source strings. */
QFLI_SCRIPT_API QfliScriptResult *qfli_script_process(
    const char *source, size_t length, const char *file,
    const char *project, const char *documents, size_t documents_length,
    const char *compiler, size_t compiler_length,
    int language, int action, int module, int timeout_ms, QfliScriptToken *token);
QFLI_SCRIPT_API void qfli_script_free(QfliScriptResult *result);
#endif
