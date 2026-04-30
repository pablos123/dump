import Data.List (sortBy)

data NdTree p
  = Node
      (NdTree p) -- sub´arbol izquierdo
      p -- punto
      (NdTree p) -- sub´arbol derecho
      Int -- eje
  | Empty
  deriving (Eq, Ord)

instance (Show p) => Show (NdTree p) where
  show Empty = " . "
  -- show (Node Empty p Empty e) = " (" ++ " h " ++ show p ++ " h " ++ show e ++ ") "
  show (Node l p r e) =
    " (" ++ show l ++ " <- " ++ show p ++ " -> " ++ show r ++ show e ++ ") "

class Punto p where
  -- devuelve el número de coordenadas de un punto
  dimension :: p -> Int

  -- devuelve la coordenada k-ésima de un punto (comenzando de 0)
  coord :: Int -> p -> Double

  -- calcula la distancia entre dos puntos
  dist :: p -> p -> Double
  dist x y = sqrt (sum [(coord c y - coord c x) ** 2 | c <- [0 .. dimension x - 1]])

newtype Punto2d = P2d (Double, Double) deriving (Show)

newtype Punto3d = P3d (Double, Double, Double) deriving (Show)

instance Punto Punto2d where
  dimension _ = 2
  coord 0 (P2d (i, _)) = i
  coord 1 (P2d (_, j)) = j
  coord _ (P2d _) = error "Bad index for Punto2d"

instance Punto Punto3d where
  dimension _ = 3
  coord 0 (P3d (i, _, _)) = i
  coord 1 (P3d (_, j, _)) = j
  coord 2 (P3d (_, _, k)) = k
  coord _ (P3d _) = error "Bad index for Punto3d"

instance Eq Punto2d where
  P2d (i, j) == P2d (k, l) = (i == k) && (j == l)

instance Eq Punto3d where
  P3d (i, j, k) == P3d (l, m, n) = (i == l) && (j == m) && (k == n)

fromList :: (Punto p) => [p] -> NdTree p
fromList [] = Empty
fromList xs = fromList' xs 0 (dimension (head xs))

fromList' :: (Punto p) => [p] -> Int -> Int -> NdTree p
fromList' [] _ _ = Empty
fromList' xs i d =
  let eje = i `mod` d
      sorted = sortBy (\x y -> compare (coord eje x) (coord eje y)) xs
      m_ind = length sorted `div` 2
      m_punto = sorted !! m_ind
      m_value_p = coord eje m_punto
      r_list = drop (m_ind + 1) sorted
   in Node (fromList' (take m_ind sorted ++ takeWhile (\x -> coord eje x == m_value_p) r_list) (i + 1) d) m_punto (fromList' (dropWhile (\x -> coord eje x == m_value_p) r_list) (i + 1) d) eje

insertar :: (Punto p) => p -> NdTree p -> NdTree p
insertar p Empty = Node Empty p Empty 0
insertar p (Node Empty pt r e)
  | coord e p <= coord e pt = Node (Node Empty p Empty ((e + 1) `mod` dimension pt)) pt r e
  | otherwise = Node Empty pt (insertar p r) e
insertar p (Node l pt Empty e)
  | coord e p > coord e pt = Node l pt (Node Empty p Empty ((e + 1) `mod` dimension pt)) e
  | otherwise = Node (insertar p l) pt Empty e
insertar p (Node l pt r e)
  | coord e p > coord e pt = Node l pt (insertar p r) e
  | otherwise = Node (insertar p l) pt r e

eliminar :: (Eq p, Punto p) => p -> NdTree p -> NdTree p
eliminar _ Empty = Empty
eliminar p n@(Node Empty pt Empty e)
  | p == pt = Empty
  | otherwise = n
eliminar p n@(Node l pt Empty e)
  | p == pt = eliminarFoundLeft n
  | coord e p <= coord e pt = Node (eliminar p l) pt Empty e
  | otherwise = n
eliminar p n@(Node l pt r e)
  | p == pt = eliminarFoundRight n
  | coord e p > coord e pt = Node l pt (eliminar p r) e
  | otherwise = Node (eliminar p l) pt r e

eliminarFoundLeft :: (Eq p, Punto p) => NdTree p -> NdTree p
eliminarFoundLeft (Node l pt Empty e) =
  let biggerSmallers = getBiggers l e
      candidato = head biggerSmallers
   in Node (eliminar candidato l) candidato Empty e
eliminarFoundLeft _ = error "Bad node for eliminarFoundLeft"

eliminarFoundRight :: (Eq p, Punto p) => NdTree p -> NdTree p
eliminarFoundRight (Node l pt r e) =
  let smallerBiggers = getSmallers r e
      candidato = head smallerBiggers
      toMovePoints = tail smallerBiggers
   in Node (foldl (flip insertar) l toMovePoints) candidato (foldl (flip eliminar) r smallerBiggers) e

getBiggers :: (Eq p, Punto p) => NdTree p -> Int -> [p]
getBiggers Empty _ = []
getBiggers (Node Empty p Empty _) _ = [p]
getBiggers (Node l p Empty _) e =
  let leftListBiggers = getBiggers l e
      c = coord e p
      cl = coord e (head leftListBiggers)
   in case c of
        x
          | cl > x -> leftListBiggers
          | x > cl -> [p]
          | otherwise -> p : leftListBiggers
getBiggers (Node Empty p r _) e =
  let rightListBiggers = getBiggers r e
      c = coord e p
      cr = coord e (head rightListBiggers)
   in case c of
        x
          | cr > x -> rightListBiggers
          | x > cr -> [p]
          | otherwise -> p : rightListBiggers
getBiggers (Node l p r _) e =
  let leftListBiggers = getBiggers l e
      rightListBiggers = getBiggers r e
      c = coord e p
      cl = coord e (head leftListBiggers)
      cr = coord e (head rightListBiggers)
   in case c of
        x
          | cl > x && cl > cr -> leftListBiggers
          | cr > x && cr > cl -> rightListBiggers
          | x > cl && x > cr -> [p]
          | x < cl -> leftListBiggers ++ rightListBiggers
          | cl < x -> p : rightListBiggers
          | cr < x -> p : leftListBiggers
          | otherwise -> p : leftListBiggers ++ rightListBiggers

getSmallers :: (Eq p, Punto p) => NdTree p -> Int -> [p]
getSmallers Empty _ = []
getSmallers (Node Empty p Empty _) _ = [p]
getSmallers (Node l p Empty _) e =
  let leftListSmallers = getSmallers l e
      c = coord e p
      cl = coord e (head leftListSmallers)
   in case c of
        x
          | cl < x -> leftListSmallers
          | x < cl -> [p]
          | otherwise -> p : leftListSmallers
getSmallers (Node Empty p r _) e =
  let rightListSmallers = getSmallers r e
      c = coord e p
      cr = coord e (head rightListSmallers)
   in case c of
        x
          | cr < x -> rightListSmallers
          | x < cr -> [p]
          | otherwise -> p : rightListSmallers
getSmallers (Node l p r _) e =
  let leftListSmallers = getSmallers l e
      rightListSmallers = getSmallers r e
      c = coord e p
      cl = coord e (head leftListSmallers)
      cr = coord e (head rightListSmallers)
   in case c of
        x
          | cl < x && cl < cr -> leftListSmallers
          | cr < x && cr < cl -> rightListSmallers
          | x < cl && x < cr -> [p]
          | x > cl -> leftListSmallers ++ rightListSmallers
          | cl > x -> p : rightListSmallers
          | cr > x -> p : leftListSmallers
          | otherwise -> p : leftListSmallers ++ rightListSmallers

main :: IO ()
main = do
  let test_p2d = P2d (1, 2)
  let test_p2d_1 = P2d (1, 5)
  let test_p3d = P3d (1, 2, 3)
  let test_list_p2d = [P2d (2, 3), P2d (5, 4), P2d (9, 6), P2d (4, 7), P2d (8, 1), P2d (7, 2)]
  let test_list_p2d_1 = [P2d (2, 3), P2d (5, 4), P2d (9, 6)]
  let test_list_p2d_2 = [P2d (5, 4), P2d (2, 3), P2d (9, 6)]
  let test_list_p2d_3 = [P2d (2, 2), P2d (2, 3), P2d (2, 4)]

  let test_tree = fromList test_list_p2d_2
  let test_tree_1 = fromList test_list_p2d

  print "Ejercicio 1. Puntos 2D"
  print "==========="
  print test_p2d
  print (coord 1 test_p2d)
  print (dimension test_p2d)
  print (dist test_p2d test_p2d)
  print "==========="

  print "Ejercicio 1. Puntos 3D"
  print "==========="
  print test_p3d
  print (coord 2 test_p3d)
  print (dimension test_p3d)
  print (dist test_p3d test_p3d)
  print "==========="

  print "Ejercicio 2."
  print "==========="
  print (fromList test_list_p2d)
  print (fromList test_list_p2d_1)
  print (fromList test_list_p2d_3)
  print "==========="

  print "Ejercicio 3"
  print "==========="
  print (insertar test_p2d test_tree)
  print (insertar test_p2d_1 test_tree_1)
  print (insertar test_p2d_1 (insertar test_p2d_1 test_tree_1))
  print "==========="

  print (eliminar (P2d (5, 4)) test_tree)
