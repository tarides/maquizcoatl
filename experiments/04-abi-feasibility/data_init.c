/* data_init.c: reads libonig's data symbols before calling any library
   function, as a client using ONIG_ENCODING_* / ONIG_SYNTAX_* may. A
   stub whose data is filled at run time (Custard's custard_init_globals)
   must have done it by the time main runs. */
#include <stdio.h>
#include "oniguruma.h"

int main(void) {
  printf("UTF8 max_enc_len=%d min_enc_len=%d mbc_enc_len=%s is_valid=%s\n",
         OnigEncodingUTF8.max_enc_len, OnigEncodingUTF8.min_enc_len,
         OnigEncodingUTF8.mbc_enc_len ? "set" : "NULL",
         OnigEncodingUTF8.is_valid_mbc_string ? "set" : "NULL");
  printf("ASCII mbc_enc_len=%s\n", OnigEncodingASCII.mbc_enc_len ? "set" : "NULL");
  printf("OnigDefaultSyntax==&OnigSyntaxOniguruma: %d\n",
         OnigDefaultSyntax == &OnigSyntaxOniguruma);
  printf("OnigDefaultCaseFoldFlag=0x%x\n", OnigDefaultCaseFoldFlag);
  return 0;
}
