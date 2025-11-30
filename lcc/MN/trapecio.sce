funcprot(0);

// TRAPECIO

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

function y = log_dos(x)
    y = -1 ./ (x.^2);
endfunction

// x = [0.5:0.1:2]';
// y = log_dos(x);
// plot2d(x, y)

// SIMPSON

function y = simpson(a, b, f)
    h = (b - a) / 2
    y = h / 3 * (f(a) + 4 * f(a + h) + f(b))
endfunction

function t = simpson_compuesto(a, b, f, n)
    if modulo(n, 2) == 1 then
        t = 0
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

// INTEGRALES DOBLES

// Esto funciona cuando c(x) d(x) son funciones constantes.
function v = trapecio_extendido(a, b, f, c, d)
    h1 = (b - a) / 2;
    h2 = (d - c) / 2;
    h = h1 * h2;

    v = h * (f(c, a) + f(c, b) + f(d, a) + f(d, b));
endfunction

// Trapecio extendido con una grilla n * n
// Esto funciona cuando c(x) d(x) son funciones constantes.
function v = trapecio_extendido_grilla_n(a, b, f, c, d, n)
    w = b - a;
    h = d - c;
    w_intervalo = w / n;
    h_intervalo = h / n;

    // Vértices;
    v = (f(c, a) + f(c, b) + f(d, a) + f(d, b)) / 4;

    v_aristas = 0;
    for i = 1:n-1
        // Aristas filas y columnas
        current_w = a + i * w_intervalo;
        current_h = c + i * h_intervalo;

        v_aristas = v_aristas + f(d, current_w) + f(c, current_w) + f(current_h, a) + f(current_h, b);

        // Internos
        for j = 1:n-1
            current_h = c + j * h_intervalo;
            v = v + f(current_h, current_w);
        end
    end

    v = w_intervalo * h_intervalo * (v + v_aristas / 2);
endfunction

function z = sin_doble(x, y)
    z = sin(x + y);
endfunction

// Trapecio doble integral con funciones no constantes con n intervalos.
// n intervalos para la aproximación de la integral doble
// m intervalos para el cálculo de cada integral en las iteraciones
function v = trapecio_doble_integral_n(a, b, c, d, f, n, m)
    h = (b - a) / n;

    deff("z=fxa(y)", "z=f(" + string(a) + ", y)");
    deff("z=fxb(y)", "z=f(" + string(b) + ", y)");

    v = (trapecio_compuesto(c(a), d(a), fxa, m) + trapecio_compuesto(c(b), d(b), fxb, m)) / 2;

    for i = 1:n-1
        xi = a + i * h;
        deff("z=fxi(y)", "z=f(" + string(xi) + ", y)");
        v = v + trapecio_compuesto(c(xi), d(xi), fxi, m);
    end

    v = h * v;
endfunction
