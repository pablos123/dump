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

-- 2)
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

-- 3)
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

-- 4)
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

-- 5)
type Rect = (Punto2d, Punto2d)

-- Definir una función inRegion : Punto2d → Rect → Bool, que determine si un punto de dos dimensiones
-- está dentro de un rectángulo.
inRegion :: Punto2d -> Rect -> Bool
inRegion p rect = inRegionAxis p rect 0 && inRegionAxis p rect 1

inRegionAxis :: Punto2d -> Rect -> Int -> Bool
inRegionAxis (P2d (x, _)) (P2d (ax, _), P2d (bx, _)) 0 = x <= max ax bx && x >= min ax bx
inRegionAxis (P2d (_, y)) (P2d (_, ay), P2d (_, by)) 1 = y <= max ay by && y >= min ay by

-- Definir una función ortogonalSearch :: NdTree Punto2d → Rect → [Punto2d], que dado un conjunto s de
-- puntos en el plano y un rectángulo, encuentre los puntos de s que están dentro del rectángulo dado.
ortogonalSearch :: NdTree Punto2d -> Rect -> [Punto2d]
ortogonalSearch Empty _ = []
ortogonalSearch (Node l p@(P2d (x, y)) r e) rect@(P2d (ax, _), _)
  | inRegion p rect = p : ortogonalSearch l rect ++ ortogonalSearch r rect
  | inRegionAxis p rect e = ortogonalSearch l rect ++ ortogonalSearch r rect
  | otherwise = if x < ax then ortogonalSearch r rect else ortogonalSearch l rect

main :: IO ()
main = do
  -- =========================
  -- TESTS EJERCICIO 1
  -- =========================

  print "=== Ejercicio 1 ==="

  print (coord 0 (P2d (3, 4)))
  print (coord 1 (P2d (3, 4)))
  print (dimension (P2d (3, 4)))

  print (coord 0 (P3d (1, 2, 3)))
  print (coord 2 (P3d (1, 2, 3)))
  print (dimension (P3d (1, 2, 3)))

  print (dist (P2d (0, 0)) (P2d (3, 4)))
  print (dist (P2d (1, 1)) (P2d (1, 1)))
  print (dist (P3d (0, 0, 0)) (P3d (1, 2, 2)))

  print (dist (P2d (2, 2)) (P2d (2, 5)))
  print (dist (P2d (-1, -1)) (P2d (1, 1)))

  -- =========================
  -- TESTS EJERCICIO 2
  -- =========================

  print "=== Ejercicio 2 ==="

  print (fromList ([] :: [Punto2d]))
  print (fromList [P2d (1, 1)])
  print (fromList [P2d (1, 1), P2d (2, 2)])

  print (fromList [P2d (5, 4), P2d (2, 3), P2d (9, 6)])
  print (fromList [P2d (9, 6), P2d (5, 4), P2d (2, 3)])

  print (fromList [P2d (2, 2), P2d (2, 3), P2d (2, 4)])

  print (fromList [P2d (1, 1), P2d (1, 1), P2d (1, 1)])

  print (fromList [P2d (1, 2), P2d (3, 4), P2d (5, 6), P2d (7, 8), P2d (9, 1), P2d (2, 3), P2d (4, 5), P2d (6, 7)])

  -- =========================
  -- TESTS EJERCICIO 3
  -- =========================

  print "=== Ejercicio 3 ==="

  print (insertar (P2d (1, 1)) Empty)

  let t_ins = fromList [P2d (5, 5)]
  print (insertar (P2d (3, 3)) t_ins)
  print (insertar (P2d (7, 7)) t_ins)

  let t1 = insertar (P2d (3, 3)) t_ins
  let t2 = insertar (P2d (7, 7)) t1
  let t3 = insertar (P2d (4, 4)) t2
  print t3

  print (insertar (P2d (5, 5)) t_ins)

  let t_same_axis = fromList [P2d (2, 2), P2d (2, 3)]
  print (insertar (P2d (2, 4)) t_same_axis)

  -- =========================
  -- TESTS EJERCICIO 4
  -- =========================

  print "=== Ejercicio 4 ==="

  let t_del1 = fromList [P2d (2, 3), P2d (5, 4), P2d (9, 6)]
  print t_del1
  print (eliminar (P2d (2, 3)) t_del1)

  print (eliminar (P2d (5, 4)) t_del1)

  let t_left = fromList [P2d (5, 5), P2d (3, 3)]
  print (eliminar (P2d (5, 5)) t_left)

  let t_right = fromList [P2d (5, 5), P2d (7, 7)]
  print (eliminar (P2d (5, 5)) t_right)

  let t_not_found = fromList [P2d (1, 1), P2d (2, 2)]
  print (eliminar (P2d (9, 9)) t_not_found)

  let t_dups = fromList [P2d (1, 1), P2d (1, 1), P2d (1, 1)]
  print (eliminar (P2d (1, 1)) t_dups)

  let t_big = fromList [P2d (2, 3), P2d (5, 4), P2d (9, 6), P2d (4, 7), P2d (8, 1), P2d (7, 2)]

  print (eliminar (P2d (7, 2)) t_big)
  print (eliminar (P2d (4, 7)) t_big)
  print (eliminar (P2d (8, 1)) t_big)

  let t_chain0 = fromList [P2d (2, 3), P2d (5, 4), P2d (9, 6), P2d (4, 7), P2d (8, 1), P2d (7, 2)]

  let t_chain1 = eliminar (P2d (2, 3)) t_chain0
  let t_chain2 = eliminar (P2d (5, 4)) t_chain1
  let t_chain3 = eliminar (P2d (7, 2)) t_chain2
  print t_chain3

  -- =========================
  -- OTROS
  -- =========================

  print "=== Stress Tests ==="

  let t_same_x = fromList [P2d (2, 1), P2d (2, 2), P2d (2, 3), P2d (2, 4)]
  print t_same_x
  print (eliminar (P2d (2, 2)) t_same_x)

  let t_mix = fromList [P2d (1, 1), P2d (1, 1), P2d (2, 2)]
  print t_mix
  print (eliminar (P2d (1, 1)) t_mix)

  let t_single = fromList [P2d (1, 1)]
  print t_single
  print (eliminar (P2d (1, 1)) t_single)

  let t_foldl = foldl (flip insertar) Empty [P2d (2.0, 3.0), P2d (3.0, 4.0), P2d (3.0, 3.0), P2d (3.5, 3.5), P2d (5.0, 6.0)]
  print t_foldl

  print "Ejercicio 5"
  let rect1 = (P2d (0, 0), P2d (1, 1))
  let rect2 = (P2d (0, 0), P2d (5, 5))
  let rect3 = (P2d (1, 1), P2d (0, 0))
  print (inRegion (P2d (0, 0.5)) rect1)
  print (inRegion (P2d (0, 0.5)) rect2)
  print (inRegion (P2d (0, 0.5)) rect3)
  print (inRegion (P2d (-1, 0.5)) rect3)

  print (ortogonalSearch t_foldl rect1)
  print (ortogonalSearch t_foldl rect2)

  print "aaaaaaaaaaaaaaa"
