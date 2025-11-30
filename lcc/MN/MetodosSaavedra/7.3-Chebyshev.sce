// Devuelve nodos de interpolación para aproximar la función con lagrange o newton luego

// Todas las raíces están entre -1 y 1
// Devuelve el polinomio de chebyshev de grado n
function polinomio = polinomio_chebyshev(n)
    if n == 0 then
        polinomio = 1
        return 
    end
    
    equis = poly([0, 1], "x", "c")
    polinomios = [1, equis]
    
    for i = 3:n + 1
        polinomios(i) = 2 * equis * polinomios(i -1) - polinomios(i - 2)
    end
    
    polinomio = polinomios(n + 1)
endfunction

// Todas las raíces están entre -1 y 1
// La función devuelve las raíces del polinomio de Chebyshev
function nodos = raíces_polinomio_chebyshev(n)
    // Los polinomios de Chebyshev son simétricos. Con respecto al eje y si son pares y si no al 0,0.
    // En los impares quedará una raíz en cero justo en el medio.
    nodos(1) = 0
    
    for i = 1:n/2
        raiz = cos((2 * i - 1) * %pi / (2 * n))
        nodos(i) = - raiz
        nodos(n - i + 1) = raiz
    end
endfunction

// Esto sirve para poder mover los puntos en los que quiero aplicar el método de aproximación de una función
// por polinomios.
function nodos = nodos_chebyshev_transformacion_lineal(n, a, b)
    nodos = nodos_chebyshev(n) * ((b - a) / 2) + (a + b) / 2
endfunction
