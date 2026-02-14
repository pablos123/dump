// ============================================================================
// 4.2 - Eliminacion Gaussiana con pivoteo parcial
// Unidad 4: Sistemas de ecuaciones lineales - Metodos directos
// ============================================================================
funcprot(0)

// Eliminacion Gaussiana con pivoteo parcial (version simple).
// Resuelve el sistema A*x = b.
//
// Parametros:
//   A - matriz de coeficientes
//   b - vector de terminos independientes
// Devuelve: vector solucion x
function x = mgaussPP(A, b)
    [nA, mA] = size(A)
    [nb, mb] = size(b)

    // Matriz aumentada
    a = [A b]
    n = nA

    // Eliminacion progresiva con pivoteo parcial
    for k = 1:n - 1
        // Pivoteo: busqueda del pivot maximo para disminucion de error
        kpivot = k
        amax = abs(a(k, k))
        for i = k + 1:n
            if abs(a(i, k)) > amax then
                kpivot = i
                amax = a(i, k)
            end
        end

        // Swap fila actual por fila elegida por el pivot
        temp = a(kpivot, :)
        a(kpivot, :) = a(k, :)
        a(k, :) = temp

        for i = k + 1:n
            for j = k + 1:n + 1
                a(i, j) = a(i, j) - a(k, j) * a(i, k) / a(k, k)
            end
        end
    end

    // Sustitucion regresiva
    for i = n:-1:1
        suma = 0
        for k = i + 1:n
            suma = suma + a(i, k) * x(k)
        end
        x(i) = (a(i, n + 1) - suma) / a(i, i)
    end
endfunction


// Eliminacion Gaussiana con pivoteo parcial (con validacion y retorno de matriz aumentada).
// Resuelve el sistema A*x = b.
//
// Parametros:
//   A - matriz de coeficientes (debe ser cuadrada)
//   b - vector de terminos independientes
// Devuelve: [x, a] vector solucion y matriz aumentada escalonada
function [x, a] = gausselimPP(A, b)
    [nA, mA] = size(A)
    [nb, mb] = size(b)

    if nA <> mA then
        error('gausselimPP - La matriz A debe ser cuadrada')
        abort
    elseif mA <> nb then
        error('gausselimPP - dimensiones incompatibles entre A y b')
        abort
    end

    // Matriz aumentada
    a = [A b]
    n = nA

    // Eliminacion progresiva con pivoteo parcial
    for k = 1:n - 1
        // Pivoteo
        kpivot = k
        amax = abs(a(k, k))
        for i = k + 1:n
            if abs(a(i, k)) > amax then
                kpivot = i
                amax = a(i, k)
            end
        end

        // Swap fila actual por fila elegida por el pivot
        temp = a(kpivot, :)
        a(kpivot, :) = a(k, :)
        a(k, :) = temp

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
[x, a] = gausselimPP(A, b)
disp(x)

// Pivot nulo, no se rompe gracias al pivoteo
A = [0 2 3; 2 0 3; 8 16 -1]
b = [7 13 -3]'
[x, a] = gausselimPP(A, b)
disp(x)
