/* variadic_call.c: calls onig_error_code_to_str without and with the
   optional OnigErrorInfo* argument (as upstream/test/test_options.c:45,71
   and sample/echo.c:65,89 do), to check that a stub's variadic entry
   point (C va_list, or Rust trampoline to C) receives both forms. */
#include <stdio.h>
#include <string.h>
#include "oniguruma.h"

int main(void) {
  OnigUChar buf[ONIG_MAX_ERROR_MESSAGE_LEN];
  OnigErrorInfo einfo;
  static OnigUChar name[] = "foo";
  int n;
  einfo.enc = ONIG_ENCODING_ASCII;
  einfo.par = name;
  einfo.par_end = name + 3;
  n = onig_error_code_to_str(buf, ONIGERR_MEMORY);
  printf("without einfo: %d [%s]\n", n, buf);
  n = onig_error_code_to_str(buf, ONIGERR_UNDEFINED_NAME_REFERENCE, &einfo);
  printf("with einfo:    %d [%s]\n", n, buf);
  return 0;
}
