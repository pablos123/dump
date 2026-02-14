// ============================================================================
// 7.4 - Minimos Cuadrados
// Unidad 7: Interpolacion y aproximacion polinomial
// ============================================================================
funcprot(0)

// Dependencia: ejecutar 4.2-GaussPivoteo.sce para tener disponible mgaussPP

// Calcula los coeficientes del polinomio de minimos cuadrados de grado m-1.
// Resuelve el sistema normal A'*A*c = A'*b.
//
// Parametros:
//   x - vector de puntos x
//   b - vector de valores y
//   m - cantidad de coeficientes (grado + 1)
// Devuelve: vector de coeficientes del polinomio
function coeficientes = minimos_cuadrados_polinomio_coeficientes(x, b, m)
    xp = length(x)
    xb = length(b)

    if xp <> xb then
        disp("Tienen que ser iguales")
        return
    end

    A(:, 1) = ones(xp, 1)

    for i = 2:m
        A(:, i) = A(:, i - 1) .* x'
    end

    At = A'

    coeficientes = mgaussPP(At * A, At * b')
endfunction


// Construye el polinomio de minimos cuadrados de grado m-1.
//
// Parametros:
//   x - vector de puntos x
//   b - vector de valores y
//   m - cantidad de coeficientes (grado + 1)
// Devuelve: polinomio de minimos cuadrados
function p = minimos_cuadrados_polinomio(x, b, m)
    p = poly(minimos_cuadrados_polinomio_coeficientes(x, b, m), "x", "c")
endfunction


// Construye la matriz de Vandermonde simbolica para minimos cuadrados.
//
// Parametros:
//   n - cantidad de filas
//   m - cantidad de columnas
// Devuelve: matriz de polinomios
function A = matriz_polinomios_minimos_cuadrados(n, m)
    A(:, 1) = ones(n, 1)
    equis = poly([0, 1], "x", "c")

    for i = 2:m
        A(:, i) = A(:, i - 1) .* equis
    end
endfunction


// Evalua la matriz de polinomios en los puntos dados.
//
// Parametros:
//   x - vector de puntos donde evaluar
//   M - matriz de polinomios
// Devuelve: matriz evaluada
function A = evaluar_matriz_polinomios_minimos_cuadrados(x, M)
    [n, m] = size(M)
    nx = length(x)
    if nx <> n then
        disp('El tamano de x y las filas de M tienen que ser iguales')
        return
    end
    for i = 1:n
        A(i, :) = horner(M(i, :), x(i))
    end
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
// Requiere ejecutar antes 4.2-GaussPivoteo.sce
// x = [1 2 3 4 5]
// y = [2.1 3.9 6.2 7.8 10.1]
// p = minimos_cuadrados_polinomio(x, y, 2)
// disp(p)
