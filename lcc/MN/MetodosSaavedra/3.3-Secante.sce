// ============================================================================
// 3.3 - Metodo de la Secante
// Unidad 3: Ecuaciones no lineales
// ============================================================================
funcprot(0)

// Metodo de la secante recursivo.
//
// Parametros:
//   f   - funcion continua
//   x0  - primera aproximacion
//   x1  - segunda aproximacion
//   eps - tolerancia del error
// Devuelve: aproximacion de la raiz
function raiz = secante_recursivo(f, x0, x1, eps)
    fx1 = f(x1)
    x2 = x1 - fx1 * (x1 - x0) / (fx1 - f(x0))

    if abs(x1 - x2) <= eps then
        raiz = x2
    else
        raiz = secante_recursivo(f, x1, x2, eps)
    end
endfunction


// Metodo de la secante iterativo.
// Formula: x_{n+1} = x_n - f(x_n) * (x_n - x_{n-1}) / (f(x_n) - f(x_{n-1}))
//
// Parametros:
//   f        - funcion continua
//   x0       - primera aproximacion
//   x1       - segunda aproximacion
//   eps      - tolerancia del error
//   max_iter - maximo de iteraciones
// Devuelve: aproximacion de la raiz
function raiz = metodo_secante(f, x0, x1, eps, max_iter)
    fx1 = f(x1)

    x2 = x1 - fx1 * (x1 - x0) / (fx1 - f(x0))

    iter = 1
    while abs(x1 - x2) > eps && iter < max_iter
        x0 = x1
        x1 = x2

        fx1 = f(x1)

        x2 = x1 - fx1 * (x1 - x0) / (fx1 - f(x0))

        iter = iter + 1
    end

    raiz = x2
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
deff("y = f(x)", "y = x^3 - x - 2")
raiz = metodo_secante(f, 1, 2, 1e-6, 100)
disp("Secante iterativa: raiz = " + string(raiz))

raiz_rec = secante_recursivo(f, 1, 2, 1e-6)
disp("Secante recursiva: raiz = " + string(raiz_rec))
