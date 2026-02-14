// ============================================================================
// 4.7 - Factorizacion de Cholesky
// Unidad 4: Sistemas de ecuaciones lineales - Metodos directos
// ============================================================================
funcprot(0)

// Factorizacion de Cholesky: A = U' * U.
// Trabaja unicamente con la parte triangular superior.
// Requiere que A sea simetrica y definida positiva.
//
// Parametros:
//   A   - matriz simetrica definida positiva
//   eps - tolerancia para detectar pivotes nulos
// Devuelve: U triangular superior tal que A = U' * U
function U = mcholesky(A, eps)
    t = A(1, 1)

    // Si t es casi cero entonces quiere decir que esta quedando un pivote
    // nulo en la diagonal de U.
    if t <= eps then
        printf('Matriz no definida positiva.\n')
        return
    end

    n = size(A, 1)

    U(1, 1) = sqrt(t)
    for j = 2:n
        U(1, j) = A(1, j) / U(1, 1)
    end

    for k = 2:n
        t = A(k, k) - U(1:k - 1, k)' * U(1:k - 1, k)
        // Si t es casi cero entonces quiere decir que esta quedando un pivote
        // nulo en la diagonal de U.
        if t <= eps then
            printf('Matriz no definida positiva.\n')
            return
        end
        U(k, k) = sqrt(t)
        for j = k + 1:n
            U(k, j) = (A(k, j) - U(1:k - 1, k)' * U(1:k - 1, j)) / U(k, k)
        end
    end
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
A = [4 1 1; 8 2 2; 1 2 3]
disp(A)
U = mcholesky(A, %eps)
disp(U)

B = [5 2 1 0; 2 5 2 0; 1 2 5 2; 0 0 2 5]
disp(B)
U = mcholesky(B, %eps)
disp(U)
