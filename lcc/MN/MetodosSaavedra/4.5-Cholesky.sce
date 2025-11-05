funcprot(0)

function U = mcholesky(A, eps)
    // Factorización de Cholesky.
    // Trabaja únicamente con la parte triangular superior.
    
    t = A(1, 1);
    
    // Si t es casi cero entonces quiere decir que está quedando un pivote
    // nulo en la diagonal de U.
    if t <= eps then
        printf('Matriz no definida positiva.\n')
        return
    end
    
    n = size(A, 1);
    
    U(1, 1) = sqrt(t)
    for j = 2:n
        U(1, j) = A(1, j) / U(1, 1)
    end
        
    for k = 2:n
        t = A(k, k) - U(1:k - 1, k)' * U(1:k - 1, k)
        // Si t es casi cero entonces quiere decir que está quedando un pivote
        // nulo en la diagonal de U.
        if t <= eps then
            printf('Matriz no definida positiva.\n')
            return
        end
        U(k, k) = sqrt(t)
        for j = k + 1:n
            U(k, j) = (A(k, j) - U(1:k - 1, k)' * U(1:k - 1, j) ) / U(k, k)
        end
    end
endfunction

A = [4 1 1; 8 2 2; 1 2 3]
disp(A)
U = mcholesky(A, %eps)
disp(U)

B = [5 2 1 0; 2 5 2 0; 1 2 5 2; 0 0 2 5]
disp(B)
U = mcholesky(B, %eps)
disp(U)

C = [5 2 1 0; 2 -4 2 0; 1 2 2 2; 0 0 2 5]
disp(C, %eps)
U = mcholesky(C, %eps)
