function [x, cont] = gauss_seidel(A, b, x0, eps, max_iter)
    n = size(A, 1);
    x = x0;               // vector de la iteración actual
    xk = x0;              // para comparar convergencia
    cont = 0;

    while (cont < max_iter)
        cont = cont + 1;
        for i = 1:n
            suma = 0;

            // Parte con los valores ya actualizados (j < i)
            for j = 1:i-1
                suma = suma + A(i, j) * x(j);
            end

            // Parte con los valores aún no actualizados (j > i)
            for j = i+1:n
                suma = suma + A(i, j) * xk(j);
            end

            // Nueva aproximación para x(i)
            x(i) = (b(i) - suma) / A(i, i);
        end

        // Comprobamos convergencia con respecto a la iteración anterior
        if norm(x - xk) < eps then
            disp("Convergió en " + string(cont) + " iteraciones.");
            return;
        end

        // Actualizamos el vector de referencia
        xk = x;
    end

    // Si llegamos acá, no convergió
endfunction
