import Data.List (sortBy)

data NdTree p
  = Node
      (NdTree p) -- sub-árbol izquierdo
      p -- punto
      (NdTree p) -- sub-árbol derecho
      Int -- eje
  | Empty
  deriving (Eq, Ord)

-- 1)
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
  coord _ (P2d _) = error "Bad axis for Punto2d"

instance Punto Punto3d where
  dimension _ = 3
  coord 0 (P3d (i, _, _)) = i
  coord 1 (P3d (_, j, _)) = j
  coord 2 (P3d (_, _, k)) = k
  coord _ (P3d _) = error "Bad axis for Punto3d"

instance Eq Punto2d where
  P2d (i, j) == P2d (k, l) = (i == k) && (j == l)

instance Eq Punto3d where
  P3d (i, j, k) == P3d (l, m, n) = (i == l) && (j == m) && (k == n)

-- 2)
-- Construye un árbol a partir de una lista de puntos.
fromList :: (Punto p) => [p] -> NdTree p
fromList [] = Empty
fromList xs = fromList' xs 0 (dimension (head xs))

-- Construye un árbol a partir de una lista, la altura donde comienza a armar el árbol y la dimensión de los puntos del árbol.
fromList' :: (Punto p) => [p] -> Int -> Int -> NdTree p
fromList' [] _ _ = Empty
fromList' xs h dim =
  -- Seleccionar el eje sobre el cual se alineará el hiperplano.
  let eje = h `mod` dim
      sorted = sortBy (\x y -> compare (coord eje x) (coord eje y)) xs
      -- Calcular la mediana de la la lista de puntos, según el eje seleccionado.
      med_ind = length sorted `div` 2

      med = sorted !! med_ind
      med_c = coord eje med
      r_list = drop (med_ind + 1) sorted
      -- Tomo los puntos que tienen su valor igual al valor en el eje de la mediana de la lista de los valores posteriores al índice de la mediana.
      r_list_equal = takeWhile (\x -> coord eje x == med_c) r_list
      -- Crear un árbol l con los puntos de la lista que tienen como valor en el eje seleccionado
      -- un valor menor o igual al valor en el eje de la mediana.
      l = fromList' (take med_ind sorted ++ r_list_equal) (h + 1) dim
      -- Crear un árbol r con los puntos de la lista que tienen como valor en el eje seleccionado
      -- un valor mayor al valor en el eje de la mediana.
      r = fromList' (drop (length r_list_equal) r_list) (h + 1) dim
   in -- Crear un nodo del árbol que tenga como raíz la mediana, como eje el eje seleccionado, como subárbol izquierdo el árbol l y como subárbol derecho el árbol r.
      Node l med r eje

-- 3)
-- Agrega un nuevo punto a un árbol
insertar :: (Punto p) => p -> NdTree p -> NdTree p
insertar p Empty = Node Empty p Empty 0 -- Si es vacío.
insertar p (Node Empty pt r e) -- Si solo tiene hijo derecho.
-- Si la coordenada en el eje e es menor o igual a la coordenada del nodo en el mismo eje. Reemplazo el árbol vacío por el nuevo nodo.
  | coord e p <= coord e pt = Node (Node Empty p Empty ((e + 1) `mod` dimension pt)) pt r e
  -- Si no, inserto el nuevo nodo en el árbol derecho.
  | otherwise = Node Empty pt (insertar p r) e
insertar p (Node l pt Empty e) -- Si solo tiene hijo izquierdo.
-- Si la coordenada en el eje e es mayor a la coordenada del nodo en el mismo eje. Reemplazo el árbol vacío por el nuevo nodo.
  | coord e p > coord e pt = Node l pt (Node Empty p Empty ((e + 1) `mod` dimension pt)) e
  -- Si no, inserto el nuevo nodo en el árbol izquierdo.
  | otherwise = Node (insertar p l) pt Empty e
insertar p (Node l pt r e) -- Si tiene ambos hijos.
-- Si la coordenada en el eje e es mayor a la coordenada del nodo en el mismo eje. Inserto a derecha.
  | coord e p > coord e pt = Node l pt (insertar p r) e
  -- Si no, inserto el nuevo nodo en el árbol izquierdo.
  | otherwise = Node (insertar p l) pt r e

-- 4)
-- Elimina un punto de un árbol.
eliminar :: (Eq p, Punto p) => p -> NdTree p -> NdTree p
eliminar _ Empty = Empty -- Si el árbol es vacío, no hay nada que eliminar.
eliminar p n@(Node Empty pt Empty e) -- Si no tiene hijos.
-- Sólo elimino si conciden.
  | p == pt = Empty
  -- Si no. No existe en el árbol.
  | otherwise = n
eliminar p n@(Node l pt Empty e) -- Si no tiene hijo derecho.
-- Se encontró el dato a eliminar. Reemplazarlo por un candidato del árbol izquierdo.
  | p == pt = replaceLeft n
  -- Si la coordenada del punto a eliminar es menor a la coordenada del nodo: eliminar sobre el único hijo.
  | coord e p <= coord e pt = Node (eliminar p l) pt Empty e
  -- Si no. No existe en el árbol.
  | otherwise = n
eliminar p n@(Node l pt r e) -- Si tiene hijo derecho.
-- Se encontró el dato a eliminar. Reemplazarlo por un candidato del árbol derecho.
  | p == pt = replaceRight n
  -- Si la coordenada del punto a eliminar es mayor a la coordenada del nodo eliminar sobre el hijo derecho.
  | coord e p > coord e pt = Node l pt (eliminar p r) e
  -- Si no, eliminar sobre el hijo izquierdo.
  | otherwise = Node (eliminar p l) pt r e

-- Reemplaza la raíz de un árbol por un nodo del hijo izquierdo.
-- El nodo candidato que busca del hijo izquierdo es alguno de los que tienen la mayor coordenada en el eje de la raíz.
replaceLeft :: (Eq p, Punto p) => NdTree p -> NdTree p
replaceLeft (Node l pt Empty e) = let bigger = getBigger l e in Node (eliminar bigger l) bigger Empty e
replaceLeft _ = error "Bad node for eliminarFoundLeft"

-- Reemplaza la raíz de un árbol por un nodo del hijo derecho.
-- Los nodos candidatos que se buscan del hijo derecho son los que tienen la menor coordenada en el eje de la raíz.
-- El primer elemento de la lista de candidatos es usado como reemplazo de la raíz del árbol.
-- El resto de los nodos de la lista de candidatos los elimina de la derecha y los vuelve a insertar a la izquierda para no perder la invariante.
replaceRight :: (Eq p, Punto p) => NdTree p -> NdTree p
replaceRight (Node l pt r e) =
  let candidatos = getSmallers r e in Node (foldl (flip insertar) l (tail candidatos)) (head candidatos) (foldl (flip eliminar) r candidatos) e

-- Encuentra en un árbol el punto con la mayor coordenada en un eje.
getBigger :: (Eq p, Punto p) => NdTree p -> Int -> p
getBigger Empty _ = error "Bad node for getBigger"
-- Si no tiene sub-árboles entonces la raíz es el punto con mayor coordenada.
getBigger (Node Empty p Empty _) _ = p
-- Si no tiene sub-árbol derecho me quedo con el mayor entre el punto y el mayor del sub-árbol izquierdo.
getBigger (Node l p Empty _) e = let bigger_left = getBigger l e in if coord e bigger_left > coord e p then bigger_left else p
-- Si no tiene sub-árbol izquierdo me quedo con el mayor entre el punto y el mayor del sub-árbol derecho.
getBigger (Node Empty p r _) e = let bigger_right = getBigger r e in if coord e bigger_right > coord e p then bigger_right else p
-- Si tiene los dos sub-árboles me quedo con el mayor de los tres.
getBigger (Node l p r _) e =
  let bigger_left = getBigger l e
      bigger_right = getBigger r e
      cl = coord e bigger_left
      cr = coord e bigger_right
   in case coord e p of
        x
          | x >= cl && x >= cr -> p
          | cl >= x && cl >= cr -> bigger_left
          | otherwise -> bigger_right

-- Encuentra en un árbol todos los puntos con la menor coordenada en un eje.
getSmallers :: (Eq p, Punto p) => NdTree p -> Int -> [p]
getSmallers Empty _ = []
-- Si no tiene sub-árboles entonces la raíz es el punto con menor coordenada.
getSmallers (Node Empty p Empty _) _ = [p]
-- Si no tiene sub-árbol derecho obtengo los menores del sub-árbol izquierdo.
getSmallers (Node l p Empty _) e =
  let smallers_left = getSmallers l e
      -- Sea cl la coordenada en el eje e de todos los menores del sub-árbol izquierdo. En particular tomo la cabeza de los menores.
      cl = coord e (head smallers_left)
   in case coord e p of
        x
          -- Si x es mayor a cl, devolvemos los menores del hijo izquierdo.
          | cl < x -> smallers_left
          -- Si x es menor que cl, entonces la raíz es el menor del árbol.
          | x < cl -> [p]
          -- Si coinciden entonces devolver la lista con la raíz y los menores del hijo izquierdo.
          | otherwise -> p : smallers_left
-- Si no tiene sub-árbol izquierdo obtengo los menores del sub-árbol derecho.
getSmallers (Node Empty p r _) e =
  let smallers_right = getSmallers r e
      -- Sea cr la coordenada en el eje e de todos los menores del sub-árbol derecho. En particular tomo la cabeza de los menores.
      cr = coord e (head smallers_right)
   in case coord e p of
        x
          -- Si x es mayor a cr, devolvemos los menores del hijo derecho.
          | cr < x -> smallers_right
          -- Si x es menor que cr, entonces la raíz es el menor del árbol.
          | x < cr -> [p]
          -- Si coinciden entonces devolver la lista con la raíz y los menores del hijo derecho.
          | otherwise -> p : smallers_right
-- Si tiene los dos sub-árboles me quedo con los menores de los tres.
getSmallers (Node l p r _) e =
  let smallers_left = getSmallers l e
      smallers_right = getSmallers r e
      -- Sea cl la coordenada en el eje e de todos los menores del sub-árbol izquierdo. En particular tomo la cabeza de los menores.
      cl = coord e (head smallers_left)
      -- Sea cr la coordenada en el eje e de todos los menores del sub-árbol derecho. En particular tomo la cabeza de los menores.
      cr = coord e (head smallers_right)
   in case coord e p of
        x
          -- Si cl es el menor de los tres entonces devolvemos los menores del hijo izquierdo.
          | cl < x && cl < cr -> smallers_left
          -- Si cr es el menor de los tres entonces devolvemos los menores del hijo derecho.
          | cr < x && cr < cl -> smallers_right
          -- Si x es el menor de los tres entonces la raíz es el menor del árbol.
          | x < cl && x < cr -> [p]
          -- En estos casos al menos dos, son iguales.
          -- Si cl == cr entonces devuelvo la lista de los menores del hijo izquierdo y los menores del hijo derecho.
          | x > cl -> smallers_left ++ smallers_right
          -- Si x == cr entonces devuelvo la lista de la raíz y los menores del hijo derecho.
          | cl > x -> p : smallers_right
          -- Si x == cl entonces devuelvo la lista de la raíz y los menores del hijo izquierdo.
          | cr > x -> p : smallers_left
          -- Si x == cl == cr entonces devuelvo la lista con todos.
          | otherwise -> p : smallers_left ++ smallers_right

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
