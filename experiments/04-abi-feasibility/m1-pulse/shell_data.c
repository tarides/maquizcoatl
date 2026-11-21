/* shell_data.c: hand-written C shell of mechanism 1, data part.
   OnigDefaultSyntax is a pointer to another global
   (upstream/src/regparse.c:165); F* has no address-of on a global, so
   it is defined here, outside the proofs. */
#include "oniguruma.h"

OnigSyntaxType* OnigDefaultSyntax = &OnigSyntaxOniguruma;
