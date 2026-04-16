import Data.Char
import Data.List

-- Ejercicios de teoría.
isEven :: Int -> Bool
isEven 0 = True
isEven x = even x -- mod x 2 == 0

takeWhile1 :: (a -> Bool) -> [a] -> [a]
takeWhile1 p [] = []
takeWhile1 p (x : xs)
  | p x = x : takeWhile1 p xs
  | otherwise = []

dropWhile1 :: (a -> Bool) -> [a] -> [a]
dropWhile1 p [] = []
dropWhile1 p (x : xs)
  | p x = dropWhile1 p xs
  | otherwise = x : xs

span1 :: (a -> Bool) -> [a] -> ([a], [a])
span1 p [] = ([], [])
span1 p x = (takeWhile1 p x, dropWhile1 p x)

span2 :: (a -> Bool) -> [a] -> ([a], [a])
span2 p [] = ([], [])
span2 p (x : xs)
  | p x = (x : y, z)
  | otherwise = ([], x : xs)
  where
    (y, z) = span2 p xs

-- Práctica 1
sumTwo :: (Num a) => a -> a
sumTwo x = x + 2

sumThree :: (Num a) => a -> a
sumThree x = x + 3

test :: (Num a, Eq a) => (a -> a) -> a -> Bool
test f x = f x == x + 2

main = do
  -- Teoría
  let list = [2, 1, 2, 3, 4]
  print (takeWhile1 isEven list)
  print (dropWhile1 isEven list)
  print (span1 isEven list)
  print (span2 isEven list)

  print ()
  print ((+ 1) 3)
