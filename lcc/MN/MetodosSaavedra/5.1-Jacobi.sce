// ============================================================================
// 5.1 - Metodo de Jacobi
// Unidad 5: Sistemas de ecuaciones lineales - Metodos iterativos
// ============================================================================
funcprot(0)

// Metodo iterativo de Jacobi para resolver A*x = b.
// En cada iteracion calcula todas las componentes usando los valores
// de la iteracion anterior.
//
// Parametros:
//   A        - matriz de coeficientes
//   b        - vector de terminos independientes
//   x0       - aproximacion inicial
//   eps      - tolerancia del error
//   max_iter - maximo de iteraciones
// Devuelve: vector solucion aproximado
function xk = mjacobi(A, b, x0, eps, max_iter)
    if jacobi_asegura_convergencia(A) then
        printf('Se asegura convergencia del metodo\n')
    else
        printf('No asegura convergencia del metodo\n')
    end

    n = size(A, 1)
    xk = x0

    iter = 0
    while (iter == 0 || norm(xk - x0) > eps && iter < max_iter)
        x0 = xk
        for i = 1:n
            suma = 0
            for j = 1:i - 1
                suma = suma + A(i, j) * x0(j)
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


// Verifica si el metodo de Jacobi asegura convergencia.
// Calcula el radio espectral de la matriz de iteracion.
// Si es true podemos asegurar que para todo vector inicial el metodo converge.
// Si es false entonces podria converger para algun vector.
//
// Parametros:
//   A - matriz de coeficientes
// Devuelve: %t si asegura convergencia, %f si no
function converge = jacobi_asegura_convergencia(A)
    n = size(A, 1)
    for i = 1:n
        aii = A(i, i)
        if aii == 0
            converge = 0
            return
        end
        Ninv(i, i) = 1 / aii
    end
    converge = max(abs(spec(eye(n, n) - Ninv * A))) < 1
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
A = [10 -1 2 -1; 2 -20 3 -3; 1 1 10 0; 1 -1 4 30]
b = [-8 -20 -2 4]'
x = mjacobi(A, b, [0 1 1 1], %eps, 1000)
disp(x)
