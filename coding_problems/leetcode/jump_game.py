#!/bin/python3

class Solution:
    def canJump(self, nums: list[int]) -> bool:
        dummy = 0
        length = len(nums) - 1
        for i, n in enumerate(nums):
            if i == length:
                break

            if n >= dummy:
                dummy = n

            if not dummy:
                return False

            dummy -= 1
        return True

if __name__ == "__main__":

    solution = Solution()
    input = [1, 2, 3, 4]
    input1 = [2, 3, 1, 1, 4] # true
    input2 = [3, 2, 1, 0, 4] # false
    input3 = [3, 3, 1, 0, 4] # true

    print(solution.canJump(nums=input))
    print(solution.canJump(nums=input1))
    print(solution.canJump(nums=input2))
    print(solution.canJump(nums=input3))
