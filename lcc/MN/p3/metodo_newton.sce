funcprot(0)

function y = metodo_newton(f, df, x0, e, it)
    x1 = x0 - f(x0) / df(x0)

    i = 0
    while abs(x1 - x0) > e && i < it
        x0 = x1
        x1 = x0 - f(x0) / df(x0)
        i = i + 1
    end

    y = x1
endfunction

// inv_df = inv(df(f))
function y = metodo_newton_vectorial(f, inv_df, x0, e, it)
    x1 = x0 - inv_df(x0) * f(x0)

    i = 0
    while norm(x1 - x0, 2) > e && i < it
        x0 = x1
        x1 = x0 - inv_df(x0) * f(x0)
        i = i + 1
    end

    y = x1
endfunction

