#include <stdio.h>

void merge(int *n1, int n1s, int m, int *n2, int n2s, int n) {
  if (n == 0)
    return;
  if (m == 0) {
    n1 = n2;
    return;
  }

  for (int i = n; i; --i) {
    if (n2[i] >= n1[i])
      n1[n1s--] = n2[i];
  }
}

void print_arr(int *nums, int size) {
  for (int i = 0; i < size; ++i) {
    printf("%d", nums[i]);
  }
  printf("\n");
}

int main() {
  int m, n;

  int nums1[] = {1};
  m = 1;
  int nums2[] = {};
  n = 0;
  merge(nums1, 1, m, nums2, n, n);
  print_arr(nums1, 1);

  int nums3[] = {1, 2, 3, 0, 0, 0};
  m = 3;
  int nums4[] = {2, 5, 6};
  n = 3;
  merge(nums3, 6, m, nums4, n, n);
  print_arr(nums3, 6);

  int nums5[] = {0};
  m = 0;
  int nums6[] = {1};
  n = 1;
  merge(nums5, 1, m, nums6, n, n);
  print_arr(nums5, 1);

  int nums7[] = {2, 0};
  m = 1;
  int nums8[] = {1};
  n = 1;
  merge(nums7, 2, m, nums8, n, n);
  print_arr(nums7, 2);

  int nums9[] = {4, 5, 6, 0, 0, 0};
  m = 3;
  int nums10[] = {1, 2, 3};
  n = 3;
  merge(nums9, 6, m, nums10, n, n);
  print_arr(nums9, 6);

  return 0;
}
