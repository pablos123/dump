// ============================================================================
// 4.6 - Factorizacion LU por Crout
// Unidad 4: Sistemas de ecuaciones lineales - Metodos directos
// ============================================================================
funcprot(0)

// Factorizacion A = LU por el metodo de Crout.
// U tiene unos en la diagonal. No soporta permutaciones.
//
// Parametros:
//   A - matriz cuadrada
// Devuelve: [L, U] matrices triangular inferior y triangular superior
function [L, U] = mcrout(A)
    n = size(A, 1)
    U = eye(n, n)

    // Me muevo sobre el tamano de la matriz, calculando primero la columna iter
    // de L y luego la fila iter de U (U en la diagonal ya esta definida con 1)
    for iter = 1:n

        // Calculo la columna iter de L
        for i = iter:n
            suma = 0
            for k = 1:iter - 1
                suma = suma + L(i, k) * U(k, iter)
            end
            L(i, iter) = (A(i, iter) - suma)
        end

        // Calculo la fila iter de U
        for j = iter + 1:n
            suma = 0
            for k = 1:iter - 1
                suma = suma + L(iter, k) * U(k, j)
            end
            U(iter, j) = (A(iter, j) - suma) / L(iter, iter)
        end
    end
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
disp('---------------------------------------')
A = [3 -2 -1; 6 -2 2; -9 7 1]
[L, U] = mcrout(A)
disp(U, L)
disp('Verificacion')
disp(A, L * U)

disp('---------------------------------------')
A = [1 1 0 3; 2 1 -1 1; 3 -1 -1 2; -1 2 3 -1]
[L, U] = mcrout(A)
disp(U, L)
disp('Verificacion')
disp(A, L * U)
