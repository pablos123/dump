funcprot(0)

// Calcula la factorización LU con el método de doolittle.
// No soporta permutaciones.
function [L, U] = mdoolittle(A)
    m = size(A, 1);
    L = eye(m, m);
    
    // Me muevo sobre el tamaño de la matriz, calculando primero la fila iter
    // de U y luego la columna iter de L (cabe destacar que L en la diagonal está definida ya con 1
    for iter = 1:m
   
        // Calculo la fila iter de U
        // En este caso iter funciona como i del apunte.
        for j = iter:m
            suma = 0
            for k = 1:iter - 1
                suma = suma + L(iter, k) * U(k, j)
            end
            U(iter, j) = A(iter, j) - suma 
        end
        
        // Calculo la columna iter de L
        // En este caso iter funciona como j del apunte.
        for i = iter + 1:m
            suma = 0
            for k = 1:iter - 1
                suma = suma + L(i, k) * U(k, iter)
            end
            L(i, iter) = (A(i, iter) - suma) / U(iter, iter)
        end
    end
endfunction

// Ejemplos de aplicación
disp('---------------------------------------')
A = [3 -2 -1; 6 -2 2; -9 7 1]
[L, U]= mdoolittle(A)
disp(U, L)
disp('Verificación')
disp(A, L * U)

disp('---------------------------------------')
A = [1 1 0 3; 2 1 -1 1; 3 -1 -1 2; -1 2 3 -1]
[L, U]= mdoolittle(A)
disp(U, L)
disp('Verificación')
disp(A, L * U)

disp('---------------------------------------')
// Se rompe por pivot nulo
A = [0 2 3; 2 0 3; 8 16 -1]
[L, U]= mdoolittle(A)
disp(U, L)
disp('Verificación')
disp(A, L * U)

disp('---------------------------------------')
// Al restar la primera en la segunta, me queda pivot nulo.
A = [1 -1 2 -1; 2 -2 3 -3; 1 1 1 0; 1 -1 4 3]
[L, U]= mdoolittle(A)
disp(U, L)
disp('Verificación')
disp(A, L * U)

