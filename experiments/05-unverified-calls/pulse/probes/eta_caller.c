/* eta_caller.c: calls EtaD.eta_d with the arity of its F* signature. */
#include <stdint.h>
#include <stdio.h>
int32_t eta_d(int32_t (*g)(int32_t *), int32_t *a);
static int calls;
static int32_t g(int32_t *a) { calls++; return *a + 1; }
int main(void) {
  int32_t x = 41;
  int32_t r = eta_d(g, &x);
  printf("eta_d(g, &41) = %d, g called %d time(s); expected 42, 1\n", r, calls);
  return !(r == 42 && calls == 1);
}
