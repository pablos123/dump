// ============================================================================
// 7.3 - Nodos de Chebyshev
// Unidad 7: Interpolacion y aproximacion polinomial
// ============================================================================
funcprot(0)

// Devuelve el polinomio de Chebyshev de grado n.
// Todas las raices estan entre -1 y 1.
// Usa la recurrencia: T_n(x) = 2*x*T_{n-1}(x) - T_{n-2}(x)
//
// Parametros:
//   n - grado del polinomio
// Devuelve: polinomio de Chebyshev de grado n
function polinomio = polinomio_chebyshev(n)
    if n == 0 then
        polinomio = 1
        return
    end

    equis = poly([0, 1], "x", "c")
    polinomios = [1, equis]

    for i = 3:n + 1
        polinomios(i) = 2 * equis * polinomios(i - 1) - polinomios(i - 2)
    end

    polinomio = polinomios(n + 1)
endfunction


// Devuelve las raices del polinomio de Chebyshev de grado n.
// Los polinomios de Chebyshev son simetricos con respecto al eje y si son
// pares y con respecto al origen si son impares.
//
// Parametros:
//   n - grado del polinomio
// Devuelve: vector con las n raices en [-1, 1]
function nodos = raices_polinomio_chebyshev(n)
    nodos(1) = 0

    for i = 1:n / 2
        raiz = cos((2 * i - 1) * %pi / (2 * n))
        nodos(i) = -raiz
        nodos(n - i + 1) = raiz
    end
endfunction


// Transformacion lineal de los nodos de Chebyshev al intervalo [a, b].
// Permite usar nodos de Chebyshev para aproximar funciones en cualquier intervalo.
//
// Parametros:
//   n - cantidad de nodos
//   a - extremo izquierdo del intervalo
//   b - extremo derecho del intervalo
// Devuelve: vector con los nodos transformados al intervalo [a, b]
function nodos = nodos_chebyshev_transformacion_lineal(n, a, b)
    nodos = raices_polinomio_chebyshev(n) * ((b - a) / 2) + (a + b) / 2
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
disp("Polinomio de Chebyshev T_4:")
disp(polinomio_chebyshev(4))

disp("Raices de T_5:")
disp(raices_polinomio_chebyshev(5))

disp("Nodos de Chebyshev en [0, 2] con n=4:")
disp(nodos_chebyshev_transformacion_lineal(4, 0, 2))
