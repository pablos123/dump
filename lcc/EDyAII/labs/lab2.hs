{-
   Laboratorio 2
   EDyAII 2022
-}

{-
1) Dada la siguiente definición para representar árboles binarios:
-}

data BTree a = E | Leaf a | Node (BTree a) (BTree a)

{-
Definir las siguientes funciones:
a) altura, devuelve la altura de un árbol binario.
-}

altura :: BTree a -> Int
altura E = 0
altura (Leaf _) = 1
altura (Node l r) = 1 + max (altura l) (altura r)

-- b) perfecto, determina si un árbol binario es perfecto (un árbol binario es perfecto si cada nodo tiene 0 o 2 hijos
-- y todas las hojas están a la misma distancia desde la raı́z).

perfecto :: BTree a -> Bool
perfecto E = True
perfecto (Leaf _) = True
perfecto (Node l r) = fecto l && fecto r && altura l == altura r

fecto :: BTree a -> Bool
fecto E = False
fecto (Leaf _) = True
fecto (Node l r) = fecto l && fecto r && altura l == altura r

-- c) inorder, dado un árbol binario, construye una lista con el recorrido inorder del mismo.

inorder :: BTree a -> [a]
inorder E = []
inorder (Leaf a) = [a]
inorder (Node l r) = inorder l ++ inorder r

{-
2) Dada las siguientes representaciones de árboles generales y de árboles binarios (con información en los nodos):

Definir una función g2bt que dado un árbol nos devuelva un árbol binario de la siguiente manera:
la función g2bt reemplaza cada nodo n del árbol general (NodeG) por un nodo n' del árbol binario (NodeB), donde
el hijo izquierdo de n' representa el hijo más izquierdo de n, y el hijo derecho de n' representa al hermano derecho
de n, si existiese (observar que de esta forma, el hijo derecho de la raı́z es siempre vacı́o).

   Por ejemplo, sea t:

                    A
                 / | | \
                B  C D  E
               /|\     / \
              F G H   I   J
             /\       |
            K  L      M

   g2bt t =

                  A
                 /
                B
               / \
              F   C
             / \   \
            K   G   D
             \   \   \
              L   H   E
                     /
                    I
                   / \
                  M   J
-}

data GTree a = EG | NodeG a [GTree a] deriving (Show)

data BinTree a = EB | NodeB (BinTree a) a (BinTree a) deriving (Show)

g2bt :: GTree a -> BinTree a
g2bt EG = EB
g2bt (NodeG a l) = NodeB (g2bt' l) a EB

g2bt' :: [GTree a] -> BinTree a
g2bt' [] = EB
g2bt' ((NodeG a l) : ls) = NodeB (g2bt' l) a (g2bt' ls)

{-
3) Utilizando el tipo de árboles binarios definido en el ejercicio anterior, definir las siguientes funciones:
a) dcn, que dado un árbol devuelva la lista de los elementos que se encuentran en el nivel más profundo
    que contenga la máxima cantidad de elementos posibles. Por ejemplo, sea t:
          1
        /   \
        2     3
         \   / \
          4 5   6

    dcn t = [2, 3], ya que en el primer nivel hay un elemento, en el segundo 2 siendo este número la máxima
    cantidad de elementos posibles para este nivel y en el tercer nivel hay 3 elementos siendo la cantidad máxima 4.
-}

dcn :: BinTree a -> [a]
dcn EB = []
dcn t = getMaxLevel t 0

getMaxLevel :: BinTree a -> Int -> [a]
getMaxLevel t i = if length (getLevel [t] (i + 1)) /= 2 ^ (i + 1) then getLevel [t] i else getMaxLevel t (i + 1)

getLevel :: [BinTree a] -> Int -> [a]
getLevel l 0 = [x | (NodeB _ x _) <- l]
getLevel list i = getLevel [x | (NodeB l _ r) <- list, x <- [l, r]] (i - 1)

{-
b) maxn, que dado un árbol devuelva la profundidad del nivel completo más profundo. Por ejemplo, maxn t = 2
-}

maxn :: BinTree a -> Int
maxn EB = 0
maxn t = getMaxLevelInt t 0

getMaxLevelInt :: BinTree a -> Int -> Int
getMaxLevelInt t i = if length (getLevel [t] (i + 1)) /= 2 ^ (i + 1) then i else getMaxLevelInt t (i + 1)

{-
c) podar, que elimine todas las ramas necesarias para transformar el árbol en un árbol completo con la máxima altura posible.
Por ejemplo, podar t = NodeB (NodeB EB 2 EB) 1 (NodeB EB 3 EB)
-}

podar :: BinTree a -> BinTree a
podar EB = EB
podar (NodeB EB x EB) = NodeB EB x EB
podar (NodeB _ x EB) = NodeB EB x EB
podar (NodeB EB x _) = NodeB EB x EB
podar t = getUntilLevel t (maxn t)

getUntilLevel :: BinTree a -> Int -> BinTree a
getUntilLevel (NodeB _ x _) 0 = NodeB EB x EB
getUntilLevel (NodeB l x r) i = NodeB (getUntilLevel l (i - 1)) x (getUntilLevel r (i - 1))

main :: IO ()
main = do
  print (altura (Node (Leaf 3) (Node (Leaf 4) (Node (Leaf 3) (Leaf 3)))))
  print (altura (Node E E))
  print (perfecto (Node (Leaf 3) (Node (Leaf 4) (Node (Leaf 3) (Leaf 3)))))
  print (perfecto (Node (Node (Leaf 4) (Node (Leaf 3) (Leaf 3))) (Node (Leaf 4) (Node (Leaf 3) (Leaf 3)))))
  print (perfecto (Node (Node (Leaf 3) (Leaf 3)) (Node (Leaf 3) (Leaf 3))))
  print (perfecto (Node (Node E E) (Node (Leaf 3) (Leaf 3))))
  print (perfecto (Node (Node E E) (Leaf 1)))
  print (perfecto (Node E (Node (Leaf 3) (Leaf 3))))
  print (perfecto E)

  print (inorder (Node E (Node (Leaf 3) (Leaf 3))))
  print (inorder (Node E (Node (Leaf 3) (Leaf 5))))
  print (inorder (Node E (Node (Leaf 5) (Leaf 3))))
  print (inorder (Node (Node (Leaf 4) (Node (Leaf 3) (Leaf 3))) (Node (Leaf 4) (Node (Leaf 3) (Leaf 3)))))

  let example_bin_tree_1 = NodeB (NodeB (NodeB (NodeB EB 'K' (NodeB EB 'L' EB)) 'F' (NodeB EB 'G' (NodeB EB 'H' EB))) 'B' (NodeB EB 'C' (NodeB EB 'D' (NodeB (NodeB (NodeB EB 'M' EB) 'I' (NodeB EB 'J' EB)) 'E' EB)))) 'A' EB
  let example_bin_tree_2 = NodeB (NodeB (NodeB (NodeB EB 'K' (NodeB EB 'L' EB)) 'F' (NodeB EB 'G' (NodeB EB 'H' EB))) 'B' (NodeB EB 'C' (NodeB EB 'D' (NodeB (NodeB (NodeB EB 'M' EB) 'I' (NodeB EB 'J' EB)) 'E' EB)))) 'A' (NodeB (NodeB EB 't' EB) 't' (NodeB EB 't' EB))
  let t = NodeB (NodeB EB 2 (NodeB EB 4 EB)) 1 (NodeB (NodeB EB 5 EB) 3 (NodeB EB 6 EB))

  let example_general_tree_1 = NodeG 'A' [NodeG 'B' [NodeG 'F' [NodeG 'K' [], NodeG 'L' []], NodeG 'G' [], NodeG 'H' []], NodeG 'C' [], NodeG 'D' [], NodeG 'E' [NodeG 'I' [NodeG 'M' []], NodeG 'J' []]]
  print (g2bt example_general_tree_1)
  print (getLevel [example_bin_tree_1] 0)
  print (getLevel [example_bin_tree_1] 3)
  print (getLevel [example_bin_tree_1] 12)
  print (dcn EB :: [Int])
  print (dcn example_bin_tree_1)
  print (dcn example_bin_tree_2)
  print (dcn t)
  print (maxn t)
  print (podar t)
