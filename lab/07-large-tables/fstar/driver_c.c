/* Experiment #7 driver for the C targets: driver <queries> <answers>. */
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#ifndef FN
#define FN TableC_ctype_mem
#endif
extern bool FN(uint32_t ct, uint32_t c);
int main(int argc, char** argv) {
  FILE *q = fopen(argv[1], "r"), *a = fopen(argv[2], "w");
  unsigned ct, c;
  while (fscanf(q, "%u %u", &ct, &c) == 2) fprintf(a, "%d\n", FN(ct, c) ? 1 : 0);
  fclose(a);
  return 0;
}
