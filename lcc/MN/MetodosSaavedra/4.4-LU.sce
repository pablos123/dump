// ============================================================================
// 4.4 - Factorizacion LU con pivoteo parcial
// Unidad 4: Sistemas de ecuaciones lineales - Metodos directos
// ============================================================================
funcprot(0)

// Factorizacion PA = LU con pivoteo parcial.
// Devuelve las matrices P, L, U tales que P*A = L*U.
//
// Parametros:
//   A - matriz cuadrada
// Devuelve: [P, L, U] matrices de permutacion, triangular inferior y triangular superior
function [P, L, U] = mLUPP(A)
    U = A

    n = size(A, 1)

    L = eye(n, n)
    P = eye(n, n)

    for k = 1:n - 1
        // Inicio pivoteo parcial
        [ma, ind] = max(abs(U(k:n, k)))

        // Calculo el indice correcto ya que empece a buscar desde k
        ind = ind + (k - 1)

        // Permuto
        // Se podria hacer entera pero en U hasta k sin incluir hay ceros
        U([k ind], k:n) = U([ind k], k:n)
        // Se podria hacer entera pero en L desde k + 1 hay ceros. En k hay un 1
        L([k ind], 1:k - 1) = L([ind k], 1:k - 1)

        // Permuta las filas de la identidad
        P([k ind], :) = P([ind k], :)
        // Fin pivoteo parcial

        for j = k + 1:n
            // L es la inversa de E por eso el signo es positivo
            L(j, k) = U(j, k) / U(k, k)

            U(j, k:n) = U(j, k:n) - L(j, k) * U(k, k:n)
        end
    end
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
disp('---------------------------------------')
A = [3 -2 -1; 6 -2 2; -9 7 1]
[P, L, U] = mLUPP(A)
disp(U, L, P)
disp('Verificacion')
disp(P * A, L * U)

disp('---------------------------------------')
A = [1 1 0 3; 2 1 -1 1; 3 -1 -1 2; -1 2 3 -1]
[P, L, U] = mLUPP(A)
disp(U, L, P)
disp('Verificacion')
disp(P * A, L * U)
