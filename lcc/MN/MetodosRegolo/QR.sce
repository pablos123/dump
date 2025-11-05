function [Q, R] = qrFact(A)
    Q(1:size(A, 1), 1) = A(:, 1) / norm(A(:, 1))
    R(1, 1:size(A, 2)) = Q(:, 1)' * A

    for i = 2:size(A, 2)
        q = A(:, i) - Q(:, 1:i-1) * R(1:i-1, i)
        Q(:, i) = q / norm(q)
        R(i, i) = norm(q)
        R(i, i+1:$) = Q(:, i)' * A(:, i+1:$)
    end
    
    R = triu(R)
endfunction
