// ============================================================================
// 5.3 - Metodo SOR (Successive Over-Relaxation)
// Unidad 5: Sistemas de ecuaciones lineales - Metodos iterativos
// ============================================================================
funcprot(0)

// Metodo SOR para resolver A*x = b.
// Generaliza Gauss-Seidel con un factor de relajacion omega.
// Si omega = 1, es equivalente a Gauss-Seidel.
//
// Parametros:
//   A        - matriz de coeficientes
//   b        - vector de terminos independientes
//   x0       - aproximacion inicial
//   eps      - tolerancia del error
//   max_iter - maximo de iteraciones
//   omega    - factor de relajacion (0 < omega < 2)
// Devuelve: vector solucion aproximado
function xk = msor(A, b, x0, eps, max_iter, omega)
    n = size(A, 1)

    xk = x0

    iter = 0
    while (iter == 0 || norm(x0 - xk) > eps && iter < max_iter)
        x0 = xk
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
    printf("Iteraciones: %i\n", iter)
endfunction


// Calcula el omega optimo para SOR.
// Valido cuando A es definida positiva y tridiagonal.
//
// Parametros:
//   A - matriz de coeficientes
// Devuelve: valor optimo de omega
function y = omega_optimo(A)
    y = 2 / (1 + sqrt(1 - radio_espectral_tj(A) ** 2))
endfunction


// Calcula el radio espectral de la matriz de iteracion de Jacobi.
//
// Parametros:
//   A - matriz de coeficientes
// Devuelve: radio espectral
function y = radio_espectral_tj(A)
    n = size(A, 1)
    for i = 1:n
        Ninv(i, i) = 1 / A(i, i)
    end
    y = max(abs(spec(eye(n, n) - Ninv * A)))
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
A = [10 -1 2 -1; 2 -20 3 -3; 1 1 10 0; 1 -1 4 30]
b = [-8 -20 -2 4]'
x = msor(A, b, [0 1 1 1], %eps, 1000, 1)
disp(x)

// Con omega optimo
A = [8 5 0 0; 1 9 1 0; 0 2 10 0; 0 0 3 7]
b = [-8 -20 -2 4]'
x = msor(A, b, [0 1 1 1], %eps, 1000, omega_optimo(A))
disp(x)
