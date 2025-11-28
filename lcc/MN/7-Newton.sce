funcprot(0)

function y = Lk(x, k)
    n = length(x);
    r = [x(1:k-1),x(k+1:n)];
    p = poly(r,"x","roots");
    pk = horner(p,x(k));
    y = p/pk;
endfunction

function y = mlagrange(x,y)
    n = length(x);
    p = 0;
    for k = 1:n
        p = p + Lk(x,k) * y(k)
    end
    y = p;
endfunction

// 1

x0 = [0.2 0.4];
y0 = [1.2214 1.4918];
p0 = mlagrange(x0,y0);
a0 = horner(p0,1/3)
err_exacto = abs(1.3956124225 - a0)

x1 = [0 0.2 0.4 0.6];
y1 = [1 1.2214 1.4918 1.8221];
p1 = mlagrange(x1,y1);
a1 = horner(p1,1/3)
err_exacto = abs(1.3956124225 - a1)

disp(p0)
disp(p1)

function A = tabla_diferencias_divididas(x, y)
    n = length(x)
    A(1:n,1) = y'
    for j = 2:n // orden
        for i = j:n
            A(i, j) = (A(i, j-1) - A(i-1, j-1)) / (x(i) - x(i-j+1))
        end
    end
endfunction


function p = mNewtonDiferenciasDivididas(x, y)
    n = length(x)
    A = tabla_diferencias_divididas(x,y);
    equis = poly(0, "x")
    q = 1
    p = 0
    for i = 1:n 
        p = p + A(i,i) * q
        q = q * (equis-x(i))
    end
endfunction

p = mNewtonDiferenciasDivididas(x1,y1)

disp(p)

// No óptimo, de la cátedra.
function w=DD(x,y)
    n = length(x);
    if n==1 then
        w = y(1)
    else
        w = (DD(x(2:n),y(2:n))-DD(x(1:n-1),y(1:n-1)))/(x(n)-x(1))
    end;
endfunction

function p = newton_no_tabla(x,y)
    r = poly(0,"x");
    p = 0;
    n= length(x);
    for i=n:(-1):2
        p = (p+DD(x(1:i),y(1:i)))*(r-x(i-1))
    end;
    p = p + y(1);
endfunction

p = newton_no_tabla(x1, y1)
disp(p)
