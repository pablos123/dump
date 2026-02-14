// ============================================================================
// 8.2 - Metodo de Simpson
// Unidad 8: Integracion numerica
// ============================================================================
funcprot(0)

// Regla de Simpson simple.
// Aproxima la integral de f en [a, b] usando una parabola.
// Formula: h/3 * (f(a) + 4*f(a+h) + f(b)) con h = (b-a)/2
//
// Parametros:
//   a - extremo izquierdo
//   b - extremo derecho
//   f - funcion a integrar
// Devuelve: aproximacion de la integral
function resultado = simpson(a, b, f)
    h = (b - a) / 2
    resultado = h / 3 * (f(a) + 4 * f(a + h) + f(b))
endfunction


// Regla de Simpson compuesto.
// Divide [a, b] en n subintervalos (n debe ser par).
//
// Parametros:
//   a - extremo izquierdo
//   b - extremo derecho
//   f - funcion a integrar
//   n - cantidad de subintervalos (debe ser par)
// Devuelve: aproximacion de la integral
function resultado = simpson_compuesto(a, b, f, n)
    if modulo(n, 2) == 1 then
        resultado = 0
        disp("n tiene que ser par.")
        return
    end

    h = (b - a) / n
    resultado = f(a) + f(b)

    for i = 1:2:n - 1
        resultado = resultado + 4 * f(a + i * h)
    end

    for i = 2:2:n - 2
        resultado = resultado + 2 * f(a + i * h)
    end

    resultado = h / 3 * resultado
endfunction


// Cota del error de Simpson simple.
// Error = -h^5/90 * f''''(c) para algun c en [a, b].
//
// Parametros:
//   a               - extremo izquierdo
//   b               - extremo derecho
//   f               - funcion a integrar
//   f_deriv_cuarta  - cuarta derivada de f
//   c               - punto que maximiza |f''''| en [a, b]
// Devuelve: cota del error
function err = cota_error_simpson(a, b, f, f_deriv_cuarta, c)
    h = (b - a) / 2
    err = -(h ** 5 / 90 * f_deriv_cuarta(c))
endfunction


// Cota del error de Simpson compuesto.
//
// Parametros:
//   a               - extremo izquierdo
//   b               - extremo derecho
//   f               - funcion a integrar
//   n               - cantidad de subintervalos
//   f_deriv_cuarta  - cuarta derivada de f
//   c               - punto que maximiza |f''''| en [a, b]
// Devuelve: cota del error
function err = cota_error_simpson_compuesto(a, b, f, n, f_deriv_cuarta, c)
    h = (b - a) / n
    err = -(h ** 4 * (b - a) / 180 * f_deriv_cuarta(c))
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
deff("y = f1(x)", "y = x^2")
disp("Simpson simple de x^2 en [0, 1]: " + string(simpson(0, 1, f1)))
disp("Simpson compuesto n=4: " + string(simpson_compuesto(0, 1, f1, 4)))
