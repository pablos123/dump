// ============================================================================
// graficar - Grafica una o varias funciones y un conjunto de puntos
// ============================================================================
funcprot(0)

// Grafica una funcion/polinomio o una lista de hasta 3 funciones/polinomios
// sobre [a, b] y un conjunto de puntos (x_pts, y_pts).
// Cada curva se dibuja en un color distinto (azul, verde, magenta).
// Los puntos se dibujan en rojo.
//
// Parametros:
//   f      - funcion, polinomio, o list() de hasta 3 funciones/polinomios
//   x_pts  - vector de coordenadas x de los puntos
//   y_pts  - vector de coordenadas y de los puntos
//   a      - extremo izquierdo del intervalo
//   b      - extremo derecho del intervalo
function graficar(f, x_pts, y_pts, a, b)
    curve_colors = list('b-', 'g-', 'm-')
    x   = linspace(a, b, 300)
    leg = []

    clf()

    if type(f) == 15 then  // list de funciones
        n = min(length(f), 3)
        for i = 1:n
            fi = f(i)
            if type(fi) == 2 then
                y = horner(fi, x)
            else
                y = fi(x)
            end
            plot(x, y, curve_colors(i))
            leg = [leg; "Funcion " + string(i)]
        end
    else  // funcion o polinomio unico
        if type(f) == 2 then
            y = horner(f, x)
        else
            y = f(x)
        end
        plot(x, y, curve_colors(1))
        leg = ["Funcion"]
    end

    plot(x_pts, y_pts, 'ro', 'markersize', 8, 'markerfacecolor', 'r')

    legend([leg; "Puntos"])
    xgrid()
endfunction


// ============================================================================
// Ejemplo con una sola funcion
// ============================================================================
// function y = f(x)
//    y = sin(x)
// endfunction
// x_pts = [0, %pi/4, %pi/2, 3*%pi/4, %pi]
// y_pts = sin(x_pts)
// graficar(f, x_pts, y_pts, 0, %pi)

// ============================================================================
// Ejemplo con multiples funciones
// ============================================================================
// function y = f1(x), y = sin(x),    endfunction
// function y = f2(x), y = cos(x),    endfunction
// function y = f3(x), y = sin(2*x),  endfunction
// x_pts = [0, %pi/4, %pi/2, 3*%pi/4, %pi]
// y_pts = sin(x_pts)
// graficar(list(f1, f2, f3), x_pts, y_pts, 0, %pi)
