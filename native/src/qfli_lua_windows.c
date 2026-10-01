#include "qfli_lua_windows.h"

#include <errno.h>
#include <stdlib.h>
#include <wchar.h>
#include <windows.h>

static wchar_t *wide_path(const char *utf8) {
  if (!utf8) {
    errno = EINVAL;
    return NULL;
  }
  int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8, -1,
                                 NULL, 0);
  if (!length) {
    errno = EILSEQ;
    return NULL;
  }
  wchar_t *wide = (wchar_t *)malloc((size_t)length * sizeof(wchar_t));
  if (!wide) {
    errno = ENOMEM;
    return NULL;
  }
  if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8, -1, wide,
                         length)) {
    free(wide);
    errno = EILSEQ;
    return NULL;
  }
  return wide;
}

FILE *qfli_utf8_fopen(const char *filename, const char *mode) {
  wchar_t *wide_filename = wide_path(filename);
  if (!wide_filename) return NULL;
  wchar_t *wide_mode = wide_path(mode);
  FILE *file = wide_mode ? _wfopen(wide_filename, wide_mode) : NULL;
  int saved_errno = errno;
  free(wide_filename);
  free(wide_mode);
  errno = saved_errno;
  return file;
}

FILE *qfli_utf8_freopen(const char *filename, const char *mode, FILE *stream) {
  wchar_t *wide_filename = wide_path(filename);
  if (!wide_filename) return NULL;
  wchar_t *wide_mode = wide_path(mode);
  FILE *file = wide_mode ? _wfreopen(wide_filename, wide_mode, stream) : NULL;
  int saved_errno = errno;
  free(wide_filename);
  free(wide_mode);
  errno = saved_errno;
  return file;
}

int qfli_utf8_remove(const char *filename) {
  wchar_t *wide_filename = wide_path(filename);
  if (!wide_filename) return -1;
  int result = _wremove(wide_filename);
  int saved_errno = errno;
  free(wide_filename);
  errno = saved_errno;
  return result;
}

int qfli_utf8_rename(const char *source, const char *destination) {
  wchar_t *wide_source = wide_path(source);
  if (!wide_source) return -1;
  wchar_t *wide_destination = wide_path(destination);
  int result = wide_destination ? _wrename(wide_source, wide_destination) : -1;
  int saved_errno = errno;
  free(wide_source);
  free(wide_destination);
  errno = saved_errno;
  return result;
}
