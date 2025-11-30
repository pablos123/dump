function [L,U] = doolittle(A)
    m = size(A, 1);
    L = eye(m,m);
    U = zeros(m,m);
    U(1, :) = A(1, :);
    L(2:m, 1) = A(2:m, 1) / U(1,1);
    for i = 2:m
        U(i, i:m) = A(i, i:m) - L(i, 1:(i-1)) * U(1:(i-1), i:m);
        L((i+1):m, i) = (A((i+1):m, i) - L((i+1):m, 1:(i-1)) * U(1:(i-1), i)) / U(i, i);
    end
endfunction
