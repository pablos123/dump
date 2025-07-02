#!/usr/bin/env python3

# Get the sum of the odd numbers of a list
nl = [1,2,3,4,5,5,6,7,8,123,3,4,5,213,6,2,45,2135,2,45,145,1,1,6,7,7,8]

# Basic
ts = 0
for i in nl:
    if not i % 2:
        ts += i
print(ts)

# Get primes smaller than a given number
n = 27
def primes(n):
    if n < 3:
        return

    print(2)

    for i in range(3, n):
        y = 1
        for j in range(2, i):
            if not i % j:
                y = 0
                break
        if y:
            print(i)
primes(n)
