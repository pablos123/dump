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

// Test functions
function y = cuadrado_menos_uno(x)
    y = x * x - 1
endfunction

