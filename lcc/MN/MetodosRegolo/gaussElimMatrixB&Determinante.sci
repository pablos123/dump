function [s1,dete] = gaussElimOptimized(A,B)
    
    [nA,mA] = size(A) 
    [nb,mb] = size(B)
    
    if nA<>mA then
        error('gausselim - La matriz A debe ser cuadrada');
        abort;
    elseif mA<>nb then
        error('gausselim - dimensiones incompatibles entre A y b');
        abort;
    end;
    
    a = [A B]; // Matriz aumentada
    
    // Eliminación progresiva
    n = nA;
    dete = 1;
    for k=1:n-1
        for i=k+1:n
            for j=k+1:n+mb
                a(i,j) = a(i,j) - a(k,j)*a(i,k)/a(k,k);
            end;
        end;
        dete = dete*a(k,k);
    end;
    dete = dete * a(n,n);
    
    n = size(A,1)
    X(n,:) = a(n,n+1:n+mb) / a(n,n);
    
    for i = n-1:-1:1
        X(i,:) = (a(i,n+1:n+mb) - a(i,i+1:n)*X(i+1:n,1:mb))/a(i,i)
    end    
    
    s1 = X
endfunction
