class Solution:
    def merge(self, nums1: list[int], m: int, nums2: list[int], n: int) -> None:
        if not nums2:
            return

        if not nums1:
            nums1.extend(nums2)
            return

        # I want to modify nums1.
        c = nums1.copy()
        nums1.clear()

        j = 0
        for i in range(m):
            while j < n and nums2[j] <= c[i]:
                nums1.append(nums2[j])
                j += 1
            nums1.append(c[i])

        for i in range(j, n):
            nums1.append(nums2[i])


if __name__ == "__main__":
    sol = Solution()

    nums1 = [1]
    m = 1
    nums2 = []
    n = 0
    sol.merge(nums1, m, nums2, n)
    print(nums1)

    nums1 = [1,2,3,0,0,0]
    m = 3
    nums2 = [2,5,6]
    n = 3
    sol.merge(nums1, m, nums2, n)
    print(nums1)

    nums1 = [0]
    m = 0
    nums2 = [1]
    n = 1
    sol.merge(nums1, m, nums2, n)
    print(nums1)

    nums1 = [2,0]
    m = 1
    nums2 = [1]
    n = 1
    sol.merge(nums1, m, nums2, n)
    print(nums1)

    nums1 = [4,5,6,0,0,0]
    m = 3
    nums2 = [1,2,3]
    n = 3
    sol.merge(nums1, m, nums2, n)
    print(nums1)

