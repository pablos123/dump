funcprot(0)

function [P, L, U] = mLUPP(A)
    U = A;
    
    m = size(A, 1);
    
    L = eye(m, m);
    P = eye(m, m);
    
    for k = 1:m - 1
        // Inicio pivoteo parcial
        [ma, ind] = max(abs(U(k:m, k)))
        
        // Calculo el indice correcto ya que empecé a buscar desde k.
        ind = ind + (k - 1)
        
        // Permuto
        // Se podría hacer entera pero en U hasta k sin icluir hay ceros
        U([k ind], k:m) = U([ind k], k:m)
        // Se podría hacer entera pero en L desde k + 1 hay ceros. En k hay un 1
        L([k ind], 1:k - 1) = L([ind k], 1:k - 1)
        
        // Permuta las filas de la identidad
        P([k ind], :) = P([ind k], :)
        //Fin pivoteo parcial
  
        for j = k + 1:m
            // L es la inversa de E por eso el signo es positivo
            L(j, k) = U(j, k) / U(k, k)

            U(j, k:m) = U(j, k:m) - L(j, k) * U(k, k:m)
        end 
    end
endfunction

// Ejemplos de aplicación
disp('---------------------------------------')
A = [3 -2 -1; 6 -2 2; -9 7 1]
[P, L, U]= mLUPP(A)
disp(U, L, P)
disp('Verificación')
disp(P * A, L * U)

disp('---------------------------------------')
A = [1 1 0 3; 2 1 -1 1; 3 -1 -1 2; -1 2 3 -1]
[P, L, U]= mLUPP(A)
disp(U, L, P)
disp('Verificación')
disp(P * A, L * U)

disp('---------------------------------------')
A = [0 2 3; 2 0 3; 8 16 -1]
[P, L, U]= mLUPP(A)
disp(U, L, P)
disp('Verificación')
disp(P * A, L * U)

disp('---------------------------------------')
// Al restar la primera en la segunta, me queda pivot nulo.
A = [1 -1 2 -1; 2 -2 3 -3; 1 1 1 0; 1 -1 4 3]
[P, L, U]= mLUPP(A)
disp(U, L, P)
disp('Verificación')
disp(P * A, L * U)
