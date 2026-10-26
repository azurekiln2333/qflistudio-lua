#include "qfli_lua_windows.h"

#include <errno.h>
#include <fcntl.h>
#include <io.h>
#include <stdlib.h>
#include <sys/stat.h>
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

int qfli_utf8_regular_file(const char *filename) {
  wchar_t *wide_filename = wide_path(filename);
  if (!wide_filename) return -1;
  struct _stat64 info;
  int result = _wstat64(wide_filename, &info);
  int saved_errno = errno;
  free(wide_filename);
  errno = saved_errno;
  return result < 0 ? -1 : ((info.st_mode & _S_IFMT) == _S_IFREG);
}

char *qfli_utf8_absolute_path(const char *filename) {
  wchar_t *wide_filename = wide_path(filename);
  if (!wide_filename) return NULL;
  wchar_t *absolute = _wfullpath(NULL, wide_filename, 0);
  free(wide_filename);
  if (!absolute) return NULL;
  int length = WideCharToMultiByte(CP_UTF8, 0, absolute, -1, NULL, 0, NULL, NULL);
  char *utf8 = length ? malloc((size_t)length) : NULL;
  if (utf8)
    WideCharToMultiByte(CP_UTF8, 0, absolute, -1, utf8, length, NULL, NULL);
  else
    errno = ENOMEM;
  free(absolute);
  return utf8;
}

FILE *qfli_utf8_create_exclusive(const char *filename) {
  wchar_t *wide_filename = wide_path(filename);
  if (!wide_filename) return NULL;
  int descriptor = _wopen(wide_filename,
      _O_CREAT | _O_EXCL | _O_RDWR | _O_BINARY | _O_NOINHERIT,
      _S_IREAD | _S_IWRITE);
  free(wide_filename);
  if (descriptor < 0) return NULL;
  FILE *file = _fdopen(descriptor, "w+b");
  if (!file) {
    int saved_errno = errno;
    _close(descriptor);
    qfli_utf8_remove(filename);
    errno = saved_errno;
  }
  return file;
}
