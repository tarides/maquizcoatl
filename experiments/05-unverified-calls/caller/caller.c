/* caller.c: the C client of experiment #5. It supplies the function
   pointers of proto.h, calls the verified functions of one prototype
   (or of reference.c) and prints one line per check. The output must
   equal caller/expected.txt.

   Build: cc -std=c11 -I.. caller.c <prototype object or library>

   The client functions:
   - utf8_mbc_enc_len: upstream's UTF-8 mbc_enc_len (well-behaved,
     results in [1, 4]), copied below with its notice;
   - client_mbc_enc_len: the single-byte client encoding of experiment
     #4 (experiments/04-abi-feasibility/client_encoding.c on branch
     exp/04-abi-feasibility, function c_mbc_enc_len), well-behaved for
     bounds [1, 1];
   - bad_mbc_enc_len: a misbehaving encoding returning 0, -5, 100,
     INT_MIN and INT_MAX, so only the clamp keeps the result in range;
   - co_const: a callout returning a fixed value, for every value class
     of the branch rules and every direction;
   - co_slots: a callout calling vu_get_slot and vu_set_slot by name
     (re-entrancy shape (b));
   - client_apply_all: an apply_all_case_fold calling back the verified
     function it is given (re-entrancy shape (a)). */

#include <limits.h>
#include <stdio.h>
#include <string.h>
#include "proto.h"

/* The following table and function are copied from upstream/src/utf8.c
   at f95747b: EncLen_UTF8 (lines 47-68, keeping only the
   USE_RFC3629_RANGE arm, since line 33 defines that macro) and
   mbc_enc_len (lines 70-74), renamed. Their notice follows.

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

static const int EncLen_UTF8[] = {
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
  4, 4, 4, 4, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
};

static int
utf8_mbc_enc_len(const unsigned char* p)
{
  return EncLen_UTF8[*p];
}

/* End of the code copied from upstream. */

/* From experiment #4's client_encoding.c (c_mbc_enc_len). */
static int calls;
static int client_mbc_enc_len(const unsigned char* p) { (void)p; calls++; return 1; }

/* Misbehaving: the first byte selects the result. */
static int bad_mbc_enc_len(const unsigned char *p) {
  switch (*p) {
  case 0: return 0;
  case 1: return -5;
  case 2: return 100;
  case 3: return INT_MIN;
  default: return INT_MAX;
  }
}

static int failures;

static void check(int ok, const char *what) {
  if (!ok) {
    failures++;
    printf("  FAILED: %s\n", what);
  }
}

static void char_len(const char *name, vu_enc_len_fn f, unsigned char b,
                     int min, int max) {
  vu_enc_state st = {min, max};
  unsigned char buf[2] = {b, 0};
  int r = vu_char_len(f, buf, &st);
  printf("char_len %s byte=0x%02x bounds=[%d,%d] -> %d\n", name, b, min, max,
         r);
  check(st.min_enc_len == min && st.max_enc_len == max, "bounds unchanged");
  check(min <= r && r <= max, "result in bounds");
}

static const unsigned char subject[] = "abc";

static void init_args(vu_args *a) {
  memset(a, 0, sizeof *a);
  a->subject = subject;
  a->subject_len = 3;
  a->pos = 1;
  a->num = 1;
}

static int same_state(const vu_args *a, const vu_args *b) {
  return a->subject == b->subject && a->subject_len == b->subject_len &&
         a->pos == b->pos && a->num == b->num;
}

static int same_slots(const vu_args *a, const vu_args *b) {
  for (int k = 0; k < VU_SLOT_NUM; k++)
    if (a->slot[k] != b->slot[k])
      return 0;
  return 1;
}

static int co_calls;

static int co_const(vu_args *args, void *user_data) {
  (void)args;
  co_calls++;
  return *(const int *)user_data;
}

static const char *dir_name(int dir) {
  switch (dir) {
  case VU_DIR_PROGRESS: return "progress";
  case VU_DIR_RETRACTION: return "retraction";
  case VU_DIR_EACH_MATCH: return "each-match";
  default: return "invalid";
  }
}

static const char *action_name(int a) {
  switch (a) {
  case VU_ACT_CONTINUE: return "continue";
  case VU_ACT_BACKTRACK: return "backtrack";
  /* -1 is ONIG_MISMATCH: upstream's search loop moves on to the next
     start position instead of failing (upstream/src/regexec.c:5720-5727). */
  case VU_MISMATCH: return "mismatch";
  default: return a < 0 ? "error" : "?";
  }
}

static void callout(int dir, int value) {
  vu_args a, before;
  init_args(&a);
  before = a;
  co_calls = 0;
  int r = vu_callout_step(dir, co_const, &a, &value);
  printf("callout dir=%d:%s callee=%d -> %d (%s) calls=%d\n", dir,
         dir_name(dir), value, r, action_name(r), co_calls);
  check(same_state(&a, &before) && same_slots(&a, &before),
        "args unchanged");
}

/* Re-entrancy (b): the callout reads slot 0, writes slot 0 + 1 into it,
   copies it into slot 4, and probes both accessors out of bounds; a
   failing vu_get_slot must leave its output untouched. It returns the
   value user_data points to. callout_slots fills co_slots_status with
   CO_SLOTS_UNSET first, so a status the callout did not set shows. */
#define CO_SLOTS_UNSET 99
#define CO_SLOTS_PROBE 12345
static int co_slots_status[6];

static int co_slots(vu_args *args, void *user_data) {
  int64_t v = -1, probe = CO_SLOTS_PROBE;
  co_slots_status[0] = vu_get_slot(args, 0, &v);
  co_slots_status[1] = vu_set_slot(args, 0, v + 1);
  co_slots_status[2] = vu_set_slot(args, 4, v + 1);
  co_slots_status[3] = vu_get_slot(args, VU_SLOT_NUM, &probe);
  check(probe == CO_SLOTS_PROBE, "failing get_slot leaves *v untouched");
  co_slots_status[4] = vu_set_slot(args, -1, 7);
  co_slots_status[5] = vu_get_slot(args, INT_MIN, &probe);
  check(probe == CO_SLOTS_PROBE, "failing get_slot leaves *v untouched");
  return *(const int *)user_data;
}

static void callout_slots(int dir, int value, int64_t slot0) {
  vu_args a, before;
  init_args(&a);
  a.slot[0] = slot0;
  before = a;
  for (int k = 0; k < 6; k++)
    co_slots_status[k] = CO_SLOTS_UNSET;
  int r = vu_callout_step(dir, co_slots, &a, &value);
  printf("slots dir=%s callee=%d slot0=%lld -> %d (%s) status=%d,%d,%d,%d,%d,%d"
         " slots=%lld,%lld,%lld,%lld,%lld\n",
         dir_name(dir), value, (long long)slot0, r, action_name(r),
         co_slots_status[0], co_slots_status[1], co_slots_status[2],
         co_slots_status[3], co_slots_status[4], co_slots_status[5],
         (long long)a.slot[0], (long long)a.slot[1], (long long)a.slot[2],
         (long long)a.slot[3], (long long)a.slot[4]);
  check(same_state(&a, &before), "verified-side state unchanged");
}

/* Re-entrancy (a): the client walks a small fold table and calls back
   the verified function for each entry, stopping at the first non-zero
   result, as upstream's apply_all_case_fold implementations do. */
struct fold_entry {
  unsigned int from;
  int to_len;
  unsigned int to[4];
};

static const struct fold_entry fold_table[] = {
  {0x41, 1, {0x61}},
  {0x61, 1, {0x41}},
  {0xdf, 2, {0x73, 0x73}},
  {0x390, 3, {0x3b9, 0x308, 0x301}},
  {0x1e9e, 0, {0}},
  {0x2000, 4, {1, 2, 3, 4}},
  {0x2001, -1, {0}},
  {0x101, 1, {0x100}},
  {0x103, 1, {0x102}},
  {0x105, 1, {0x104}},
  {0x107, 1, {0x106}},
  {0x109, 1, {0x108}},
  {0x10b, 1, {0x10a}},
};

static int apply_all_calls;

static int client_apply_all(vu_apply_fn f, void *arg) {
  apply_all_calls++;
  for (size_t i = 0; i < sizeof fold_table / sizeof fold_table[0]; i++) {
    unsigned int to[4];
    memcpy(to, fold_table[i].to, sizeof to);
    int r = f(fold_table[i].from, to, fold_table[i].to_len, arg);
    if (r != 0)
      return r;
  }
  return 0;
}

static int client_apply_all_stop(vu_apply_fn f, void *arg) {
  unsigned int to[1] = {0x61};
  (void)f(0x41, to, 1, arg);
  return -7;
}

static void fold(const char *name, vu_apply_all_fn g, int calls0) {
  vu_fold_rec rec;
  memset(&rec, 0, sizeof rec);
  rec.calls = calls0;
  int r = vu_fold_all(g, &rec);
  printf("fold %s calls0=%d -> %d calls=%d recorded=%d from=", name, calls0,
         r, rec.calls, rec.recorded);
  for (int i = 0; i < rec.recorded; i++)
    printf("%s0x%x", i ? "," : "", rec.from[i]);
  printf("\n");
  check(0 <= rec.recorded && rec.recorded <= VU_FOLD_REC_MAX,
        "record within capacity");
}

int main(void) {
  static const unsigned char utf8_bytes[] = {0x41, 0x7f, 0x80, 0xc2,
                                             0xe3, 0xf0, 0xf4, 0xf5, 0xff};
  static const int values[] = {0, 1, 2, -1, -2, INT_MAX, INT_MIN};

  for (size_t i = 0; i < sizeof utf8_bytes; i++)
    char_len("utf8", utf8_mbc_enc_len, utf8_bytes[i], 1, 4);
  calls = 0;
  char_len("client", client_mbc_enc_len, 0x41, 1, 1);
  char_len("client", client_mbc_enc_len, 0xe3, 1, 1);
  printf("char_len client calls=%d\n", calls);
  for (unsigned char b = 0; b <= 4; b++) {
    char_len("bad", bad_mbc_enc_len, b, 1, 4);
    char_len("bad", bad_mbc_enc_len, b, 2, 3);
  }

  for (int dir = VU_DIR_PROGRESS; dir <= VU_DIR_EACH_MATCH; dir++)
    for (size_t i = 0; i < sizeof values / sizeof values[0]; i++)
      callout(dir, values[i]);
  callout(3, 0);
  callout(-1, 0);

  callout_slots(VU_DIR_PROGRESS, VU_CALLOUT_SUCCESS, 41);
  callout_slots(VU_DIR_RETRACTION, VU_CALLOUT_FAIL, -9);
  callout_slots(VU_DIR_PROGRESS, 2, 0);

  {
    int64_t v = 0;
    vu_args a;
    init_args(&a);
    int s = vu_set_slot(&a, 2, INT64_MIN);
    int g = vu_get_slot(&a, 2, &v);
    printf("direct set=%d get=%d value=%lld\n", s, g, (long long)v);
  }

  fold("table", client_apply_all, 0);
  fold("saturate", client_apply_all, INT_MAX - 2);
  fold("stop", client_apply_all_stop, 0);
  printf("fold apply_all calls=%d\n", apply_all_calls);

  printf("failures=%d\n", failures);
  return failures != 0;
}
