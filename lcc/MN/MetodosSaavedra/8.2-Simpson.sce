funcprot(0);

function y = simpson(a, b, f)
    h = (b - a) / 2
    y = h / 3 * (f(a) + 4 * f(a + h) + f(b))
endfunction

function t = simpson_compuesto(a, b, f, n)
    if modulo(n, 2) == 1 then
        t = 0;
        disp("n tiene que ser par.");
        return
    end

    h = (b - a) / n;
    t = f(a) + f(b);

    for i = 1:2:n-1
        t = t + 4 * f(a + i * h);
    end

    for i = 2:2:n-2
        t = t + 2 * f(a + i * h);
    end

    t = h / 3 * t;
endfunction

// Pasar el c haciendo un estudio de la función eligiendo el valor que maximiza el error en ese intervalo.
function err = cota_error_simpson(a, b, f, f_deriv_cuarta, c)
    h = (b - a) / 2;
    err = -(h ** 5 / 90 * f_deriv_cuarta(c));
endfunction

// Pasar el c haciendo un estudio de la función eligiendo el valor que maximiza el error en ese intervalo.
function err = cota_error_simpson_compuesto(a, b, f, n, f_deriv_cuarta, c)
    h = (b - a) / n;
    err = -(h ** 4 * (b - a)  / 180 * f_deriv_cuarta(c));
endfunction
