funcprot(0);

function y = trapecio(a, b, f)
    h = b - a;
    y = h / 2 * (f(a) + f(b));
endfunction

function t = trapecio_compuesto(a, b, f, n)
    h = (b - a) / n;
    t = (f(a) + f(b)) / 2;

    for i = 1:n-1
        t = t + f(a + i * h);
    end

    t = h * t;
endfunction

// Pasar el c haciendo un estudio de la función eligiendo el valor que maximiza el error en ese intervalo.
function err = cota_error_trapecio(a, b, f, f_deriv_seg, c)
    h = b - a;
    err = - (h ** 3 / 12 * f_deriv_seg(c));
endfunction

// Pasar el c haciendo un estudio de la función eligiendo el valor que maximiza el error en ese intervalo.
function err = cota_error_trapecio_compuesto(a, b, f, n, f_deriv_seg, c)
    h = (b - a) / n;
    err = - (h ** 2 / 12 * (b - a) * f_deriv_seg(c));
endfunction

// Auxiliares

function z = sin_doble(x, y)
    z = sin(x + y);
endfunction

function y = log_dos(x)
    y = -1 ./ (x.^2);
endfunction
