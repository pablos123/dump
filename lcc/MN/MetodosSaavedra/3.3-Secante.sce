// ============================================================================
// 3.3 - Metodo de la Secante
// Unidad 3: Ecuaciones no lineales
// ============================================================================
funcprot(0)

// Metodo de la secante recursivo.
//
// Parametros:
//   f   - funcion continua
//   a   - primera aproximacion
//   b   - segunda aproximacion
//   fa  - f(a)
//   fb  - f(b)
//   eps - tolerancia del error
// Devuelve: aproximacion de la raiz
function raiz = secante_recursivo(f, a, b, fa, fb, eps)
    c = b - fb * (b - a) / (fb - fa)

    if abs(b - c) <= eps then
        raiz = c
    else
        raiz = secante_recursivo(f, b, c, fb, f(c), eps)
    end
endfunction


// Metodo de la secante iterativo.
// Formula: x_{n+1} = x_n - f(x_n) * (x_n - x_{n-1}) / (f(x_n) - f(x_{n-1}))
//
// Parametros:
//   f        - funcion continua
//   a        - primera aproximacion
//   b        - segunda aproximacion
//   eps      - tolerancia del error
//   max_iter - maximo de iteraciones
// Devuelve: aproximacion de la raiz
function raiz = metodo_secante(f, a, b, eps, max_iter)
    fa = f(a)
    fb = f(b)
    c = b - fb * (b - a) / (fb - fa)

    iter = 1
    while abs(b - c) > eps && iter < max_iter
        a = b;  fa = fb
        b = c;  fb = f(c)
        c = b - fb * (b - a) / (fb - fa)
        iter = iter + 1
    end

    raiz = c
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
deff("y = f(x)", "y = x^3 - x - 2")
raiz = metodo_secante(f, 1, 2, 1e-6, 100)
disp("Secante iterativa: raiz = " + string(raiz))

raiz_rec = secante_recursivo(f, 1, 2, f(1), f(2), 1e-6)
disp("Secante recursiva: raiz = " + string(raiz_rec))
