import Data.List

data CList a = EmptyCL
                | CUnit a
                | Consnoc a (CList a) a deriving Show

-- EmptyCL :: CList a
-- CUnit :: a -> cList a
-- Cansnoc :: a -> CList a -> a -> CList a
--
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
                            where m = mapPrepend (inits l) x

mapPrepend :: Clist (Clist a) -> a -> CList (Clist a)
mapPrepend EmptyCL x = EmptyCL
mapPrepend (CUnit l) x = CUnit (prepend x l)
mapPrepend (Consnoc l1 ls l2) x = Consnoc (prepend x l1) (mapPrepend l2 x ) (consCl x l2)


prepend :: a -> CList a -> CList a
prepend x EmptyCL = CUnit x
prepend x (CUnit y) = prepend x EmptyCl y
prepend x (Consnoc a l b) = Consnoc x (prepend x l) b


tailCL :: CList a -> CList a
tailCL (CUnit x) = EmptyCL
tailCL (Consnoc x l y) = appendElem l y

test :: Int -> Char
test x = 'a'

main = do
    putStrLn $ show $  test 5
