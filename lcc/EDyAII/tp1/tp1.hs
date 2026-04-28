import Data.List (sortBy)

data NdTree p
  = Node
      (NdTree p) -- sub´arbol izquierdo
      p -- punto
      (NdTree p) -- sub´arbol derecho
      Int -- eje
  | Empty
  deriving (Eq, Ord, Show)

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
   in Node (fromList' (take m_ind sorted) (i + 1) d) (sorted !! m_ind) (fromList' (drop (m_ind + 1) sorted) (i + 1) d) eje

main :: IO ()
main = do
  let test_p2d = P2d (1, 2)
  let test_p3d = P3d (1, 2, 3)
  let test_list_p2d = [P2d (2, 3), P2d (5, 4), P2d (9, 6), P2d (4, 7), P2d (8, 1), P2d (7, 2)]
  let test_list_p2d_1 = [P2d (2, 3), P2d (5, 4), P2d (9, 6)]
  let test_list_p2d_2 = [P2d (5, 4), P2d (2, 3), P2d (9, 6)]

  print test_p2d
  print (coord 1 test_p2d)
  print (dimension test_p2d)
  print (dist test_p2d test_p2d)

  print test_p3d
  print (coord 2 test_p3d)
  print (dimension test_p3d)
  print (dist test_p3d test_p3d)

  print (fromList test_list_p2d)
  print (fromList test_list_p2d_1)
  print (fromList test_list_p2d_2)
