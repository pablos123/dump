function y = triangula_sup(A,b)
    n = size(A,1);
    y(n) = b(n) / A(n,n);
    for i = n-1:-1:1
        Sum = 0;
        for j = n - 1: -1 : i+1
            Sum = Sum + A(i,j) * y(j);
        end
        y(i) = (b(i)-Sum ) / A(i,i);
    end
endfunction

function y = triangula_sup(A,b)
    n = size(A,1);
    y(n) = b(n) / A(n,n);
    for i = n-1:-1:1
        Sum = A(i,i+1:)* y(i:)
        y(i) = (b(i)-Sum ) / A(i,i);
    end
endfunction

function y = triangula_inf(A,b)
    n = size(A,1);
    y(1) = b(1) / A(1,1);
    for i = 1:n-1
        Sum = A(i,1:i-1)* y(1:i-1)
        y(i) = (b(i)-Sum ) / A(i,i);
    end
endfunction
