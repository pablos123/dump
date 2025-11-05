funcprot(0)

function [Q, R] = mqr(A)
    // es_LI
    [m, n] = size(A)
    if m < n then
        disp("NOT LI")
        return
    end
    
    [Q, v] = gram_schmidt_qr(A)
    for k = 1:n
        R(k, k) = v(k)
        for i = k + 1:n
             R(k, i) = A(:, i)' * Q(:, k)
        end
    end
endfunction

function [Q, v] = gram_schmidt_qr(A)
    m = size(A, 1)
    for k = 1:m
        suma = 0
        ak = A(:, k)
        for i = 1:k - 1
            qi = Q(:, i)
            suma = suma + ((ak' * qi) * qi)
        end
        vk = norm(ak - suma)
        Q(:, k) = (ak - suma) / vk
        v(k) = vk
    end
endfunction

// Toma una matriz con espacio columna linealmente independiente.
// Devuelve una matriz con columnas ortonormales
function Q = gram_schmidt(A)
    m = size(A, 1)
    for k = 1:m
        suma = 0
        ak = A(:, k)
        for i = 1:k - 1
            qi = Q(:, i)
            suma = suma + ((ak' * qi) * qi)
        end
        Q(:, k) = (ak - suma) / norm(ak - suma) 
    end
endfunction
