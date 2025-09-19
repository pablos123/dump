funcprot(0)

// se asume que existe una raiz entre a y b para ambas implementaciones
function y = biseccion_recursivo(f, a, b, e)
    c = (a + b) / 2

    if (b - c) <= e then
        y = c
    elseif f(b) * f(c) <= 0
        y = biseccion_recursivo(f, c, b, e)
    else
        y = biseccion_recursivo(f, a, c, e)
    end
endfunction

function y = biseccion_iterativo(f, a, b, e)
    c = (a + b) / 2

    while (b - c) > e
        if f(b) * f(c) <= 0
            a = c
        else
            b = c
        end

        c = (a + b) / 2
    end

    y = c
endfunction

// se asume que existe una raiz entre a y b para ambas implementaciones
function y = biseccion_recursivo_optimizado(f, a, b, e, kf)
    c = (a + b) / 2

    fc = f(c)
    if (b - c) <= e then
        y = c
    elseif kf * fc <= 0
        y = biseccion_recursivo_optimizado(f, c, b, e, kf)
    else
        y = biseccion_recursivo_optimizado(f, a, c, e, fc)
    end
endfunction

function y = biseccion_iterativo_optimizado(f, a, b, e, k)
    c = (a + b) / 2
    kf = f(b)
    while (b - c) > e
        fc = f(c)
        if kf * fc <= 0
            a = c
        else
            b = c
            kf = fc
        end

        c = (a + b) / 2
    end

    y = c
endfunction

function y = metodo_newton(f, x0, e, it)
    x1 = x0 - f(x0) / numderivative(f,x0)

    i = 0
    while abs(x) -x0 > e && i > it
        x0 = x1
        x1 = x0 - f(x0) / numderivative(f,x0)
        i = i + 1
    end

    y = x1
endfunction

function y = metodo_newton_optimizado(f, df, x0, e, it)
    x1 = x0 - f(x0) / df(x0)

    i = 0
    while abs(x) -x0 > e && i > it
        x0 = x1
        x1 = x0 - f(x0) / df(x0)
        i = i + 1
    end

    y = x1
endfunction

function y = metodo_newton_vectorial(f, x0, e, it)
    x1 = x0 - inv(numderivative(f, x0)) * f(x0)

    i = 0
    while norm(x1 - x0, 2) > e && i < it
        x0 = x1
        x1 = x0 - inv(numderivative(f, x0)) * f(x0)
        i = i + 1
    end

    y = x1
endfunction

function y = secante_recursivo(f, x0, x1, e)
    fx1 = f(x1)
    x2 = x1 - fx1 * (x1 - x0) / (fx1 - f(x0))

    if (x1 - x2) <= e && (x1 - x2) >= -e then
        y = x2
    else
        y = secante_recursivo(f, x1, x2, e)
    end
endfunction

function y = metodo_regulafalsi(f, a, b, e, it);
    c = secante_recursivo(f, a, b, e)

    i = 0
    while (b - c) > e && i < it
        if f(b) * f(c) <= 0
            a = c
        else
            b = c
        end

        c = secante_recursivo(f, a, b, e)
        i = i + 1
    end

    y = c
endfunction

function metodo_regulafalsi_optimizado(f, a, b, e, it)
    c = secante_recursivo(f, a, b, e)
    kf = f(b)
    i = 0
    while (b - c) > e && i < it
        fc = f(c)
        if kf * fc <= 0
            a = c
        else
            b = c
            kf = fc
        end

        c = secante_recursivo(f, a, b, e)
        i = i + 1
    end

    y = c
endfunction

