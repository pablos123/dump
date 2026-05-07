import Data.Char (digitToInt, isDigit)

-- 1)
type Color = (Double, Double, Double)

mezclar :: Color -> Color -> Color
mezclar (a, b, c) (d, e, f) = ((a + d) / 2, (b + e) / 2, (c + f) / 2)

-- 2)
type Linea = ([Char], Int)

vacia :: Linea
vacia = ([], 0)

moverIzq :: Linea -> Linea
moverIzq l@(_, 0) = l
moverIzq (l, i) = (l, i - 1)

moverDer :: Linea -> Linea
moverDer (l, i) = let len = length l in if i == len then (l, i) else (l, i + 1)

moverIni :: Linea -> Linea
moverIni (l, _) = (l, 0)

moverFin :: Linea -> Linea
moverFin (l, _) = (l, length l)

insertar :: Char -> Linea -> Linea
insertar c ([], _) = ([c], 1)
insertar c (l, cur) = (take cur l ++ [c] ++ drop (cur + 1) l, cur + 1)

borrar :: Linea -> Linea
borrar ([], _) = ([], 0)
borrar (l, cur) = (take (cur - 1) l ++ drop cur l, cur - 1)

insertarText :: [Char] -> Linea -> Linea
insertarText ss l = foldl (flip insertar) l ss

-- 3)
data CList a
  = EmptyCL
  | CUnit a
  | Consnoc a (CList a) a
  deriving (Show)

isEmpty :: CList a -> Bool
isEmpty EmptyCL = True
isEmpty _ = False

isCUnit :: CList a -> Bool
isCUnit (CUnit _) = True
isCUnit _ = False

headCL :: CList a -> a
headCL EmptyCL = error "Bad argument for headCL"
headCL (CUnit a) = a
headCL (Consnoc a _ _) = a

lastCL :: CList a -> a
lastCL EmptyCL = error "Bad argument for lastCL"
lastCL (CUnit a) = a
lastCL (Consnoc _ EmptyCL b) = b
lastCL (Consnoc _ l _) = lastCL l

appendElem :: CList a -> a -> CList a
appendElem EmptyCL x = CUnit x
appendElem (CUnit y) x = Consnoc y EmptyCL x
appendElem (Consnoc a l b) x = Consnoc a (appendElem l b) x

tailCL :: CList a -> CList a
tailCL EmptyCL = error "Bad argument for tailCL"
tailCL (CUnit _) = EmptyCL
tailCL (Consnoc _ l y) = appendElem l y

reverseCL :: CList a -> CList a
reverseCL EmptyCL = EmptyCL
reverseCL (CUnit x) = CUnit x
reverseCL (Consnoc a l b) = Consnoc b (reverseCL l) a

inits :: CList a -> CList (CList a)
inits EmptyCL = CUnit EmptyCL
inits (CUnit x) = Consnoc EmptyCL EmptyCL (CUnit x)
inits c@(Consnoc x l _) = Consnoc EmptyCL m c
  where
    m = mapPrepend (inits l) x

-- TODO: Revisar, probablemente esté mal el caso recursivo.
mapPrepend :: CList (CList a) -> a -> CList (CList a)
mapPrepend EmptyCL _ = EmptyCL
mapPrepend (CUnit l) x = CUnit (prepend x l)
mapPrepend (Consnoc l1 ls l2) x = Consnoc (prepend x l1) (mapPrepend (Consnoc l1 ls l2) x) (prepend x l2)

prepend :: a -> CList a -> CList a
prepend x EmptyCL = CUnit x
prepend x (CUnit _) = prepend x EmptyCL
prepend x (Consnoc _ l b) = Consnoc x (prepend x l) b

-- Definir una función concatCL que toma una CList de CList y devuelve la CList con todas ellas concatenadas
concatCL :: CList (CList a) -> CList a
concatCL EmptyCL = EmptyCL
concatCL (CUnit l) = l
concatCL c@(Consnoc l1 l l2) = concatCL' c EmptyCL

concatCL' :: CList (CList a) -> CList a -> CList a
concatCL' (Consnoc EmptyCL EmptyCL EmptyCL) ret = ret
concatCL' (Consnoc EmptyCL l EmptyCL) ret = concatCL' l (appendElem ret (headCL (headCL l)))
concatCL' (Consnoc EmptyCL l l2) ret = concatCL' (Consnoc EmptyCL l (tailCL l2)) (appendElem ret (headCL l2))
concatCL' (Consnoc l1 l EmptyCL) ret = concatCL' (Consnoc (tailCL l1) l EmptyCL) (appendElem ret (headCL l1))
concatCL' (Consnoc l1 l l2) ret = concatCL' (Consnoc (tailCL l1) l (tailCL l2)) (appendElem (appendElem ret (headCL l1)) (headCL l2))

-- 4)
data Exp = Lit Int | Add Exp Exp | Sub Exp Exp | Prod Exp Exp | Div Exp Exp deriving (Show)

eval :: Exp -> Int
eval (Lit a) = a
eval (Add a b) = eval a + eval b
eval (Sub a b) = eval a - eval b
eval (Prod a b) = eval a * eval b
eval (Div a b) = eval a `div` eval b

seval :: Exp -> Maybe Int
seval (Lit a) = Just a
seval (Add a b) =
  case (seval a, seval b) of
    (Just x, Just y) -> Just (x + y)
    _ -> Nothing
seval (Sub a b) =
  case (seval a, seval b) of
    (Just x, Just y) -> Just (x - y)
    _ -> Nothing
seval (Prod a b) =
  case (seval a, seval b) of
    (Just x, Just y) -> Just (x * y)
    _ -> Nothing
seval (Div a (Lit 0)) = Nothing
seval (Div a b) =
  case (seval a, seval b) of
    (Just x, Just y) -> Just (x `div` y)
    _ -> Nothing

-- 5
parseRPN :: String -> Exp
parseRPN [] = error "Empty expression"
parseRPN l = parseRPN' l []

parseRPN' :: String -> [Exp] -> Exp
parseRPN' [] ret = head ret -- Si queda un elemento en la pila entonces está bien formado y es la expresión.
parseRPN' (l : ls) ret
  | l == ' ' = parseRPN' ls ret
  | isDigit l = parseRPN' ls (Lit (digitToInt l) : ret)
  | otherwise = parseRPN' ls (createExp l (take 2 ret) : drop 2 ret)

createExp :: Char -> [Exp] -> Exp
createExp op (i : j : ls) = case op of
  '+' -> Add j i
  '-' -> Sub j i
  '*' -> Prod j i
  '/' -> Div j i

evalRPN :: String -> Int
evalRPN [] = error "Empty expression"
evalRPN e = eval (parseRPN e)

main :: IO ()
main = do
  print vacia
  print (insertar 'a' vacia)
  let text = insertarText "Hello World!" vacia
  print text
  print (borrar text)

  let test_clist = foldr (flip appendElem) EmptyCL [1 .. 10]
  print test_clist

  let cl3 = Consnoc (Consnoc 1 (CUnit 2) 3) (Consnoc (CUnit 4) EmptyCL (CUnit 5)) (CUnit 6)

  print (concatCL cl3)

  print (parseRPN "8 5 +")
  print (parseRPN "8 5 3 - 3 * +")
  print (evalRPN "8 5 3 - 3 * +")
