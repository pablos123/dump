// ============================================================================
// 8.1 - Metodo del Trapecio
// Unidad 8: Integracion numerica
// ============================================================================
funcprot(0)

// Regla del trapecio simple.
// Aproxima la integral de f en [a, b] con un solo trapecio.
// Formula: h/2 * (f(a) + f(b))
//
// Parametros:
//   a - extremo izquierdo
//   b - extremo derecho
//   f - funcion a integrar
// Devuelve: aproximacion de la integral
function resultado = trapecio(a, b, f)
    h = b - a
    resultado = h / 2 * (f(a) + f(b))
endfunction


// Regla del trapecio compuesto.
// Divide [a, b] en n subintervalos y aplica el trapecio en cada uno.
//
// Parametros:
//   a - extremo izquierdo
//   b - extremo derecho
//   f - funcion a integrar
//   n - cantidad de subintervalos
// Devuelve: aproximacion de la integral
function resultado = trapecio_compuesto(a, b, f, n)
    h = (b - a) / n
    resultado = (f(a) + f(b)) / 2

    for i = 1:n - 1
        resultado = resultado + f(a + i * h)
    end

    resultado = h * resultado
endfunction


// Cota del error del trapecio simple.
// Error = -h^3/12 * f''(c) para algun c en [a, b].
//
// Parametros:
//   a                - extremo izquierdo
//   b                - extremo derecho
//   f                - funcion a integrar
//   segunda_derivada - segunda derivada de f
//   c                - punto que maximiza |f''| en [a, b]
// Devuelve: cota del error
function err = cota_error_trapecio(a, b, f, segunda_derivada, c)
    h = b - a
    err = -(h ** 3 / 12 * segunda_derivada(c))
endfunction


// Cota del error del trapecio compuesto.
//
// Parametros:
//   a                - extremo izquierdo
//   b                - extremo derecho
//   f                - funcion a integrar
//   n                - cantidad de subintervalos
//   segunda_derivada - segunda derivada de f
//   c                - punto que maximiza |f''| en [a, b]
// Devuelve: cota del error
function err = cota_error_trapecio_compuesto(a, b, f, n, segunda_derivada, c)
    h = (b - a) / n
    err = -(h ** 2 / 12 * (b - a) * segunda_derivada(c))
endfunction


// ============================================================================
// Trapecio extendido (integracion bidimensional)
// ============================================================================

// Trapecio extendido para integrales dobles con limites constantes.
// Aproxima integral doble de f(x, y) en [a, b] x [c, d].
//
// Parametros:
//   a - extremo izquierdo en x
//   b - extremo derecho en x
//   f - funcion de dos variables f(x, y)
//   c - extremo inferior en y
//   d - extremo superior en y
// Devuelve: aproximacion de la integral doble
function v = trapecio_extendido(a, b, f, c, d)
    h1 = (b - a) / 2
    h2 = (d - c) / 2
    h = h1 * h2

    v = h * (f(c, a) + f(c, b) + f(d, a) + f(d, b))
endfunction


// Trapecio extendido con una grilla n x n para limites constantes.
//
// Parametros:
//   a - extremo izquierdo en x
//   b - extremo derecho en x
//   f - funcion de dos variables f(x, y)
//   c - extremo inferior en y
//   d - extremo superior en y
//   n - cantidad de subintervalos en cada direccion
// Devuelve: aproximacion de la integral doble
function v = trapecio_extendido_grilla(a, b, f, c, d, n)
    w = b - a
    h = d - c
    w_intervalo = w / n
    h_intervalo = h / n

    // Vertices
    v = (f(c, a) + f(c, b) + f(d, a) + f(d, b)) / 4

    v_aristas = 0
    for i = 1:n - 1
        // Aristas filas y columnas
        current_w = a + i * w_intervalo
        current_h = c + i * h_intervalo

        v_aristas = v_aristas + f(d, current_w) + f(c, current_w) + f(current_h, a) + f(current_h, b)

        // Internos
        for j = 1:n - 1
            current_h = c + j * h_intervalo
            v = v + f(current_h, current_w)
        end
    end

    v = w_intervalo * h_intervalo * (v + v_aristas / 2)
endfunction


// Trapecio para integral doble con limites de integracion variables.
// n intervalos para la integral exterior, m para cada integral interior.
//
// Parametros:
//   a - extremo izquierdo de la integral exterior
//   b - extremo derecho de la integral exterior
//   c - funcion limite inferior de la integral interior c(x)
//   d - funcion limite superior de la integral interior d(x)
//   f - funcion de dos variables f(x, y)
//   n - intervalos para la integral exterior
//   m - intervalos para cada integral interior
// Devuelve: aproximacion de la integral doble
function v = trapecio_doble_integral(a, b, c, d, f, n, m)
    h = (b - a) / n

    deff("z = fxa(y)", "z = f(" + string(a) + ", y)")
    deff("z = fxb(y)", "z = f(" + string(b) + ", y)")

    v = (trapecio_compuesto(c(a), d(a), fxa, m) + trapecio_compuesto(c(b), d(b), fxb, m)) / 2

    for i = 1:n - 1
        xi = a + i * h
        deff("z = fxi(y)", "z = f(" + string(xi) + ", y)")
        v = v + trapecio_compuesto(c(xi), d(xi), fxi, m)
    end

    v = h * v
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
deff("y = f1(x)", "y = x^2")
disp("Trapecio simple de x^2 en [0, 1]: " + string(trapecio(0, 1, f1)))
disp("Trapecio compuesto n=4: " + string(trapecio_compuesto(0, 1, f1, 4)))
