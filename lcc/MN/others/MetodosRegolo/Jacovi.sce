
function [x, cont] = jacobi(A, b, x0, eps, max_iter)
    n = size(A, 1);
    xk = x0;             // vector con la iteración actual
    x = zeros(n, 1);     // vector con la iteración siguiente
    cont = 0;

    while cont < max_iter
        cont = cont + 1;

        // Calcular nueva aproximación
        for i = 1:n
            suma = 0;
            for j = 1:n
                if i <> j then
                    suma = suma + A(i, j) * xk(j);
                end
            end
            x(i) = (b(i) - suma) / A(i, i);
        end

        // Verificar convergencia
        if norm(x - xk) < eps then
            disp("Convergió en " + string(cont) + " iteraciones.");
            return;  // salir de la función
        end

        // Actualizar para la próxima iteración
        xk = x;
    end

    // Si llega acá, no convergió
    disp("No convergió tras " + string(max_iter) + " iteraciones.");
endfunction
