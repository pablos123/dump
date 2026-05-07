-- 1)
data Tree a = Leaf | Node (Tree a) a (Tree a) deriving (Show)

-- Dado un valor x de tipo a y un entero d, crea un árbol binario completo de altura d
-- con el valor x en cada nodo.
completo :: a -> Int -> Tree a
completo x 0 = Node Leaf x Leaf
completo x d = Node tree x tree where tree = completo x (d - 1)

-- Dado un valor x de tipo a y un entero n, crea un árbol binario balanceado
-- de tamaño n, con el valor x en cada nodo.

balanceado :: a -> Int -> Tree a
balanceado x 0 = Leaf
balanceado x d
  | even d = Node treeEven x treeEven'
  | otherwise = Node treeOdd x treeOdd
  where
    treeOdd = balanceado x ((d - 1) `div` 2)
    treeEven = balanceado x (d `div` 2)
    treeEven' = balanceado x ((d - 2) `div` 2)

-- 2)
-- 1. maximum :: Ord a ⇒ BST a → a, que calcula el máximo valor en un bst.
-- 2. checkBST :: Ord a ⇒ BST a → Bool, que chequea si un árbol binario es un bst.
-- 3. splitBST :: Ord a ⇒ BST a → a → (BST a, BST a), que dado un árbol bst t y un elemento x , devuelva una
-- tupla con un bst con los elementos de t menores o iguales a x y un bst con los elementos de t mayores a x .
-- 4. join :: Ord a ⇒ BST a → BST a → BST a, que una los elementos dos árboles bst en uno.

data BST a = Hoja | Nodo (BST a) a (BST a) deriving (Show)

maximunBST :: (Ord a) => BST a -> a
maximunBST Hoja = error "Not defined"
maximunBST (Nodo _ x Hoja) = x
maximunBST (Nodo _ _ r) = maximunBST r

minimunBST :: (Ord a) => BST a -> a
minimunBST Hoja = error "Not defined"
minimunBST (Nodo Hoja x _) = x
minimunBST (Nodo l _ _) = minimunBST l

checkBST :: (Ord a) => BST a -> Bool
checkBST Hoja = True
checkBST (Nodo Hoja _ Hoja) = True
checkBST (Nodo l x Hoja) = checkBST l && x >= maximunBST l
checkBST (Nodo Hoja x r) = checkBST r && x < minimunBST r
checkBST (Nodo l x r) = checkBST l && checkBST r && x >= maximunBST l && x < minimunBST r

splitBST :: (Ord a) => BST a -> a -> (BST a, BST a)
splitBST Hoja _ = error "Not defined"
splitBST t@(Nodo Hoja v Hoja) x = if v <= x then (t, Hoja) else (Hoja, t)
splitBST (Nodo l v r) x = if v <= x then (Nodo l v rightSplittedL, rightSplittedR) else (leftSplittedL, Nodo leftSplittedR v r)
  where
    (rightSplittedL, rightSplittedR) = splitBST r x
    (leftSplittedL, leftSplittedR) = splitBST l x

join :: (Ord a) => BST a -> BST a -> BST a
join Hoja Hoja = Hoja
join t Hoja = t
join Hoja t = t
join (Nodo l1 v1 r1) r = Nodo (join l1 spl) v1 (join r1 spr) where (spl, spr) = splitBST r v1

main :: IO ()
main = do
  print "Hello"
  print (completo 1 2)
  print (balanceado 1 2)
  print (balanceado 1 6)
  print (balanceado 1 7)
