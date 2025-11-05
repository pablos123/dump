function a = simetrica(A)
    [n,m] = size(A);
    if n <> m then
        error('La matriz A debe ser cuadrada');
        abort;
    end
    a = %T;
    for i=1:n
        for j=1:m
           if A(i,j) == A(j,i) then a = a && %T else a = a && %F
           end
        end
    end
endfunction


function a = Ddominante(A)
   [n,m] = size(A);
    if n <> m then
        error('La matriz A debe ser cuadrada');
        abort;
    end
    a = %T;
    for i = 1:n
        if(sum (abs(A(i,:))) -A(i,i) < A(i,i)) then 
            a = a && %T;
        else
            a = a && %F;
        end
    end
endfunction


function valores = DefPositiva(A)
    [n,m] = size(A);
    valores = %F;
    if (simetrica(A)) then
        valores = min(spec(A))>0;
    end
    
endfunction
    

