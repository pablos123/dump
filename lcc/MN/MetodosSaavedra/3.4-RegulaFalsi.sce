// ============================================================================
// 3.4 - Metodo de Regula Falsi
// Unidad 3: Ecuaciones no lineales
// ============================================================================
funcprot(0)

// Metodo de Regula Falsi (falsa posicion).
// Similar a biseccion pero usa interpolacion lineal para elegir el punto.
// Formula: c = b - f(b) * (b - a) / (f(b) - f(a))
//
// Parametros:
//   f        - funcion continua
//   a        - extremo izquierdo del intervalo
//   b        - extremo derecho del intervalo
//   eps      - tolerancia del error
//   max_iter - maximo de iteraciones
// Devuelve: aproximacion de la raiz
function raiz = metodo_regulafalsi(f, a, b, eps, max_iter)
    fb = f(b)
    fa = f(a)

    c = b - fb * (b - a) / (fb - fa)

    iter = 1
    while (b - c) > eps && iter < max_iter
        fc = f(c)
        if fb * fc <= 0
            a = c
            fa = fc
        else
            b = c
            fb = fc
        end

        c = b - fb * (b - a) / (fb - fa)
        iter = iter + 1
    end

    raiz = c
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
deff("y = f(x)", "y = x^3 - x - 2")
raiz = metodo_regulafalsi(f, 1, 2, 1e-6, 100)
disp("Regula Falsi: raiz = " + string(raiz))
