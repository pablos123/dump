// ============================================================================
// 7.2 - Interpolacion de Newton
// Unidad 7: Interpolacion y aproximacion polinomial
// ============================================================================
funcprot(0)

// Construye la tabla de diferencias divididas.
//
// Parametros:
//   x - vector de nodos
//   y - vector de valores en los nodos
// Devuelve: matriz triangular inferior con las diferencias divididas
function A = tabla_diferencias_divididas(x, y)
    n = length(x)
    A(1:n, 1) = y'
    for j = 2:n
        for i = j:n
            A(i, j) = (A(i, j - 1) - A(i - 1, j - 1)) / (x(i) - x(i - j + 1))
        end
    end
endfunction


// Interpolacion de Newton usando tabla de diferencias divididas.
//
// Parametros:
//   x - vector de nodos
//   y - vector de valores en los nodos
// Devuelve: polinomio interpolante
function p = mnewton(x, y)
    n = length(x)
    A = tabla_diferencias_divididas(x, y)
    equis = poly(0, "x")
    q = 1
    p = 0
    for i = 1:n
        p = p + A(i, i) * q
        q = q * (equis - x(i))
    end
endfunction


// Diferencia dividida calculada recursivamente (no optimo, de la catedra).
//
// Parametros:
//   x - vector de nodos
//   y - vector de valores
// Devuelve: diferencia dividida
function w = diferencia_dividida_recursiva(x, y)
    n = length(x)

    if n == 1 then
        w = y(1)
    else
        w = (diferencia_dividida_recursiva(x(2:n), y(2:n)) - diferencia_dividida_recursiva(x(1:n - 1), y(1:n - 1))) / (x(n) - x(1))
    end
endfunction


// Interpolacion de Newton usando diferencias divididas recursivas.
//
// Parametros:
//   x - vector de nodos
//   y - vector de valores
// Devuelve: polinomio interpolante
function p = mnewton_recursivo(x, y)
    r = poly(0, "x")
    p = 0
    n = length(x)
    for i = n:(-1):2
        p = (p + diferencia_dividida_recursiva(x(1:i), y(1:i))) * (r - x(i - 1))
    end
    p = p + y(1)
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
x = [0 1 2 3]
y = [1 2 1 4]

p = mnewton(x, y)
disp("Newton (tabla):")
disp(p)

p2 = mnewton_recursivo(x, y)
disp("Newton (recursivo):")
disp(p2)
