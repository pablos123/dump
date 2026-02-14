// ============================================================================
// 5.2 - Metodo de Gauss-Seidel
// Unidad 5: Sistemas de ecuaciones lineales - Metodos iterativos
// ============================================================================
funcprot(0)

// Metodo iterativo de Gauss-Seidel para resolver A*x = b.
// A diferencia de Jacobi, usa los valores ya calculados de la iteracion
// actual (xk) en lugar de los de la iteracion anterior (x0) para las
// componentes j < i.
//
// Parametros:
//   A        - matriz de coeficientes
//   b        - vector de terminos independientes
//   x0       - aproximacion inicial
//   eps      - tolerancia del error
//   max_iter - maximo de iteraciones
// Devuelve: vector solucion aproximado
function xk = mgaussseidel(A, b, x0, eps, max_iter)
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
            xk(i) = 1 / A(i, i) * (b(i) - suma)
        end
        iter = iter + 1
    end
    printf("Iteraciones: %i\n", iter)
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
A = [10 -1 2 -1; 2 -20 3 -3; 1 1 10 0; 1 -1 4 30]
b = [-8 -20 -2 4]'
x = mgaussseidel(A, b, [0 1 1 1], %eps, 1000)
disp(x)
