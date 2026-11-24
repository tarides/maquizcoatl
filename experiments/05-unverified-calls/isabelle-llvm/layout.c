/* layout.c: checks at compile time that the struct types of vu.ll have
   the layout of proto.h's structs.

   VU.thy writes each struct of proto.h as nested pairs, which
   Isabelle-LLVM emits as nested LLVM literal structs (see abi.expected,
   which pins those types in vu.ll). The ll_* types below are the same
   nested structs written in C; on x86-64, with the data layout vu.ll
   declares, LLVM lays a literal struct out as C does. That these C
   types mirror the LLVM ones is trusted (listed in TRUSTED); that they
   match proto.h is checked here. */

#include <stddef.h>
#include <stdint.h>

#include "proto.h"

/* { i32, i32 } */
struct ll_enc_state {
  int32_t mn;
  int32_t mx;
};

/* { { i8*, { i32, i32 } }, { i32, { i64, { i64, { i64, { i64, i64 } } } } } } */
struct ll_args {
  struct {
    const unsigned char *subject;
    struct {
      int32_t subject_len;
      int32_t pos;
    } t;
  } hd;
  struct {
    int32_t num;
    struct {
      int64_t s0;
      struct {
        int64_t s1;
        struct {
          int64_t s2;
          struct {
            int64_t s3;
            int64_t s4;
          } t;
        } t;
      } t;
    } t;
  } tl;
};

/* { i32, { i32, { i32, { i32, { i32, { i32, { i32, { i32, { i32, i32 } } } } } } } } } */
struct ll_fold_rec {
  int32_t calls;
  struct {
    int32_t recorded;
    struct {
      int32_t f0;
      struct {
        int32_t f1;
        struct {
          int32_t f2;
          struct {
            int32_t f3;
            struct {
              int32_t f4;
              struct {
                int32_t f5;
                struct {
                  int32_t f6;
                  int32_t f7;
                } t;
              } t;
            } t;
          } t;
        } t;
      } t;
    } t;
  } t;
};

#define SAME(t1, t2) \
  _Static_assert(sizeof(t1) == sizeof(t2) && _Alignof(t1) == _Alignof(t2), \
                 #t1 " and " #t2 ": size or alignment differ")
#define AT(t1, f1, t2, f2) \
  _Static_assert(offsetof(t1, f1) == offsetof(t2, f2), \
                 #t1 "." #f1 " and " #t2 "." #f2 ": offsets differ")

SAME(vu_enc_state, struct ll_enc_state);
AT(vu_enc_state, min_enc_len, struct ll_enc_state, mn);
AT(vu_enc_state, max_enc_len, struct ll_enc_state, mx);

SAME(vu_args, struct ll_args);
AT(vu_args, subject, struct ll_args, hd.subject);
AT(vu_args, subject_len, struct ll_args, hd.t.subject_len);
AT(vu_args, pos, struct ll_args, hd.t.pos);
AT(vu_args, num, struct ll_args, tl.num);
AT(vu_args, slot[0], struct ll_args, tl.t.s0);
AT(vu_args, slot[1], struct ll_args, tl.t.t.s1);
AT(vu_args, slot[2], struct ll_args, tl.t.t.t.s2);
AT(vu_args, slot[3], struct ll_args, tl.t.t.t.t.s3);
AT(vu_args, slot[4], struct ll_args, tl.t.t.t.t.s4);

SAME(vu_fold_rec, struct ll_fold_rec);
AT(vu_fold_rec, calls, struct ll_fold_rec, calls);
AT(vu_fold_rec, recorded, struct ll_fold_rec, t.recorded);
AT(vu_fold_rec, from[0], struct ll_fold_rec, t.t.f0);
AT(vu_fold_rec, from[1], struct ll_fold_rec, t.t.t.f1);
AT(vu_fold_rec, from[2], struct ll_fold_rec, t.t.t.t.f2);
AT(vu_fold_rec, from[3], struct ll_fold_rec, t.t.t.t.t.f3);
AT(vu_fold_rec, from[4], struct ll_fold_rec, t.t.t.t.t.t.f4);
AT(vu_fold_rec, from[5], struct ll_fold_rec, t.t.t.t.t.t.t.f5);
AT(vu_fold_rec, from[6], struct ll_fold_rec, t.t.t.t.t.t.t.t.f6);
AT(vu_fold_rec, from[7], struct ll_fold_rec, t.t.t.t.t.t.t.t.f7);

/* An empty translation unit is not ISO C. */
typedef int vu_layout_checked;
