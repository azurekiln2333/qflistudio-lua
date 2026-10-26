#if !defined(_WIN32)
#define _POSIX_C_SOURCE 200809L
#endif
#include "qfli_script.h"
#include "quickjs.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>
#include <ctype.h>
#include <time.h>
#if defined(_WIN32)
#include <windows.h>
#endif
#if defined(__GNUC__) && !defined(__clang__) && __GNUC__ < 9
#error "QuickJS requires GCC9+ or Clang; GCC4.9 miscompiles module atoms"
#endif
#define OUTPUT_LIMIT (1024u * 1024u)
#define SOURCE_LIMIT (512u * 1024u)
struct QfliScriptToken { atomic_int cancelled; };
typedef struct { char *data; size_t length, capacity; } Buffer;
typedef struct Rejection {
  JSValue promise, reason;
  struct Rejection *next;
} Rejection;
typedef struct {
  JSRuntime *runtime;
  JSContext *context;
  QfliScriptResult *result;
  QfliScriptToken *token;
  Buffer output, errors;
  JSValue compiler, documents, diagnostics, reported_exception;
  Rejection *rejections;
  const char *file;
  double started;
  int timeout_ms, interrupted;
} Operation;
static double now_ms(void) {
#if defined(_WIN32)
  LARGE_INTEGER count, frequency;
  QueryPerformanceCounter(&count); QueryPerformanceFrequency(&frequency);
  return (double)count.QuadPart * 1000.0 / frequency.QuadPart;
#else
  struct timespec value; clock_gettime(CLOCK_MONOTONIC, &value);
  return (double)value.tv_sec * 1000.0 + value.tv_nsec / 1000000.0;
#endif
}
static char *copy(const char *data, size_t length) {
  char *value = malloc(length + 1);
  if (value) { if (length) memcpy(value, data, length); value[length] = 0; }
  return value;
}
static int append(Buffer *buffer, const char *value, size_t length) {
  if (length > OUTPUT_LIMIT - buffer->length) return 0;
  if (buffer->length + length + 1 > buffer->capacity) {
    size_t capacity = buffer->capacity ? buffer->capacity : 256;
    while (capacity < buffer->length + length + 1) capacity *= 2;
    char *data = realloc(buffer->data, capacity);
    if (!data) return 0;
    buffer->data = data; buffer->capacity = capacity;
  }
  if (length) memcpy(buffer->data + buffer->length, value, length);
  buffer->length += length; buffer->data[buffer->length] = 0;
  return 1;
}
static int interrupted(JSRuntime *runtime, void *opaque) {
  (void)runtime;
  Operation *operation = opaque;
  if (operation->token && atomic_load(&operation->token->cancelled))
    operation->interrupted = 130;
  else if (now_ms() - operation->started >= operation->timeout_ms)
    operation->interrupted = 124;
  return operation->interrupted != 0;
}
static JSValue console_write(JSContext *context, JSValueConst self,
                              int count, JSValueConst *values, int error) {
  (void)self;
  Operation *operation = JS_GetContextOpaque(context);
  Buffer *target = error ? &operation->errors : &operation->output;
  for (int index = 0; index < count; index++) {
    size_t length = 0;
    const char *text = JS_ToCStringLen(context, &length, values[index]);
    if (!text) return JS_EXCEPTION;
    int okay = (index == 0 || append(target, " ", 1)) && append(target, text, length);
    JS_FreeCString(context, text);
    if (!okay) return JS_ThrowRangeError(context, "Script output exceeds1MiB");
  }
  if (!append(target, "\n", 1)) return JS_ThrowRangeError(context, "Script output exceeds1MiB");
  return JS_UNDEFINED;
}
static int number_property(JSContext *context, JSValueConst value, const char *key) {
  JSValue property = JS_GetPropertyStr(context, value, key);
  int32_t number = 0;
  JS_ToInt32(context, &number, property); JS_FreeValue(context, property);
  return number;
}
static void add_diagnostic(Operation *operation, const char *file, int start, int end,
                             JSValue message, JSValue code, int severity) {
  JSContext *context = operation->context;
  JSValue item = JS_NewObject(context);
  JS_SetPropertyStr(context, item, "filePath", JS_NewString(context, file));
  JS_SetPropertyStr(context, item, "startOffset", JS_NewInt32(context, start));
  JS_SetPropertyStr(context, item, "endOffset", JS_NewInt32(context, end));
  JS_SetPropertyStr(context, item, "message", message);
  JS_SetPropertyStr(context, item, "code", code);
  JS_SetPropertyStr(context, item, "severity", JS_NewInt32(context, severity));
  int count = number_property(context, operation->diagnostics, "length");
  JS_SetPropertyUint32(context, operation->diagnostics, (uint32_t)count, item);
}
/* QuickJS locations count Unicode scalars; offsets count exact UTF16 units. */
static int offsets(const unsigned char *source, size_t length, int target_line,
                     int target_column, int *start, int *end) {
  int line = 1, column = 1, utf16 = 0;
  size_t index = 0;
  while (index < length) {
    unsigned char first = source[index];
    size_t bytes = first < 0x80 ? 1 : first < 0xe0 ? 2 : first < 0xf0 ? 3 : 4;
    int units = bytes == 4 ? 2 : 1;
    if (line == target_line && column == target_column) {
      *start = utf16; *end = utf16 + units; return 1;
    }
    if (index + bytes > length) return 0;
    index += bytes; utf16 += units;
    if (first == '\n') { line++; column = 1; } else column++;
  }
  if (line == target_line && column == target_column) {
    *start = *end = utf16; return 1;
  }
  return 0;
}
static void error_text(Operation *operation, const char *text, size_t length) {
  if (length >= OUTPUT_LIMIT) length = OUTPUT_LIMIT - 1;
  if (operation->errors.length > OUTPUT_LIMIT - length - 1) {
    operation->errors.length = OUTPUT_LIMIT - length - 1;
    if (operation->errors.data) operation->errors.data[operation->errors.length] = 0;
  }
  append(&operation->errors, text, length); append(&operation->errors, "\n", 1);
}
static void capture_exception(Operation *operation, const char *source,
                                size_t length, int checking) {
  JSContext *context = operation->context;
  JSValue exception = JS_GetException(context);
  if (!JS_IsUndefined(operation->reported_exception) &&
      JS_StrictEq(context, operation->reported_exception, exception)) {
    JS_FreeValue(context, exception); return;
  }
  JS_FreeValue(context, operation->reported_exception);
  operation->reported_exception = JS_DupValue(context, exception);
  JSValue name_value = JS_GetPropertyStr(context, exception, "name");
  const char *name = JS_ToCString(context, name_value);
  size_t message_length = 0;
  const char *message = JS_ToCStringLen(context, &message_length, exception);
  int status = checking ? 127 : 1;
  int start = 0, end = 0;
  if (checking && name && strcmp(name, "SyntaxError") == 0 && source &&
      offsets((const unsigned char *)source, length,
              number_property(context, exception, "lineNumber"),
              number_property(context, exception, "columnNumber"), &start, &end)) {
    status = 3;
    add_diagnostic(operation, operation->file, start, end,
        JS_NewStringLen(context, message ? message : "JavaScript syntax error",
                           message ? message_length : 23),
        JS_NewString(context, "javascript.syntax"), 1);
  }
  if (message) error_text(operation, message, message_length);
  else error_text(operation, "Script engine failed", 20);
  if (!checking) {
    JSValue stack = JS_GetPropertyStr(context, exception, "stack");
    const char *text = JS_ToCStringLen(context, &message_length, stack);
    if (text && !JS_IsUndefined(stack)) error_text(operation, text, message_length);
    JS_FreeCString(context, text); JS_FreeValue(context, stack);
  }
  operation->result->status = operation->interrupted ? operation->interrupted :
      operation->result->status == 3 ? 3 : status;
  JS_FreeCString(context, message); JS_FreeCString(context, name);
  JS_FreeValue(context, name_value); JS_FreeValue(context, exception);
}
static int load_compiler(Operation *operation, const char *source, size_t length) {
  if (!source || !length || length > 12u * 1024u * 1024u) return 0;
  const char *prefix = "(function(){\n", *suffix = "\nreturn ts;})()";
  size_t prefix_length = strlen(prefix), suffix_length = strlen(suffix);
  char *wrapped = malloc(prefix_length + length + suffix_length + 1);
  if (!wrapped) return 0;
  memcpy(wrapped, prefix, prefix_length); memcpy(wrapped + prefix_length, source, length);
  memcpy(wrapped + prefix_length + length, suffix, suffix_length + 1);
  operation->compiler = JS_Eval(operation->context, wrapped,
      prefix_length + length + suffix_length, "<trusted-typescript-5.9.3>", JS_EVAL_TYPE_GLOBAL);
  free(wrapped);
  return !JS_IsException(operation->compiler) && JS_IsObject(operation->compiler);
}
static JSValue transpile(Operation *operation, const char *source, size_t length,
                            const char *file) {
  JSContext *context = operation->context;
  JSValue options = JS_NewObject(context), settings = JS_NewObject(context);
  JS_SetPropertyStr(context, settings, "target", JS_NewInt32(context, 99));
  JS_SetPropertyStr(context, settings, "module", JS_NewInt32(context, 99));
  JS_SetPropertyStr(context, options, "compilerOptions", settings);
  JS_SetPropertyStr(context, options, "fileName", JS_NewString(context, file));
  JS_SetPropertyStr(context, options, "reportDiagnostics", JS_TRUE);
  JSValue function = JS_GetPropertyStr(context, operation->compiler, "transpileModule");
  JSValue arguments[2] = {JS_NewStringLen(context, source, length), options};
  JSValue compiled = JS_Call(context, function, operation->compiler, 2, arguments);
  JS_FreeValue(context, arguments[0]); JS_FreeValue(context, options); JS_FreeValue(context, function);
  if (JS_IsException(compiled)) return compiled;
  JSValue diagnostics = JS_GetPropertyStr(context, compiled, "diagnostics");
  int count = number_property(context, diagnostics, "length");
  for (int index = 0; index < count && index < 256; index++) {
    JSValue diagnostic = JS_GetPropertyUint32(context, diagnostics, (uint32_t)index);
    int start = number_property(context, diagnostic, "start");
    int span = number_property(context, diagnostic, "length");
    int category = number_property(context, diagnostic, "category");
    JSValue message = JS_GetPropertyStr(context, diagnostic, "messageText");
    JSValue flatten = JS_GetPropertyStr(context, operation->compiler, "flattenDiagnosticMessageText");
    JSValue flatten_arguments[2] = {message, JS_NewString(context, "\n")};
    JSValue flattened = JS_Call(context, flatten, operation->compiler, 2, flatten_arguments);
    JS_FreeValue(context, message); JS_FreeValue(context, flatten_arguments[1]); JS_FreeValue(context, flatten);
    JSValue code = JS_GetPropertyStr(context, diagnostic, "code");
    if (category == 1) {
      size_t message_length = 0;
      const char *text = JS_ToCStringLen(context, &message_length, flattened);
      if (text) error_text(operation, text, message_length);
      JS_FreeCString(context, text);
      operation->result->status = 3;
    }
    add_diagnostic(operation, file, start, start + span, flattened, code, category);
    JS_FreeValue(context, diagnostic);
  }
  JS_FreeValue(context, diagnostics);
  JSValue output = JS_GetPropertyStr(context, compiled, "outputText");
  JS_FreeValue(context, compiled);
  return output;
}
static JSModuleDef *module_loader(JSContext *context, const char *name, void *opaque) {
  Operation *operation = opaque;
  JSValue source_value = JS_GetPropertyStr(context, operation->documents, name);
  if (!JS_IsString(source_value)) {
    JS_FreeValue(context, source_value);
    JS_ThrowReferenceError(context, "Offline project module unavailable: %s", name);
    return NULL;
  }
  size_t length = 0;
  const char *source = JS_ToCStringLen(context, &length, source_value);
  JSValue emitted = JS_UNDEFINED;
  const char *text = source;
  const char *extension = strrchr(name, '.');
  if (extension && strlen(extension) == 3 && tolower((unsigned char)extension[1]) == 't' &&
      tolower((unsigned char)extension[2]) == 's') {
    if (JS_IsUndefined(operation->compiler)) {
      JS_ThrowReferenceError(context, "TypeScript compiler unavailable for %s", name);
      JS_FreeCString(context, source); JS_FreeValue(context, source_value); return NULL;
    }
    emitted = transpile(operation, source, length, name);
    if (JS_IsException(emitted) || operation->result->status == 3) {
      if (!JS_IsException(emitted)) JS_ThrowSyntaxError(context, "TypeScript module syntax failed: %s", name);
      JS_FreeValue(context, emitted); JS_FreeCString(context, source); JS_FreeValue(context, source_value); return NULL;
    }
    text = JS_ToCStringLen(context, &length, emitted);
  }
  JSValue compiled = text ? JS_Eval(context, text, length, name,
      JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY) : JS_EXCEPTION;
  if (text != source) JS_FreeCString(context, text);
  JS_FreeCString(context, source); JS_FreeValue(context, emitted); JS_FreeValue(context, source_value);
  if (JS_IsException(compiled)) return NULL;
  JSModuleDef *module = JS_VALUE_GET_PTR(compiled);
  JS_FreeValue(context, compiled); return module;
}
static void rejection_tracker(JSContext *context, JSValueConst promise,
                                  JSValueConst reason, JS_BOOL handled, void *opaque) {
  Operation *operation = opaque;
  Rejection **cursor = &operation->rejections;
  while (*cursor && JS_VALUE_GET_PTR((*cursor)->promise) != JS_VALUE_GET_PTR(promise)) cursor = &(*cursor)->next;
  if (*cursor && handled) {
    Rejection *removed = *cursor; *cursor = removed->next;
    JS_FreeValue(context, removed->promise); JS_FreeValue(context, removed->reason); free(removed);
  } else if (!*cursor && !handled) {
    Rejection *created = malloc(sizeof(*created));
    if (!created) { operation->result->status = 127; return; }
    created->promise = JS_DupValue(context, promise); created->reason = JS_DupValue(context, reason);
    created->next = NULL; *cursor = created;
  }
}
const char *qfli_script_version(void) { return "QuickJS2026-06-04 / TypeScript5.9.3 transpileModule"; }
QfliScriptToken *qfli_script_token_new(void) {
  QfliScriptToken *token = malloc(sizeof(*token));
  if (token) atomic_init(&token->cancelled, 0);
  return token;
}
void qfli_script_token_cancel(QfliScriptToken *token) { if (token) atomic_store(&token->cancelled, 1); }
void qfli_script_token_free(QfliScriptToken *token) { free(token); }
void qfli_script_free(QfliScriptResult *result) {
  if (!result) return;
  free(result->output); free(result->error); free(result->diagnostics); free(result);
}
QfliScriptResult *qfli_script_process(const char *source, size_t length,
    const char *file, const char *project, const char *documents, size_t documents_length,
    const char *compiler, size_t compiler_length, int language, int action,
    int module, int timeout_ms, QfliScriptToken *token) {
  (void)project;
  QfliScriptResult *result = calloc(1, sizeof(*result));
  if (!result) return NULL;
  Operation operation = {0};
  operation.result = result; operation.token = token;
  operation.file = file;
  operation.started = now_ms(); operation.timeout_ms = timeout_ms > 0 ? timeout_ms : 10000;
  operation.compiler = operation.documents = operation.diagnostics = operation.reported_exception = JS_UNDEFINED;
  if (!source || !file || length > SOURCE_LIMIT || language < 0 || language > 1 || action < 0 || action > 2) {
    result->status = 127; error_text(&operation, "Invalid Script input or source exceeds512KiB", 44); goto finish;
  }
  if (interrupted(NULL, &operation)) { result->status = operation.interrupted; goto finish; }
  operation.runtime = JS_NewRuntime();
  if (!operation.runtime) { result->status = 127; goto finish; }
  JS_SetMemoryLimit(operation.runtime, 256u * 1024u * 1024u);
  JS_SetMaxStackSize(operation.runtime, 2u * 1024u * 1024u);
  JS_SetInterruptHandler(operation.runtime, interrupted, &operation);
  operation.context = JS_NewContext(operation.runtime);
  if (!operation.context) { result->status = 127; goto finish; }
  JSContext *context = operation.context;
  JS_SetContextOpaque(context, &operation);
  operation.diagnostics = JS_NewArray(context);
  if (language || compiler_length) {
    if (!load_compiler(&operation, compiler, compiler_length)) {
      result->status = operation.interrupted ? operation.interrupted : 127;
      error_text(&operation, "TypeScript compiler initialization failed", 41);
      goto finish;
    }
  }
  JSValue emitted = JS_UNDEFINED;
  const char *text = source;
  size_t text_length = length;
  if (language) {
    emitted = transpile(&operation, source, length, file);
    if (JS_IsException(emitted)) { capture_exception(&operation, NULL, 0, 1); goto emitted_finish; }
    if (result->status == 3) goto emitted_finish;
    /* Compiler diagnostics index original TS; engine offsets index emitted JS.
       A syntax-only TS check must never decorate generated-code locations. */
    if (action == 1) goto emitted_finish;
    text = JS_ToCStringLen(context, &text_length, emitted);
    if (!text) { capture_exception(&operation, NULL, 0, 1); goto emitted_finish; }
  }
  if (action == 2) {
    if (!append(&operation.output, text, text_length)) result->status = 127;
    goto text_finish;
  }
  if (action == 0) {
    operation.documents = documents && documents_length ?
        JS_ParseJSON(context, documents, documents_length, "<project-snapshots>") : JS_NewObject(context);
    if (JS_IsException(operation.documents)) { capture_exception(&operation, NULL, 0, 0); goto text_finish; }
    JS_SetModuleLoaderFunc(operation.runtime, NULL, module_loader, &operation);
    JS_SetHostPromiseRejectionTracker(operation.runtime, rejection_tracker, &operation);
    JSValue global = JS_GetGlobalObject(context), console = JS_NewObject(context);
    const char *names[] = {"log", "info", "debug", "warn", "error"};
    for (int index = 0; index < 5; index++) JS_SetPropertyStr(context, console, names[index],
        JS_NewCFunctionMagic(context, console_write, names[index], 1, JS_CFUNC_generic_magic, index >= 3));
    JS_SetPropertyStr(context, global, "console", console);
    JS_FreeValue(context, global);
  }
  JSValue value = JS_Eval(context, text, text_length, file,
      (module ? JS_EVAL_TYPE_MODULE : JS_EVAL_TYPE_GLOBAL) | (action == 1 ? JS_EVAL_FLAG_COMPILE_ONLY : 0));
  if (JS_IsException(value)) capture_exception(&operation, text, text_length, action == 1);
  else if (action == 0) {
    JSContext *job_context = context;
    int jobs;
    while ((jobs = JS_ExecutePendingJob(operation.runtime, &job_context)) > 0) {
      if (interrupted(operation.runtime, &operation)) break;
    }
    if (jobs < 0) { JSContext *original = operation.context; operation.context = job_context;
      capture_exception(&operation, NULL, 0, 0); operation.context = original; }
    int promise_state = JS_PromiseState(context, value);
    if (promise_state >= 0 && promise_state != JS_PROMISE_FULFILLED) {
      JSValue reason = JS_PromiseResult(context, value);
      if (JS_PromiseState(context, value) == JS_PROMISE_REJECTED) {
        JS_Throw(context, reason); capture_exception(&operation, NULL, 0, 0);
      } else { JS_FreeValue(context, reason); result->status = 1;
        const char *message = "Pending async work requires unavailable host APIs";
        error_text(&operation, message, strlen(message)); }
    }
    for (Rejection *rejected = operation.rejections; rejected; rejected = rejected->next) {
      if (promise_state >= 0 && JS_VALUE_GET_PTR(rejected->promise) == JS_VALUE_GET_PTR(value)) continue;
      JS_Throw(context, JS_DupValue(context, rejected->reason)); capture_exception(&operation, NULL, 0, 0);
    }
  }
  JS_FreeValue(context, value);
text_finish:
  if (text != source) JS_FreeCString(context, text);
emitted_finish:
  JS_FreeValue(context, emitted);
finish:
  if (operation.interrupted) {
    result->status = operation.interrupted;
    const char *message = operation.interrupted == 130 ? "Script execution cancelled" : "Script execution timed out";
    error_text(&operation, message, strlen(message));
  }
  if (operation.context) {
    JSContext *context = operation.context;
    JSValue json = JS_JSONStringify(context, operation.diagnostics, JS_UNDEFINED, JS_UNDEFINED);
    const char *data = JS_ToCStringLen(context, &result->diagnostics_length, json);
    if (data) result->diagnostics = copy(data, result->diagnostics_length);
    JS_FreeCString(context, data); JS_FreeValue(context, json);
    while (operation.rejections) { Rejection *item = operation.rejections; operation.rejections = item->next;
      JS_FreeValue(context, item->promise); JS_FreeValue(context, item->reason); free(item); }
    JS_FreeValue(context, operation.compiler); JS_FreeValue(context, operation.documents);
    JS_FreeValue(context, operation.reported_exception);
    JS_FreeValue(context, operation.diagnostics); JS_FreeContext(context);
  }
  if (operation.runtime) JS_FreeRuntime(operation.runtime);
  result->output = operation.output.data ? operation.output.data : copy("", 0);
  result->error = operation.errors.data ? operation.errors.data : copy("", 0);
  result->output_length = operation.output.length; result->error_length = operation.errors.length;
  if (!result->diagnostics) { result->diagnostics = copy("[]", 2); result->diagnostics_length = 2; }
  if (!result->output || !result->error || !result->diagnostics) { qfli_script_free(result); return NULL; }
  return result;
}
