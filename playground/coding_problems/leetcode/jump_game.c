#define M(a, b) a > b ? a : b
char canJump(int *n, int s) {
  int i = 0, d = 0;
  --s;
  for (; i < s; ++i) {
    d = M(n[i], d);
    if (!d--)
      return 0;
  }
  return 1;
}
