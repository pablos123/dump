function [L, U, P] = gauss_pivoteo_vectorizado(A)
    [m, n] = size(A);
    if m <> n then
        error("La matriz debe ser cuadrada");
    end

    U = A;
    L = eye(m, m);
    P = eye(m, m);

    for k = 1:m-1
        // Selección de pivote
        [maxval, i] = max(abs(U(k:m, k)));
        i = i + k - 1;

        // Intercambio de filas
        if i <> k then
            U([k i], :) = U([i k], :);
            P([k i], :) = P([i k], :);
            if k > 1 then
                L([k i], 1:k-1) = L([i k], 1:k-1);
            end
        end

        // Eliminación vectorizada
        L(k+1:m, k) = U(k+1:m, k) / U(k, k);
        U(k+1:m, :) = U(k+1:m, :) - L(k+1:m, k) * U(k, :);
    end
endfunction
A = [2 1 1 0;4 3 3 1; 8 7 9 5;6 7 9 8];
[Lop, Uop, Pop] = gauss_pivoteo_vectorizado(A)
A2 = [1.012 -2.132 3.104;-2.132 4.096 -7.013;3.104 -7.013 0.014]
[Lop2, Uop2, Pop2] = gauss_pivoteo_vectorizado(A2)

