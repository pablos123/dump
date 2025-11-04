funcprot(0)

function x = mgaussjordan(A, b)
    // Esta función obtiene la solución del sistema de ecuaciones lineales A*x=b, 
    // dada la matriz de coeficientes A y el vector b.
    // La función implementa el método de Eliminación Gaussiana sin pivoteo. 
        
    [nA, mA] = size(A) 
    [nb, mb] = size(b)
    
     // Matriz aumentada
    a = [A b];
    
    // Eliminación progresiva
    n = nA;
    for k = 1:n
        // Normalizo la fila, ahora en la diagonal hay 1
        a(k, :) = a(k, :) / a(k, k)
        
        for i = 1:n
            if i <> k then
                a(i, :) = a(i, :) - a(i, k) * a(k, :)
            end
        end;
    end;
    x = a(:, nA + 1)
endfunction

// Ejemplos de aplicación
A = [3 -2 -1; 6 -2 2; -9 7 1]
b = [0 6 -1]'

y = mgaussjordan(A,b)
disp(y)

A = [1 1 0 3; 2 1 -1 1; 3 -1 -1 2; -1 2 3 -1]
b = [4 1 -3 4]'

y = mgaussjordan(A,b)
disp(y)

// Pivot nulo, se tiene que romper
A = [0 2 3; 2 0 3; 8 16 -1]
b = [7 13 -3]'

y = mgaussjordan(A,b)
disp(y)

// Al restar la primera en la segunta, me queda pivot nulo.
A = [1 -1 2 -1; 2 -2 3 -3; 1 1 1 0; 1 -1 4 3]
b = [-8 -20 -2 4]'

y = mgaussjordan(A,b)
disp(y)
