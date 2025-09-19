funcprot(0)

// Se asume que existe una raiz entre a y b para ambas implementaciones
function y = biseccion_recursivo(f, a, b, e, kf)
    c = (a + b) / 2

    fc = f(c)
    if (b - c) <= e then
        y = c
    elseif kf * fc <= 0
        y = biseccion_recursivo(f, c, b, e, kf)
    else
        y = biseccion_recursivo(f, a, c, e, fc)
    end
endfunction

// Este método se basa en el Teorema de Bolzano. Suponemos que f(x) es contínua
// en [a, b] y que f(a)f(b) < 0. Luego f(x) = 0 tiene al menos una raíz en dicho intervalo.
// Dada una toleracia del error eps > 0, el método de la bisección consiste en los siguiente pasos:
// 1) Definir c = (a + b) / 2
// 2) Si b - c <= eps, aceptar c como la raíz y detenerse.
// 3) Si b - c > eps, comparar el signo de f(c) con el de f(a) y f(b) . Si f(b)f(c) <= 0,
// reemplazar a con c. En caso contrario reemplazar b con c. Regresar al paso 1.

// f = function
// a = a
// b = b
// e = error
// it = max iters
function y = metodo_biseccion(f, a, b, e, it)
    c = (a + b) / 2

    fb = f(b)

    i = 0
    while (b - c) > e && i < it
        fc = f(c)
        if fb * fc <= 0
            a = c
        else
            b = c
            fb = fc
        end

        c = (a + b) / 2

        i = i + 1
    end

    y = c
endfunction
