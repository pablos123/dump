funcprot(0)

// Argumentos: Matriz, Vector, Aproximacion Inicial, Condicion de corte, máximo iteraciones.
function xk = mgaussseidel(A, b, x0, eps, max_iter)
    n = size(A, 1);
    
    xk = x0;
    
    iter = 0;
    while (iter == 0 || norm(x0 - xk) > eps && iter < max_iter)
        x0 = xk;
        for i = 1:n
            suma = 0
            for j = 1:i - 1
                suma = suma + A(i, j) * xk(j)
            end
            for j = i + 1:n
                suma = suma + A(i, j) * x0(j)
            end
            xk(i) = 1 / A(i, i) * (b(i) - suma)
        end
        iter = iter + 1
    end
    printf("Iteraciones: %i", iter)
endfunction

A = [10 -1 2 -1; 2 -20 3 -3; 1 1 10 0; 1 -1 4 30]
b = [-8 -20 -2 4]'
x = mgaussseidel(A, b, [0 1 1 1], %eps, 1000)
disp(x)

// Se rompe por tener ceros en la diagonal
A = [10 -1 2 -1; 2 0 0 3; 1 1 0 0; 1 -1 4 30]
b = [-8 -20 -2 4]'
x = mgaussseidel(A, b, [0 1 1 1], %eps, 1)
disp(x)









