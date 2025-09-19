funcprot(0)

function y = secante_recursivo(f, x0, x1, e)
    fx1 = f(x1)
    x2 = x1 - fx1 * (x1 - x0) / (fx1 - f(x0))

    if abs(x1 - x2) <= e then
        y = x2
    else
        y = secante_recursivo(f, x1, x2, e)
    end
endfunction

function y = metodo_secante(f, x0, x1, e, it)
    fx1 = f(x1)

    x2 = x1 - fx1 * (x1 - x0) / (fx1 - f(x0))

    i = 0
    while abs(x1 - x2) > e && i < it then
        x0 = x1
        x1 = x2

        fx1 = f(x1)

        x2 = x1 - fx1 * (x1 - x0) / (fx1 - f(x0))

        i = i + 1
    end

    y = x2
endfunction
