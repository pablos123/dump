import Data.List

is_even :: Int -> Bool
is_even 0 = True
is_even x = mod x 2 == 0

takeWhile1 :: (a -> Bool) -> [a] -> [a]
takeWhile1 p [] = []
takeWhile1 p (x:xs) | p x = x:takeWhile1 p xs
                    | otherwise = []

dropWhile1 :: (a -> Bool) -> [a] -> [a]
dropWhile1 p [] = []
dropWhile1 p (x:xs)  | p x = dropWhile1 p xs
                     | otherwise = x:xs

span1 :: (a -> Bool) -> [a] -> ([a], [a])
span1 p [] = ([], [])
span1 p (x) = (takeWhile1 p x, dropWhile1 p x)

span2 :: (a -> Bool) -> [a] -> ([a], [a])
span2 p [] = ([], [])
span2 p (x:xs) | p x = (x:y, z)
               | otherwise =  ([], x:xs)
               where (y, z) = span2 p xs

main = do
    let list = [2,1,2,3,4]
    putStrLn $ show $ takeWhile1 is_even list
    putStrLn $ show $ dropWhile1 is_even list
    putStrLn $ show $ span1 is_even list
    putStrLn $ show $ span2 is_even list
