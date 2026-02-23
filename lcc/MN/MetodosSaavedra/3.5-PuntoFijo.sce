// ============================================================================
// 3.3 - Metodo de Punto Fijo
// Unidad 3: Ecuaciones no lineales
// ============================================================================
funcprot(0)

// Metodo de Punto Fijo para encontrar raices.
// Se reformula f(x) = 0 como x = g(x) y se itera x_{n+1} = g(x_n)
//
// Parametros:
//   g        - funcion de iteracion tal que x = g(x) en la raiz
//   x0       - aproximacion inicial
//   eps      - tolerancia del error
//   max_iter - maximo de iteraciones
// Devuelve: aproximacion del punto fijo
function raiz = mpunto_fijo(g, x0, eps, max_iter)
    x1 = g(x0)

    iter = 1
    while abs(x1 - x0) > eps && iter < max_iter
        x0 = x1
        x1 = g(x0)
        iter = iter + 1
    end

    raiz = x1
endfunction


// ============================================================================
// Regla de la cadena (para verificar convergencia o construir derivadas)
// ============================================================================
// Si tenemos h(x) = f(g(x)), su derivada es:
//   h'(x) = f'(g(x)) * g'(x)
//
// Ejemplo con g(x) = log(1 + 2*x)^(1/3):
//   Llamamos u = log(1 + 2*x)       <- funcion interior
//   Llamamos v = u^(1/3)            <- funcion exterior
//
//   du/dx = 2 / (1 + 2*x)           <- derivada de la interior
//   dv/du = (1/3) * u^(-2/3)        <- derivada de la exterior
//
//   g'(x) = dv/du * du/dx
//         = (1/3) * log(1+2*x)^(-2/3) * 2/(1+2*x)


// ============================================================================
// Ejemplos
// ============================================================================
// Ejemplo 1: Raiz de x^3 - x - 2 = 0, reformulada como x = (x + 2)^(1/3)
deff("y = g(x)", "y = (x + 2)^(1/3)")
raiz = mpunto_fijo(g, 1.5, 1e-6, 100)
disp("Punto Fijo 1: raiz = " + string(raiz))

// Ejemplo 2: Raiz de x^3 - log(1 + 2*x) = 0, reformulada como x = log(1+2*x)^(1/3)
// (log es logaritmo natural en Scilab)
deff("y = g2(x)", "y = log(1 + 2*x)^(1/3)")
raiz2 = mpunto_fijo(g2, 0.5, 1e-6, 100)
disp("Punto Fijo 2: raiz = " + string(raiz2))
