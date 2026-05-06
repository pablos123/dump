-- data RGB = Color Double Double Double
type Color = (Double, Double, Double)

mezclar :: Color -> Color -> Color
mezclar (a, b, c) (d, e, f) = ((a + d) / 2, (b + e) / 2, (c + f) / 2)

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

data CList a
  = EmptyCL
  | CUnit a
  | Consnoc a (CList a) a
  deriving (Show)

-- EmptyCL :: CList a
-- CUnit :: a -> cList a
-- Cansnoc :: a -> CList a -> a -> CList a

appendElem :: CList a -> a -> CList a
appendElem EmptyCL x = CUnit x
appendElem (CUnit y) x = Consnoc y EmptyCL x
appendElem (Consnoc a l b) x = Consnoc a (appendElem l b) x

reverseCL :: CList a -> CList a
reverseCL EmptyCL = EmptyCL
reverseCL (CUnit x) = CUnit x
reverseCL (Consnoc a l b) = Consnoc b (reverseCL l) a

inits :: CList a -> CList (CList a)
inits EmptyCL = CUnit EmptyCL
inits (CUnit x) = Consnoc EmptyCL EmptyCL (CUnit x)
inits c@(Consnoc x l y) = Consnoc EmptyCL m c
  where
    m = mapPrepend (inits l) x

mapPrepend :: CList (CList a) -> a -> CList (CList a)
mapPrepend EmptyCL x = EmptyCL
mapPrepend (CUnit l) x = CUnit (prepend x l)
mapPrepend (Consnoc l1 ls l2) x = undefined

prepend :: a -> CList a -> CList a
prepend x EmptyCL = CUnit x
prepend x (CUnit y) = prepend x EmptyCL
prepend x (Consnoc a l b) = Consnoc x (prepend x l) b

tailCL :: CList a -> CList a
tailCL (CUnit x) = EmptyCL
tailCL (Consnoc x l y) = appendElem l y

main :: IO ()
main = do
  print vacia
  print (insertar 'a' vacia)
  let text = insertarText "Hello World!" vacia
  print text
  print (borrar text)
