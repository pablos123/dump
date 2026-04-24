-- Ejercicios de teoría.

import Data.Char
import Data.List

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

main = do
  let list = [2, 1, 2, 3, 4]
  print (takeWhile1 isEven list)
  print (dropWhile1 isEven list)
  print (span1 isEven list)
  print (span2 isEven list)
