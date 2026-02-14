// ============================================================================
// 6.1 - Metodo de la Potencia
// Unidad 6: Autovalores y autovectores
// ============================================================================
funcprot(0)

// Metodo de la potencia para encontrar el autovalor dominante y su autovector.
// En cada iteracion calcula w = A*z, normaliza y obtiene el autovalor.
//
// Parametros:
//   A        - matriz cuadrada
//   z0       - aproximacion inicial del autovector
//   eps      - tolerancia del error
//   max_iter - maximo de iteraciones
// Devuelve: [autovalor, autovector] autovalor dominante y su autovector
function [autovalor, autovector] = mpotencia(A, z0, eps, max_iter)
    // Calculo w1
    w = A * z0

    // Elijo una componente no nula de w1
    [valor_max, j] = max(abs(w))

    // Calculo l1, en autovalor estara el autovalor
    autovalor = w(j) / z0(j)

    // Normalizo y obtengo z1
    autovector = w / autovalor

    iter = 1
    while (iter < max_iter) && (norm(z0 - autovector, %inf) > eps)
        z0 = autovector

        // Calculo wn
        w = A * z0

        // Elijo una componente no nula de wn
        [valor_max, j] = max(abs(w))

        // Calculo ln
        autovalor = w(j) / z0(j)

        // Normalizo y obtengo zn
        autovector = w / autovalor

        iter = iter + 1
    end
    printf("Cantidad de iteraciones: %i\n", iter)
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
A = [12 1 3 4; 1 -3 1 5; 3 1 6 -2; 4 5 -2 1]
[autovalor, autovector] = mpotencia(A, [1 2 3 4]', %eps, 22000)
disp("Autovalor dominante:")
disp(autovalor)
disp("Autovector:")
disp(autovector)

A2 = [2 -1 0; -1 2 -1; 0 -1 2]
[autovalor2, autovector2] = mpotencia(A2, [1 1 1]', %eps, 1000)
disp("Autovalor dominante:")
disp(autovalor2)
disp("Autovector:")
disp(autovector2)
