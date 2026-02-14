// ============================================================================
// 4.8 - Factorizacion QR
// Unidad 4: Sistemas de ecuaciones lineales - Metodos directos
// ============================================================================
funcprot(0)

// Factorizacion A = Q*R usando el proceso de Gram-Schmidt.
// Q es ortogonal y R es triangular superior.
//
// Parametros:
//   A - matriz con columnas linealmente independientes (m >= n)
// Devuelve: [Q, R] matrices ortogonal y triangular superior
function [Q, R] = mqr(A)
    [m, n] = size(A)
    if m < n then
        disp("Las columnas no son linealmente independientes")
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


// Proceso de Gram-Schmidt para factorizacion QR.
// Devuelve la matriz Q ortonormal y el vector v con las normas.
//
// Parametros:
//   A - matriz con columnas linealmente independientes
// Devuelve: [Q, v] matriz ortonormal y vector de normas
function [Q, v] = gram_schmidt_qr(A)
    m = size(A, 1)
    for k = 1:m
        suma = 0
        ak = A(:, k)
        // Resta las proyecciones sobre los vectores ya ortonormalizados
        for i = 1:k - 1
            qi = Q(:, i)
            suma = suma + ((ak' * qi) * qi)
        end
        vk = norm(ak - suma)
        Q(:, k) = (ak - suma) / vk
        v(k) = vk
    end
endfunction


// Proceso de Gram-Schmidt.
// Toma una matriz con espacio columna linealmente independiente.
// Devuelve una matriz con columnas ortonormales.
//
// Parametros:
//   A - matriz con columnas linealmente independientes
// Devuelve: Q matriz con columnas ortonormales
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


// ============================================================================
// Ejemplos
// ============================================================================
A = [1 1 0; 1 0 1; 0 1 1]
[Q, R] = mqr(A)
disp('Q:')
disp(Q)
disp('R:')
disp(R)
disp('Verificacion Q*R:')
disp(Q * R)

A2 = [1 2; 3 4; 5 6]
[Q2, R2] = mqr(A2)
disp('Q:')
disp(Q2)
disp('R:')
disp(R2)
disp('Verificacion Q*R:')
disp(Q2 * R2)
