function [L,U] = doolitle(A)
    m = size(A, 1);
    L = eye(m,m);
    U = zeros(m,m);
    for i = 1:m
           
     for j = 1:m
        suma = 0;
        for k = 1:i-1
            suma = suma + L(i,k) * U (k,j);
        end
        U(i,j) = A(i,j) - suma;    
     end 
     
     for j=i+1:m
        suma = 0;
        for k = 1:i-1
            suma = suma + L(j,k) * U (k,i);
        end
        L(j,i) = (A(j,i) - suma)/U(i,i); 
     end
    end
endfunction
