// ============================================================================
// 3.2 - Metodo de Newton
// Unidad 3: Ecuaciones no lineales
// ============================================================================
funcprot(0)

// Metodo de Newton-Raphson para encontrar raices.
// Formula: x_{n+1} = x_n - f(x_n) / f'(x_n)
//
// Parametros:
//   f        - funcion continua
//   df       - derivada de f
//   x0       - aproximacion inicial
//   eps      - tolerancia del error
//   max_iter - maximo de iteraciones
// Devuelve: aproximacion de la raiz
function raiz = metodo_newton(f, df, x0, eps, max_iter)
    x1 = x0 - f(x0) / df(x0)

    iter = 0
    while abs(x1 - x0) > eps && iter < max_iter
        x0 = x1
        x1 = x0 - f(x0) / df(x0)
        iter = iter + 1
    end

    raiz = x1
endfunction


// Metodo de Newton para sistemas de ecuaciones no lineales.
// Formula: x_{n+1} = x_n - J(x_n)^{-1} * F(x_n)
//
// Parametros:
//   f              - funcion vectorial
//   inv_jacobiano  - funcion que devuelve la inversa del jacobiano evaluado
//   x0             - aproximacion inicial (vector)
//   eps            - tolerancia del error
//   max_iter       - maximo de iteraciones
// Devuelve: aproximacion de la raiz (vector)
function raiz = metodo_newton_vectorial(f, inv_jacobiano, x0, eps, max_iter)
    x1 = x0 - inv_jacobiano(x0) * f(x0)

    iter = 0
    while norm(x1 - x0, 2) > eps && iter < max_iter
        x0 = x1
        x1 = x0 - inv_jacobiano(x0) * f(x0)
        iter = iter + 1
    end

    raiz = x1
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
deff("y = f(x)", "y = x^3 - x - 2")
deff("y = df(x)", "y = 3*x^2 - 1")
raiz = metodo_newton(f, df, 1.5, 1e-6, 100)
disp("Newton: raiz = " + string(raiz))
