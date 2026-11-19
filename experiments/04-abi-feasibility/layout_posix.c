/* layout_posix.c: POSIX structs of onigposix.h, real type names
   (regex_t/regmatch_t are macros there, onigposix.h:176-187). */
#include <stdio.h>
#include <stddef.h>
#include "onigposix.h"
#define S(T)   printf("%s - %zu %zu %zu\n", #T, (size_t)0, sizeof(T), _Alignof(T))
#define F(T,f) printf("%s %s %zu %zu %zu\n", #T, #f, offsetof(T,f), \
                      sizeof(((T*)0)->f), _Alignof(__typeof__(((T*)0)->f)))
int main(void) {
  S(onig_posix_regmatch_t);
  F(onig_posix_regmatch_t, rm_so); F(onig_posix_regmatch_t, rm_eo);
  S(onig_posix_regex_t);
  F(onig_posix_regex_t, onig); F(onig_posix_regex_t, re_nsub);
  F(onig_posix_regex_t, comp_options);
  return 0;
}
