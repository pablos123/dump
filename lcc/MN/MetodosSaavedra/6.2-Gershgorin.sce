// ============================================================================
// 6.2 - Discos de Gershgorin
// Unidad 6: Autovalores y autovectores
// ============================================================================
funcprot(0)

// Dibuja un circulo en el plano complejo.
//
// Parametros:
//   r - radio del circulo
//   x - coordenada x del centro
//   y - coordenada y del centro
function dibujar_circulo(r, x, y)
    xarc(x - r, y + r, 2 * r, 2 * r, 0, 360 * 64)
endfunction


// Dibuja los discos de Gershgorin de una matriz y sus autovalores.
// Cada disco tiene centro en a_{ii} y radio sum(|a_{ij}|, j <> i).
// Los autovalores de A estan contenidos en la union de los discos.
//
// Parametros:
//   A - matriz cuadrada
function gershgorin(A)
    [n, m] = size(A)
    centros = diag(A)
    radios = sum(abs(A), 'c') - abs(centros)

    // Buscamos calcular un rectangulo que contenga a todos los circulos
    // Esquina inferior izquierda
    x_min = round(min(centros - radios) - 1)
    y_min = round(min(-radios) - 1)

    // Esquina superior derecha
    x_max = round(max(centros + radios) + 1)
    y_max = round(max(radios) + 1)

    rectangulo = [x_min y_min x_max y_max]

    // Dibujamos los autovalores
    plot2d(real(spec(A)), imag(spec(A)), -1, "031", "", rectangulo)
    replot(rectangulo)
    xgrid()

    for i = 1:n
        dibujar_circulo(radios(i), centros(i), 0)
    end
endfunction


// ============================================================================
// Ejemplos
// ============================================================================
A = [4 1 0; 1 3 1; 0 1 4]
gershgorin(A)

// A2 = [10 -1 2; -1 5 -2; 2 -2 8]
// gershgorin(A2)
