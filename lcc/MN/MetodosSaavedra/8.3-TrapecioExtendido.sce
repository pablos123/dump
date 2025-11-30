funcprot(0);

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
