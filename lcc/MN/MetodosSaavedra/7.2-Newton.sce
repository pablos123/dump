funcprot(0);

function A = tabla_diferencias_divididas(x, y)
    n = length(x);
    A(1:n, 1) = y';
    for j = 2:n // Orden
        for i = j:n
            A(i, j) = (A(i, j - 1) - A(i - 1, j - 1)) / (x(i) - x(i - j + 1));
        end
    end
endfunction


function p = mnewton(x, y)
    n = length(x);
    A = tabla_diferencias_divididas(x, y);
    equis = poly(0, "x");
    q = 1;
    p = 0;
    for i = 1:n
        p = p + A(i, i) * q;
        q = q * (equis - x(i));
    end
endfunction

// -----------------------------------------------------------------------------
// No óptimo, de la cátedra.
function w = DD(x,y)
    n = length(x);

    if n==1 then
        w = y(1);
    else
        w = (DD(x(2:n), y(2:n)) - DD(x(1:n-1), y(1:n-1))) / (x(n) - x(1));
    end;
endfunction

function p = newton_no_tabla(x,y)
    r = poly(0, "x");
    p = 0;
    n= length(x);
    for i=n:(-1):2
        p = (p+DD(x(1:i),y(1:i)))*(r-x(i-1));
    end
    p = p + y(1);
endfunction
