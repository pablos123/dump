// ============================================================================
// 7.1 - Interpolacion de Lagrange
// Unidad 7: Interpolacion y aproximacion polinomial
// ============================================================================
funcprot(0)

// Calcula el k-esimo polinomio base de Lagrange.
// Lk(x) = prod((x - x_j) / (x_k - x_j), j <> k)
//
// Parametros:
//   x - vector de nodos de interpolacion
//   k - indice del polinomio base
// Devuelve: polinomio base Lk
function y = Lk(x, k)
    n = length(x)
    r = [x(1:k - 1), x(k + 1:n)]
    p = poly(r, "x", "roots")
    pk = horner(p, x(k))
    y = p / pk
endfunction


// Interpolacion de Lagrange.
// Construye el polinomio interpolante P(x) = sum(y_k * Lk(x), k = 1..n).
//
// Parametros:
//   x         - vector de nodos de interpolacion
//   valores_y - vector de valores en los nodos
// Devuelve: polinomio interpolante
function polinomio = mlagrange(x, valores_y)
    n = length(x)
    p = 0
    for k = 1:n
        p = p + Lk(x, k) * valores_y(k)
    end
    polinomio = p
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
x = [0 1 2 3]
y = [1 2 1 4]
p = mlagrange(x, y)
disp("Polinomio interpolante:")
disp(p)
disp("Evaluacion en x=1.5: " + string(horner(p, 1.5)))
