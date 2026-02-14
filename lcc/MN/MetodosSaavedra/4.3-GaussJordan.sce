// ============================================================================
// 4.3 - Eliminacion de Gauss-Jordan
// Unidad 4: Sistemas de ecuaciones lineales - Metodos directos
// ============================================================================
funcprot(0)

// Eliminacion de Gauss-Jordan sin pivoteo.
// Reduce la matriz aumentada a forma escalonada reducida (diagonal de unos).
// Resuelve el sistema A*x = b.
//
// Parametros:
//   A - matriz de coeficientes
//   b - vector de terminos independientes
// Devuelve: vector solucion x
function x = mgaussjordan(A, b)
    [nA, mA] = size(A)
    [nb, mb] = size(b)

    // Matriz aumentada
    a = [A b]

    n = nA
    for k = 1:n
        // Normalizo la fila, ahora en la diagonal hay 1
        a(k, :) = a(k, :) / a(k, k)

        for i = 1:n
            if i <> k then
                a(i, :) = a(i, :) - a(i, k) * a(k, :)
            end
        end
    end
    x = a(:, nA + 1)
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
A = [3 -2 -1; 6 -2 2; -9 7 1]
b = [0 6 -1]'
y = mgaussjordan(A, b)
disp(y)

A = [1 1 0 3; 2 1 -1 1; 3 -1 -1 2; -1 2 3 -1]
b = [4 1 -3 4]'
y = mgaussjordan(A, b)
disp(y)
