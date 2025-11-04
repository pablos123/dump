funcprot(0)

// Matriz A y 
function x = mgauss(A, b)
    // Esta función obtiene la solución del sistema de ecuaciones lineales A*x=b, 
    // dada la matriz de coeficientes A y el vector b.
    // La función implementa el método de Eliminación Gaussiana sin pivoteo. 
        
    [nA, mA] = size(A) 
    [nb, mb] = size(b)
    
     // Matriz aumentada
    a = [A b];
    
    // Eliminación progresiva
    n = nA;
    for k = 1:n - 1
        for i = k + 1:n
            for j = k + 1:n + 1
                a(i, j) = a(i, j) - a(k, j) * a(i, k) / a(k, k);
            end;
        end;
    end;
    
    // Sustitución regresiva
    for i = n:-1:1
        sumk = 0
        // No entra en la primera iteración porque el inicio es mayor al final n + 1 > n
        for k = i + 1:n
            sumk = sumk + a(i, k) * x(k);
        end;
        x(i) = (a(i, n + 1) - sumk) / a(i, i);
    end;
endfunction

function [x, a] = gausselim(A, b)
    // Esta función obtiene la solución del sistema de ecuaciones lineales A*x=b, 
    // dada la matriz de coeficientes A y el vector b.
    // La función implementa el método de Eliminación Gaussiana sin pivoteo.  
    
    [nA,mA] = size(A) 
    [nb,mb] = size(b)
    
    if nA<>mA then
        error('gausselim - La matriz A debe ser cuadrada');
        abort;
    elseif mA<>nb then
        error('gausselim - dimensiones incompatibles entre A y b');
        abort;
    end;
    
    a = [A b]; // Matriz aumentada
    
    // Eliminación progresiva
    n = nA;
    for k=1:n-1
        for i=k+1:n
            for j=k+1:n+1
                a(i,j) = a(i,j) - a(k,j)*a(i,k)/a(k,k);
            end;
            for j=1:k        // no hace falta para calcular la solución x
                a(i,j) = 0;  // no hace falta para calcular la solución x
            end              // no hace falta para calcular la solución x
        end;
    end;
    
    // Sustitución regresiva
    x(n) = a(n,n+1)/a(n,n);
    for i = n-1:-1:1
        sumk = 0
        for k=i+1:n
            sumk = sumk + a(i,k)*x(k);
        end;
        x(i) = (a(i,n+1)-sumk)/a(i,i);
    end;
endfunction

// Ejemplos de aplicación
A = [3 -2 -1; 6 -2 2; -9 7 1]
b = [0 6 -1]'

[x, a] = gausselim(A,b)
disp(x)
disp(a)
y = mgauss(A,b)
disp(y)

A = [1 1 0 3; 2 1 -1 1; 3 -1 -1 2; -1 2 3 -1]
b = [4 1 -3 4]'

[x, a] = gausselim(A,b)
disp(x)
disp(a)
y = mgauss(A,b)
disp(y)

// Pivot nulo, se tiene que romper
A = [0 2 3; 2 0 3; 8 16 -1]
b = [7 13 -3]'

[x, a] = gausselim(A,b)
disp(x)
disp(a)
y = mgauss(A,b)
disp(y)

// Al restar la primera en la segunta, me queda pivot nulo.
A = [1 -1 2 -1; 2 -2 3 -3; 1 1 1 0; 1 -1 4 3]
b = [-8 -20 -2 4]'

[x, a] = gausselim(A, b)
disp(x)
disp(a)
y = mgauss(A,b)
disp(y)
