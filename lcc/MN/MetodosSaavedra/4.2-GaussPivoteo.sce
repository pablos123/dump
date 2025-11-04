funcprot(0)

function x = mgaussPP(A, b)
    // Esta función obtiene la solución del sistema de ecuaciones lineales A*x=b, 
    // dada la matriz de coeficientes A y el vector b.
    // La función implementa el método de Eliminación Gaussiana con pivoteo parcial.
    
    [nA,mA] = size(A) 
    [nb,mb] = size(b)
        
    a = [A b]; // Matriz aumentada
    n = nA;
    
    // Eliminación progresiva con pivoteo parcial
    for k = 1:n - 1
        // Pivoteo
        kpivot = k; 
        amax = abs(a(k, k));
        // Busqueda del pivot máximo para disminución de error
        for i = k + 1:n
            if abs(a(i, k)) > amax then
                kpivot = i;
                amax = a(i, k);
            end;
        end;
        
        // Swap fila actual por fila elegida por el pivot
        temp = a(kpivot, :); 
        a(kpivot, :) = a(k, :); 
        a(k, :) = temp;
        
        for i = k + 1:n
            for j = k + 1:n + 1
                a(i, j) = a(i, j) - a(k, j) * a(i, k) / a(k, k);
            end;
        end;
    end;
    
    // Sustitución regresiva
    for i = n:-1:1
        sumk = 0
        for k = i + 1:n
            sumk = sumk + a(i,k)*x(k);
        end;
        x(i) = (a(i,n+1)-sumk)/a(i,i);
    end;
endfunction

function [x, a] = gausselimPP(A, b)
    // Esta función obtiene la solución del sistema de ecuaciones lineales A*x=b, 
    // dada la matriz de coeficientes A y el vector b.
    // La función implementa el método de Eliminación Gaussiana con pivoteo parcial.
    
    [nA,mA] = size(A) 
    [nb,mb] = size(b)
    
    if nA<>mA then
        error('gausselimPP - La matriz A debe ser cuadrada');
        abort;
    elseif mA<>nb then
        error('gausselimPP - dimensiones incompatibles entre A y b');
        abort;
    end;
    
    a = [A b]; // Matriz aumentada
    n = nA;    // Tamaño de la matriz
    
    // Eliminación progresiva con pivoteo parcial
    for k=1:n-1
        kpivot = k; amax = abs(a(k,k));  //pivoteo
        for i=k+1:n
            if abs(a(i,k))>amax then
                kpivot = i; amax = a(i,k);
            end;
        end;
        temp = a(kpivot,:); a(kpivot,:) = a(k,:); a(k,:) = temp;
        
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

[x, a] = gausselimPP(A,b)
disp(x)
disp(a)
y = mgaussPP(A,b)
disp(y)

A = [1 1 0 3; 2 1 -1 1; 3 -1 -1 2; -1 2 3 -1]
b = [4 1 -3 4]'

[x, a] = gausselimPP(A,b)
disp(x)
disp(a)
y = mgaussPP(A,b)
disp(y)

// Pivot nulo, no se tiene que romper
A = [0 2 3; 2 0 3; 8 16 -1]
b = [7 13 -3]'

[x, a] = gausselimPP(A,b)
disp(x)
disp(a)
y = mgaussPP(A,b)
disp(y)

// Al restar la primera en la segunta, me queda pivot nulo.
A = [1 -1 2 -1; 2 -2 3 -3; 1 1 1 0; 1 -1 4 3]
b = [-8 -20 -2 4]'

[x, a] = gausselimPP(A, b)
disp(x)
disp(a)
y = mgaussPP(A,b)
disp(y)
