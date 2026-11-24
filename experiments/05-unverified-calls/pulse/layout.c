/* layout.c: prints the size, alignment and member offsets of the three
   structs of proto.h. Compiled twice, once against proto.h and once
   (-DVU_KRML) against the header KaRaMeL generates; build.sh requires
   both outputs to be equal. The generated structs write the arrays of
   proto.h (slot[5], from[8]) as consecutive scalar fields. */

#include <stddef.h>
#include <stdio.h>

#ifdef VU_KRML
#include "Custard.h"
#define SLOT(k) slot##k
#define FROM(k) from##k
#else
#include "proto.h"
#define SLOT(k) slot[k]
#define FROM(k) from[k]
#endif

#define TYPE(t) printf("%s size=%zu align=%zu\n", #t, sizeof(t), _Alignof(t))
#define MEMBER(t, name, m) \
  printf("%s.%s offset=%zu size=%zu\n", #t, name, offsetof(t, m), \
         sizeof(((t *)0)->m))

int main(void) {
  TYPE(vu_enc_state);
  MEMBER(vu_enc_state, "min_enc_len", min_enc_len);
  MEMBER(vu_enc_state, "max_enc_len", max_enc_len);

  TYPE(vu_args);
  MEMBER(vu_args, "subject", subject);
  MEMBER(vu_args, "subject_len", subject_len);
  MEMBER(vu_args, "pos", pos);
  MEMBER(vu_args, "num", num);
  MEMBER(vu_args, "slot0", SLOT(0));
  MEMBER(vu_args, "slot1", SLOT(1));
  MEMBER(vu_args, "slot2", SLOT(2));
  MEMBER(vu_args, "slot3", SLOT(3));
  MEMBER(vu_args, "slot4", SLOT(4));

  TYPE(vu_fold_rec);
  MEMBER(vu_fold_rec, "calls", calls);
  MEMBER(vu_fold_rec, "recorded", recorded);
  MEMBER(vu_fold_rec, "from0", FROM(0));
  MEMBER(vu_fold_rec, "from1", FROM(1));
  MEMBER(vu_fold_rec, "from2", FROM(2));
  MEMBER(vu_fold_rec, "from3", FROM(3));
  MEMBER(vu_fold_rec, "from4", FROM(4));
  MEMBER(vu_fold_rec, "from5", FROM(5));
  MEMBER(vu_fold_rec, "from6", FROM(6));
  MEMBER(vu_fold_rec, "from7", FROM(7));
  return 0;
}
