/**
 * Note: The returned array must be malloced, assume caller calls free().
 */
int* twoSum(int* nums, int numsSize, int target, int* returnSize) {
    *returnSize = 2;
    int* ret_arr = malloc(8);
    int i, j;
    for (i = 0; i < numsSize; ++i) {
        for (j = i + 1; j < numsSize; ++j) {
            if (nums[i] + nums[j] == target) {
                ret_arr[0] = i;
                ret_arr[1] = j;
                return ret_arr;
            }
        }
    }
    return ret_arr;
}

