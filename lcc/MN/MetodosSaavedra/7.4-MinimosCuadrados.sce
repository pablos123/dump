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

function coeficientes = minimos_cuadrados_polinomio_coeficientes(x, b, m)
    xp = length(x)
    xb = length(b)

    if xp <> xb then
        disp("Tienen que ser iguales")
        return
    end

    A(:, 1) = ones(xp, 1)

    for i = 2:m
        A(:, i) = A(:, i - 1) .* x'
    end

    At = A'

    coeficientes = mgaussPP(At * A, At * b')
endfunction

function p = minimos_cuadrados_polinomio(x, b, m)
    p = poly(minimos_cuadrados_polinomio_coeficientes(x, b, m), "x", "c")
endfunction

function A = matriz_polinomios_minimos_cuadrados(n, m)
    A(:, 1) = ones(n, 1)
    equis = poly([0, 1], "x", "c")

    for i = 2:m
        A(:, i) = A(:, i - 1) .* equis
    end
endfunction

function A = evaluar_matriz_polinomios_minimos_cuadrados(x, M)
    [n, m] = size(M)
    nx = length(x)
    if nx <> n then
        disp('El tamaño de x y las columnas de M tiene que ser iguales')
        return
    end
    for i = 1:n
        A(i, :) = horner(M(i, :), x(i))
    end
endfunction
