// ============================================================================
// 4.1 - Eliminacion Gaussiana sin pivoteo
// Unidad 4: Sistemas de ecuaciones lineales - Metodos directos
// ============================================================================
funcprot(0)

// Eliminacion Gaussiana sin pivoteo (version simple).
// Resuelve el sistema A*x = b.
//
// Parametros:
//   A - matriz de coeficientes
//   b - vector de terminos independientes
// Devuelve: vector solucion x
function x = mgauss(A, b)
    [nA, mA] = size(A)
    [nb, mb] = size(b)

    // Matriz aumentada
    a = [A b]

    // Eliminacion progresiva
    n = nA
    for k = 1:n - 1
        for i = k + 1:n
            for j = k + 1:n + 1
                a(i, j) = a(i, j) - a(k, j) * a(i, k) / a(k, k)
            end
        end
    end

    // Sustitucion regresiva
    for i = n:-1:1
        suma = 0
        // No entra en la primera iteracion porque el inicio es mayor al final n + 1 > n
        for k = i + 1:n
            suma = suma + a(i, k) * x(k)
        end
        x(i) = (a(i, n + 1) - suma) / a(i, i)
    end
endfunction


// Eliminacion Gaussiana sin pivoteo (con validacion y retorno de matriz aumentada).
// Resuelve el sistema A*x = b.
//
// Parametros:
//   A - matriz de coeficientes (debe ser cuadrada)
//   b - vector de terminos independientes
// Devuelve: [x, a] vector solucion y matriz aumentada escalonada
function [x, a] = gausselim(A, b)
    [nA, mA] = size(A)
    [nb, mb] = size(b)

    if nA <> mA then
        error('gausselim - La matriz A debe ser cuadrada')
        abort
    elseif mA <> nb then
        error('gausselim - dimensiones incompatibles entre A y b')
        abort
    end

    // Matriz aumentada
    a = [A b]

    // Eliminacion progresiva
    n = nA
    for k = 1:n - 1
        for i = k + 1:n
            for j = k + 1:n + 1
                a(i, j) = a(i, j) - a(k, j) * a(i, k) / a(k, k)
            end
            // Pone ceros debajo del pivot (no hace falta para calcular x)
            for j = 1:k
                a(i, j) = 0
            end
        end
    end

    // Sustitucion regresiva
    x(n) = a(n, n + 1) / a(n, n)
    for i = n - 1:-1:1
        suma = 0
        for k = i + 1:n
            suma = suma + a(i, k) * x(k)
        end
        x(i) = (a(i, n + 1) - suma) / a(i, i)
    end
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
A = [3 -2 -1; 6 -2 2; -9 7 1]
b = [0 6 -1]'
[x, a] = gausselim(A, b)
disp(x)

// Al restar la primera en la segunda, queda pivot nulo
A = [1 -1 2 -1; 2 -2 3 -3; 1 1 1 0; 1 -1 4 3]
b = [-8 -20 -2 4]'
[x, a] = gausselim(A, b)
disp(x)
