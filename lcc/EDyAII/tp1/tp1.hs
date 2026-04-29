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
eliminar = undefined

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
