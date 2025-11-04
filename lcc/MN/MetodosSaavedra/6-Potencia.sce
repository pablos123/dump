funcprot(0)
// Argumentos: Matriz, Aproximacion inicial, Condicion de corte, Maximo de iteraciones
// Devuelve el autovalor aproximado en la iteración n y el autovector aproximado zn
// Ej: [x, y] = mpotencia([ 12 1 3 4; 1 -3 1 5; 3 1 6 -2; 4 5 -2 1], [1 2 3 4]', %eps, 22000)
function [l, zn] = mpotencia(A, z0, eps, m)
    // Calculo w1
    w = A * z0;

    // Elijo una componente no nula de w1
    [m, j] = max(abs(w));

    // Calculo l1, en l estará el autovalor
    l = w(j) / z0(j);

    // Normalizo y obtengo z1
    zn = w / l;

    iter = 1;
    while (iter < m) && (norm(z0 - zn, %inf) > eps)
        z0 = zn;
        
        // Calculo wn
        w = A * z0;
        
        // Elijo una componente no nula de wn
        [m, j] = max(abs(w));

        // Calculo ln
        l = w(j) / z0(j);
        
        // Normalizo y obtengo zn
        zn = w / l;
        
        iter = iter + 1;
    end
    disp('Cantidad de iteraciones:');
    disp(iter);
endfunction

