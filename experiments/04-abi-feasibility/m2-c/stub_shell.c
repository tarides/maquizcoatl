/* Derived from Oniguruma's public headers and sources at f95747b
   (prototypes, case lists); Oniguruma's notice follows. */
/*-
 * Copyright (c) 2002-2025  K.Kosako
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/* stub_shell.c: the hand-written part of the mechanism 2 stub.
   onig_error_code_to_str is variadic (upstream/src/oniguruma.h:812):
   the third argument, an OnigErrorInfo*, is read with va_arg only for
   the codes that carry a name (upstream/src/regerror.c:306-312). */
#include <stdarg.h>
#include <stdio.h>
#include "oniguruma.h"

int onig_error_code_to_str(OnigUChar* s, int code, ...)
{
  va_list ap;
  OnigErrorInfo* einfo = 0;
  va_start(ap, code);
  switch (code) {
  case ONIGERR_UNDEFINED_NAME_REFERENCE:
  case ONIGERR_UNDEFINED_GROUP_REFERENCE:
  case ONIGERR_MULTIPLEX_DEFINED_NAME:
  case ONIGERR_MULTIPLEX_DEFINITION_NAME_CALL:
  case ONIGERR_INVALID_GROUP_NAME:
  case ONIGERR_INVALID_CHAR_IN_GROUP_NAME:
  case ONIGERR_INVALID_CHAR_PROPERTY_NAME:
    einfo = va_arg(ap, OnigErrorInfo*);
    break;
  default:
    break;
  }
  va_end(ap);
  return snprintf((char*)s, ONIG_MAX_ERROR_MESSAGE_LEN, "stub error %d%s",
                  code, einfo ? " (with name)" : "");
}
