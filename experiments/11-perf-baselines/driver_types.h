/* Experiment #11: types shared by driver.h and the engine files. */
#ifndef E11_DRIVER_TYPES_H
#define E11_DRIVER_TYPES_H
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct {
  int pid;
  char syntax[32];
  unsigned long options;
  char encoding[32];
  unsigned char *pat;
  size_t len;
} pattern_t;

typedef struct { unsigned char *s; size_t len; } subject_t;

/* Compile status codes. */
#define ST_OK 0
#define ST_ERR 1       /* rejected with an error */
#define ST_UNSUP 2     /* option, syntax or encoding not supported */
#define ST_LIMIT 3     /* rejected by a resource limit */

/* Length of the character at s[at] for the empty-match step: one UTF-8
 * code point, judged by its lead byte only, or one byte when the lead
 * byte is not a valid UTF-8 lead byte. Same rule in every harness. */
static size_t utf8_advance(const unsigned char *s, size_t len, size_t at)
{
  unsigned c;
  size_t n;
  if (at >= len) return 1;
  c = s[at];
  n = c < 0x80 ? 1 : c < 0xC2 ? 1 : c < 0xE0 ? 2 : c < 0xF0 ? 3 : c < 0xF5 ? 4 : 1;
  return at + n > len ? len - at : n;
}
#endif
