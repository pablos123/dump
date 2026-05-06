-- Ejercicios de teoría.
isEven :: Int -> Bool
isEven 0 = True
isEven x = even x -- mod x 2 == 0

takeWhile1 :: (a -> Bool) -> [a] -> [a]
takeWhile1 _ [] = []
takeWhile1 p (x : xs)
  | p x = x : takeWhile1 p xs
  | otherwise = []

dropWhile1 :: (a -> Bool) -> [a] -> [a]
dropWhile1 _ [] = []
dropWhile1 p (x : xs)
  | p x = dropWhile1 p xs
  | otherwise = x : xs

span1 :: (a -> Bool) -> [a] -> ([a], [a])
span1 _ [] = ([], [])
span1 p x = (takeWhile1 p x, dropWhile1 p x)

span2 :: (a -> Bool) -> [a] -> ([a], [a])
span2 _ [] = ([], [])
span2 p (x : xs)
  | p x = (x : y, z)
  | otherwise = ([], x : xs)
  where
    (y, z) = span2 p xs

-- Práctica 2
sumTwo :: (Num a) => a -> a
sumTwo x = x + 2

sumThree :: (Num a) => a -> a
sumThree x = x + 3

test :: (Num a, Eq a) => (a -> a) -> a -> Bool
test f x = f x == x + 2

-- 10.
-- a) [[ ]] ++ xs = xs
-- b) [[ ]] ++ xs = [xs ]
-- c) [[ ]] ++ xs = [ ] : xs
-- d) [[ ]] ++ xs = [[ ], xs ]
-- e) [[ ]] ++ [xs ] = [[ ], xs ]
-- f) [[ ]] ++ [xs ] = [xs ]
-- g) [ ] ++ xs = [ ] : xs
-- h) [ ] ++ xs = xs
-- i) [xs ] ++ [ ] = [xs ]
-- j) [xs ] ++ [xs ] = [xs, xs ]
--
-- 11.
-- a) modulus :: [Float] -> Float
-- b) vmod :: [[Float]] -> [Float]

type NumBin = [Bool]

xor :: Bool -> Bool -> Bool
xor a b = a && not b || not a && b

sumaBin :: NumBin -> NumBin -> NumBin
sumaBin [] b = b
sumaBin b [] = b
sumaBin b1 b2 = normalize (sumaBin' b1 b2 False)

sumaBin' :: NumBin -> NumBin -> Bool -> NumBin
sumaBin' [] b a = sumaBin b [a]
sumaBin' b [] a = sumaBin b [a]
sumaBin' (l1 : ls1) (l2 : ls2) a = let x = xor l1 l2 in xor x a : sumaBin' ls1 ls2 (if x && a then a else l1 && l2)

productoBin :: NumBin -> NumBin -> NumBin
productoBin [] b = b
productoBin b [] = b
productoBin [False] _ = [False]
productoBin _ [False] = [False]
productoBin [True] b = b
productoBin b [True] = b
productoBin l1 l2 = sumaBin l1 (productoBin l1 (normalize (restaUno l2)))

restaUno :: NumBin -> NumBin
restaUno [] = []
restaUno (True : ls) = False : ls
restaUno (False : ls) = True : restaUno ls

normalize :: NumBin -> NumBin
normalize [] = []
normalize (l : ls) = if not (or (l : ls)) then [] else l : normalize ls

cocienteDos :: NumBin -> NumBin
cocienteDos [] = []
cocienteDos (_ : ls) = ls

restoDos :: NumBin -> NumBin
restoDos [] = []
restoDos (l : _) = [l]

main :: IO ()
main = do
  -- Teoría
  let list = [2, 1, 2, 3, 4]
  print (takeWhile1 isEven list)
  print (dropWhile1 isEven list)
  print (span1 isEven list)
  print (span2 isEven list)

  -- Practica
  print "Suma Bin"
  print (sumaBin [True, True] [False, False])
  print (sumaBin [True, False, True] [True, False, True])
  print (sumaBin [True, True, True] [True, True, True])
  print (sumaBin [True, False, True] [True, True, True, True])
  print (sumaBin [True] [True, True])
  print (sumaBin [True] [True])

  print "Producto Bin"
  print (productoBin [True, False, True] [True, False, True])
  print (productoBin [False, True] [False, True])
  print (productoBin [False, True, False, True] [False, True, False, True])
