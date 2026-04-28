import Data.List

type Texto = String

{-
   Definir una función que dado un caracter y un texto calcule la frecuencia
   con la que ocurre el caracter en el texto
   Por ejemplo: frecuency 'a' "casa" = 0.5
-}

frecuency :: Char -> Texto -> Float
frecuency c "" = 0
frecuency c t = fromIntegral (length [x | x <- t, x == c]) / fromIntegral (length t)

{-
  Definir una función frecuencyMap que dado un texto calcule la frecuencia
  con la que ocurre cada caracter del texto en éste.
  La lista resultado debe estar ordenada respecto a la frecuencia con la que ocurre
  cada caracter, de menor a mayor frecuencia.

  Por ejemplo: frecuencyMap "casa" = [('c',0.25),('s',0.25),('a',0.5)]

-}

frecuencyMap :: Texto -> [(Char, Float)]
frecuencyMap "" = []
frecuencyMap t = sortBy (\(_, a) (_, b) -> compare a b) [(x, frecuency x t) | x <- unique t]

unique :: (Ord a) => [a] -> [a]
unique [] = []
unique l = generateUniqueList l []

generateUniqueList :: (Ord a) => [a] -> [a] -> [a]
generateUniqueList [] ret = ret
generateUniqueList (l : ls) ret = if not (isIn ret l) then generateUniqueList ls (l : ret) else generateUniqueList ls ret

isIn :: (Eq a) => [a] -> a -> Bool
isIn [] _ = False
isIn l v = or [x == v | x <- l]

{-
  Definir una función subconjuntos, que dada una lista xs devuelva una lista
  con las listas que pueden generarse con los elementos de xs.

  Por ejemplo: subconjuntos [2,3,4] = [[2,3,4],[2,3],[2,4],[2],[3,4],[3],[4],[]]
-}

subconjuntos :: [a] -> [[a]]
subconjuntos [] = [[]]
subconjuntos (l : ls) = generateSubset l ls ++ subconjuntos ls

generateSubset :: a -> [a] -> [[a]]
generateSubset x [] = [[x]]
generateSubset x (l : ls) = (x : l : ls) : generateSubset x ls

{-
 Definir una función intercala :: a -> [a] -> [[a]]
 tal que (intercala x ys) contiene las listas que se obtienen
 intercalando x entre los elementos de ys.

 Por ejemplo: intercala 1 [2,3]  ==  [[1,2,3],[2,1,3],[2,3,1]]
-}

intercala :: a -> [a] -> [[a]]
intercala _ [] = []
intercala x l = intercala' x l 0 (length l)

intercala' :: a -> [a] -> Int -> Int -> [[a]]
intercala' x l i j
  | i == j = [l ++ [x]]
  | otherwise = (getUntil i l ++ [x] ++ getFrom i l) : intercala' x l (i + 1) j

getUntil :: Int -> [a] -> [a]
getUntil 0 _ = []
getUntil i (l : ls) = l : getUntil (i - 1) ls

getFrom :: Int -> [a] -> [a]
getFrom i = getFrom' i 0

getFrom' :: Int -> Int -> [a] -> [a]
getFrom' 0 _ l = l
getFrom' i j (l : ls)
  | i == j = l : ls
  | otherwise = getFrom' i (j + 1) ls

{-
  Definir una función permutaciones que dada una lista calcule todas las permutaciones
  posibles de sus elementos. Ayuda: la función anterior puede ser útil.

  Por ejemplo: permutaciones "abc" = ["abc","bac","cba","bca","cab","acb"]
-}

permutaciones :: [a] -> [[a]]
permutaciones [] = []
permutaciones l = undefined

main :: IO ()
main = do
  print (frecuency 'a' "")
  print (frecuency 'a' "casa")
  print (unique "casa")
  print (frecuencyMap "casa")
  print (subconjuntos "casa")
  print (subconjuntos [2, 3, 4])
  print (intercala 1 [2, 3, 4])
  print (intercala 1 [2, 3])
  print (intercala 1 [])
  print (intercala 'a' "cac")
  print (intercala 'a' "bc")

  print (permutaciones [1, 2])
  print (permutaciones "abc")
  print (permutaciones "nachito")

-- print (permutaciones "nachito el mas capito")
