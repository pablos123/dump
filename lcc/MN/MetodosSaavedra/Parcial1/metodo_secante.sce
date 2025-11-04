funcprot(0)

function y = secante_recursivo(f, x0, x1, e)
    fx1 = f(x1)
    x2 = x1 - fx1 * ((x1 - x0)/(fx1 - f(x0)))
    
    if (x1 - x2) <= e and (x1 - x2) >= -e then
        y = x2
    else
        y = secante_recursivo(f, x1, x2, e)
    end
endfunction

function y = secante_iterativo(f, a, b, e)
    ...
endfunction
