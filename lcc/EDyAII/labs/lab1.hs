-- module Lab01 where

{-
1) Corregir los siguientes programas de modo que sean aceptados por GHCi.
-}

-- a)
-- Estaba mal la identación.
-- not definido en el preludio
-- Luego, como no se usa el nombre not, se puede usar en la función.
-- case innecesario
--
-- not b = case b of
--   True -> False
--     False -> True
--
-- not' b = if b then False else True
--
-- not' b = not b
not' :: Bool -> Bool
not' = not

-- b)
-- in es palabra reservada
--
-- in [x]         =  []
-- in (x:xs)      =  x : in xs
-- in []          =  error "empty list"
inside :: [a] -> [a]
inside [_] = []
inside [_, _] = []
inside (_ : xs) = head xs : inside xs
inside [] = error "empty list"

-- c)
-- length ya está definida en el preludio
-- Las funciones no pueden empezar en mayúsculas.
--
-- Length []        =  0
-- Length (_:l)     =  1 + Length l
len :: [a] -> Int
len [] = 0
len (_ : l) = 1 + len l

-- d)
-- : espera una lista, estoy pasando ([])
--
-- list123 = (1 : 2) : 3 : []
-- list123 = [1, 2, 3]

-- e)
-- : probablemente tenga más precedencia que ++!
-- No lo entiendo. TODO
-- [] ++! ys = ys
-- (x : xs) ++! ys = x : xs ++! ys

-- f)
addToTail :: (Num a) => a -> [a] -> [a]
addToTail _ [x] = [x]
addToTail x (l : ls) = l : map (+ x) ls
addToTail _ [] = []

-- g)
-- . es composición de funciones
-- También se puede hacer con $: listMin xs = head . sort xs
-- listMin xs = head $ sort xs
-- Luego recomienda usar minimun
--
-- listMin xs = head . sort xs
-- listMin xs = (head . sort) xs
-- listMin xs = minimum xs
listMin :: (Ord a) => [a] -> a
listMin = minimum

-- h) (*)
smap :: (a -> b) -> [a] -> [b]
smap _ [] = []
smap f [x] = [f x]
smap f (x : xs) = f x : smap f xs

multMap :: (a -> a) -> [a] -> [a]
multMap _ [] = []
multMap f [x] = [f x]
multMap f (x : xs) = f x : multMap f (multMap f xs)

{-
2. Definir las siguientes funciones y determinar su tipo:

a) five, que dado cualquier valor, devuelve 5

b) apply, que toma una función y un valor, y devuelve el resultado de
aplicar la función al valor dado

c) ident, la función identidad

d) first, que toma un par ordenado, y devuelve su primera componente

e) derive, que aproxima la derivada de una función dada en un punto dado

f) sign, la función signo

g) vabs, la función valor absoluto (usando sign y sin usarla)

h) pot, que toma un entero y un número, y devuelve el resultado de
elevar el segundo a la potencia dada por el primero

i) xor, el operador de disyunción exclusiva

j) max3, que toma tres números enteros y devuelve el máximo entre llos

k) swap, que toma un par y devuelve el par con sus componentes invertidas
-}

five :: a -> Int
five _ = 5

apply :: (a -> b) -> a -> b
apply f = f

ident :: a -> a
ident x = x

first :: (a, b) -> a
first (a, _) = a

derive :: (Fractional a) => (a -> a) -> a -> a -> a
derive f x h = (f (x + h) - f x) / h

sign :: (Num a, Eq a, Ord a) => a -> Int
sign x
  | x == 0 = 0
  | x > 0 = 1
  | otherwise = -1

vabs :: (Num a, Ord a, Eq a) => a -> a
vabs x
  | sign x == 0 = 0
  | sign x == 1 = x
  | otherwise = x * (-1)

vabs1 :: (Num a, Eq a, Ord a) => a -> a
vabs1 x
  | x == 0 = 0
  | x > 0 = x
  | otherwise = x * (-1)

pot :: forall a. (Floating a) => a -> a -> a
pot a x = x ** a

xor :: Bool -> Bool -> Bool
xor a b = a && not b || not a && b

max3 :: Int -> Int -> Int -> Int
max3 a b c = max a (max b c)

swap :: (a, b) -> (b, a)
swap (a, b) = (b, a)

{-
3) Definir una función que determine si un año es bisiesto o no, de
acuerdo a la siguiente definición:

año bisiesto 1. m. El que tiene un día más que el año común, añadido al mes de febrero. Se repite
cada cuatro años, a excepción del último de cada siglo cuyo número de centenas no sea múltiplo
de cuatro. (Diccionario de la Real Academia Espaola, 22ª ed.)

¿Cuál es el tipo de la función definida?
-}

{-
Si aplicamos nuestra regla actual hacia el pasado (lo que se llama Año bisiesto proléptico),
los matemáticos dicen que los años 100, 200 y 300 no deberían contarse como bisiestos para que
los cálculos astronómicos modernos cuadren, pero en la realidad histórica,
la gente de esa época sí los vivió como años de 366 días.
-}

bisiesto :: Int -> Bool
bisiesto a = if mod a 100 == 0 then mod a 400 == 0 else mod a 4 == 0

{-
4)

Defina un operador infijo *$ que implemente la multiplicación de un
vector por un escalar. Representaremos a los vectores mediante listas
de Haskell. Así, dada una lista ns y un número n, el valor ns *$ n
debe ser igual a la lista ns con todos sus elementos multiplicados por
n. Por ejemplo,

[ 2, 3 ] *$ 5 == [ 10 , 15 ].

El operador *$ debe definirse de manera que la siguiente
expresión sea válida:

v = [1, 2, 3] *$ 2 *$ 4

-}

--  (por defecto tendrá infixl 9)
(*$) :: (Num a) => [a] -> a -> [a]
(*$) l a = map (* a) l

v :: (Num a) => [a]
v = [1, 2, 3] *$ 2 *$ 4

{-
5) Definir las siguientes funciones usando listas por comprensión:

a) 'divisores', que dado un entero positivo 'x' devuelve la
lista de los divisores de 'x' (o la lista vacía si el entero no es positivo)

b) 'matches', que dados un entero 'x' y una lista de enteros descarta
de la lista los elementos distintos a 'x'

c) 'cuadrupla', que dado un entero 'n', devuelve todas las cuadruplas
'(a,b,c,d)' que satisfacen a^2 + b^2 = c^2 + d^2,
donde 0 <= a, b, c, d <= 'n'

(d) 'unique', que dada una lista 'xs' de enteros, devuelve la lista
'xs' sin elementos repetidos
-}

divisores :: Int -> [Int]
divisores a = [x | x <- [1 .. a], mod a x == 0]

matches :: [Int] -> Int -> [Int]
matches l a = [x | x <- l, x == a]

cuadrupla :: Int -> [(Int, Int, Int, Int)]
cuadrupla a = [(x, y, z, w) | x <- [0 .. a], y <- [0 .. a], z <- [0 .. a], w <- [0 .. a], (x * x) + (y * y) == (z * z) + (w * w)]

unique :: [Int] -> [Int]
unique xs = [x | (x, i) <- zip xs [0 ..], x `notElem` take i xs]

{-
6) El producto escalar de dos listas de enteros de igual longitud
es la suma de los productos de los elementos sucesivos (misma
posición) de ambas listas.  Definir una función 'scalarProduct' que
devuelva el producto escalar de dos listas.

Sugerencia: Usar las funciones 'zip' y 'sum'.
-}

scalarProduct :: [Int] -> [Int] -> Int
scalarProduct l1 l2 = sum [x * y | (x, y) <- zip l1 l2]

{-
7) Definir mediante recursión explícita
las siguientes funciones y escribir su tipo más general:

a) 'suma', que suma todos los elementos de una lista de números

b) 'alguno', que devuelve True si algún elemento de una
lista de valores booleanos es True, y False en caso
contrario

c) 'todos', que devuelve True si todos los elementos de
una lista de valores booleanos son True, y False en caso
contrario

d) 'codes', que dada una lista de caracteres, devuelve la
lista de sus ordinales

e) 'restos', que calcula la lista de los restos de la
división de los elementos de una lista de números dada por otro
número dado

f) 'cuadrados', que dada una lista de números, devuelva la
lista de sus cuadrados

g) 'longitudes', que dada una lista de listas, devuelve la
lista de sus longitudes

h) 'orden', que dada una lista de pares de números, devuelve
la lista de aquellos pares en los que la primera componente es
menor que el triple de la segunda

i) 'pares', que dada una lista de enteros, devuelve la lista
de los elementos pares

j) 'letras', que dada una lista de caracteres, devuelve la
lista de aquellos que son letras (minúsculas o mayúsculas)

k) 'masDe', que dada una lista de listas 'xss' y un
número 'n', devuelve la lista de aquellas listas de 'xss'
con longitud mayor que 'n' -}

main :: IO ()
main = do
  -- 1
  print "Ejercicio 1-------------------------------"

  print (not' False)

  print (inside [1, 2, 3, 4])
  print (inside [1, 2])

  print (len [1, 2])

  print (addToTail 3 [1, 2, 3])

  print (listMin [1, 2, 0, 3])

  print (smap (+ 5) [1, 2, 0, 3])
  print (multMap (+ 5) [1, 2, 0, 3])

  -- 2
  print "Ejercicio 2-------------------------------"

  print (five [1, 2, 0, 3])

  print (apply map (+ 5) [1, 2, 0, 3])

  print (ident [1, 2, 0, 3])

  print (first (1, 2))
  print (first ([1, 2, 0, 3], 2))

  print "Derivada|Aprox"
  print (cos 0, derive sin 0 0.00001)
  print "Derivada|Aprox"
  print (cos 1, derive sin 1 0.00001)
  print "Derivada|Aprox"
  print (cos pi, derive sin pi 0.00001)

  print (sign 45)
  print (sign (-2))
  print (sign 0)

  print (vabs (-2))
  print (vabs 2)
  print (vabs1 0)
  print (vabs1 (-3))

  print (pot 3 3)
  print (pot 8 2)

  print (xor False False)
  print (xor True True)
  print (xor False True)
  print (xor True False)

  print (max3 3 4 5)
  print (max3 5 4 3)

  print (swap (3, 4))

  -- 3
  print "Ejercicio 3-------------------------------"
  print (bisiesto 1900)
  print (bisiesto 2024)
  print (bisiesto 200)
  print (bisiesto 200)

  -- 4
  print "Ejercicio 4-------------------------------"
  print v

  -- 5
  print "Ejercicio 5-------------------------------"
  print (divisores 5)
  print (divisores 24)

  print (matches [1, 2, 3, 4, 5, 5, 5, 5, 6] 5)
  print (matches [1, 2, 3, 4, 5, 5, 5, 5, 6] 2)

  print (cuadrupla 7)

  print (unique [1, 2, 3, 44, 4, 4, 1])

  -- 6
  print "Ejercicio 6-------------------------------"
  print (scalarProduct [1, 2, 4] [2, 3, 4])
