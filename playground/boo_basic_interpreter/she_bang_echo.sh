#! ./interpreter.py

# Result is zero
# This is a comment
   # This is also a comment
   #
# r = 2
r 2
# 0 -> r = 2
div
# 0 -> r = 2
diff
# 0 -> r = 2
div 0
# 0 -> r = 2
div 1
# 1 -> r = 3
sum 1
# 8 -> r = 11
sum 2 2 2 2
# 0 -> r = 11
diff 3 1 2
# -2 -> r = 9
diff 3 1 2 2
# Invalid operation
bling
# 0 -> r = 9
div 0 1 1
# 0 -> r = 9
div 2 0 0 0 0
# 64 -> r = 75
mult 2 2 2 2 2 2
# Invalid operation
blang
# Print result
p
# Compare result to 64 -> True
boo 64
# Set result to 65
r 65
# Compare result to 64 -> False
boo 64
# Print result
p

