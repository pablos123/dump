funcprot(0)

// Argumentos: Matriz, Vector, Aproximacion Inicial, Condicion de corte, máximo iteraciones.
function xk = msor(A, b, x0, eps, max_iter, omega)
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
            xk(i) = (1 - omega) * x0(i) + omega / A(i, i) * (b(i) - suma)
        end
        iter = iter + 1
    end
    printf("Iteraciones: %i", iter)
endfunction

// Esto vale siempre y cuando A es definida positiva y tridiagonal
function y = opt_omega(A)
    y = 2 / (1 + sqrt(1 - spec_matriz_tj(A) ** 2))
endfunction

function y = spec_matriz_tj(A)
    n = size(A, 1)
    for i = 1:n
        Ninv(i, i) = 1 / A(i, i)
    end
    y = max(abs(spec(eye(n, n) - Ninv * A)))
endfunction

A = [10 -1 2 -1; 2 -20 3 -3; 1 1 10 0; 1 -1 4 30]
b = [-8 -20 -2 4]'
x = msor(A, b, [0 1 1 1], %eps, 1000, 1)
disp(x)

A = [10 -1 2 -1; 2 -20 3 -3; 1 1 10 0; 1 -1 4 30]
b = [-8 -20 -2 4]'
x = msor(A, b, [0 1 1 1], %eps, 1000, opt_omega(A))
disp(x)

A = [8 5 0 0; 1 9 1 0; 0 2 10 0; 0 0 3 7]
b = [-8 -20 -2 4]'
x = msor(A, b, [0 1 1 1], %eps, 1000, 1)
disp(x)

A = [8 5 0 0; 1 9 1 0; 0 2 10 0; 0 0 3 7]
b = [-8 -20 -2 4]'
x = msor(A, b, [0 1 1 1], %eps, 1000, opt_omega(A))
disp(x)

// Se rompe por tener ceros en la diagonal
A = [10 -1 2 -1; 2 0 0 3; 1 1 0 0; 1 -1 4 30]
b = [-8 -20 -2 4]'
x = msor(A, b, [0 1 1 1], %eps, 1, 1)
disp(x)



