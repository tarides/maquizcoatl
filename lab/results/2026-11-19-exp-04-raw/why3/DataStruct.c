#include <stdint.h>


struct syn {
  int32_t op;
  int32_t op2;
};

struct syn onigsyntaxruby() {
  struct syn syn;
  syn.op = 1;
  syn.op2 = 2;
  return syn;
}

int32_t get_op() {
  return onigsyntaxruby().op;
}
