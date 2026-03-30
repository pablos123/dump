// ============================================================================
// 3.1 - Metodo de Biseccion
// Unidad 3: Ecuaciones no lineales
// ============================================================================
funcprot(0)

// Metodo de biseccion recursivo.
// Se asume que existe una raiz entre a y b.
//
// Parametros:
//   f    - funcion continua
//   a    - extremo izquierdo del intervalo
//   b    - extremo derecho del intervalo
//   eps  - tolerancia del error
//   kf   - valor de f evaluado en el extremo que se mantiene
// Devuelve: aproximacion de la raiz
function raiz = biseccion_recursivo(f, a, b, eps, kf)
    c = (a + b) / 2

    fc = f(c)
    if (b - c) <= eps then
        raiz = c
    elseif kf * fc <= 0
        raiz = biseccion_recursivo(f, c, b, eps, kf)
    else
        raiz = biseccion_recursivo(f, a, c, eps, fc)
    end
endfunction


// Metodo de biseccion iterativo.
// Se basa en el Teorema de Bolzano. Suponemos que f(x) es continua
// en [a, b] y que f(a)f(b) < 0. Luego f(x) = 0 tiene al menos una raiz
// en dicho intervalo.
// Formula: c = (a + b) / 2
//
// Parametros:
//   f        - funcion continua
//   a        - extremo izquierdo del intervalo
//   b        - extremo derecho del intervalo
//   eps      - tolerancia del error
//   max_iter - maximo de iteraciones
// Devuelve: aproximacion de la raiz
function raiz = metodo_biseccion(f, a, b, eps, max_iter)
    c = (a + b) / 2

    fb = f(b)

    iter = 1
    while (b - c) > eps && iter < max_iter
        fc = f(c)
        if fb * fc <= 0
            a = c
        else
            b = c
            fb = fc
        end

        c = (a + b) / 2

        iter = iter + 1
    end

    raiz = c
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
deff("y = f(x)", "y = x^3 - x - 2")
raiz = metodo_biseccion(f, 1, 2, 1e-6, 100)
disp("Biseccion iterativa: raiz = " + string(raiz))

raiz_rec = biseccion_recursivo(f, 1, 2, 1e-6, f(1))
disp("Biseccion recursiva: raiz = " + string(raiz_rec))
