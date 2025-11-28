x0 = [0.2 0.4];
y0 = [1.2214 1.4918];

x1 = [0 0.2 0.4 0.6];
y1 = [1 1.2214 1.4918 1.8221];

global cgood
cgood=0

global cmocho
cmocho=0

function A = tabla_diferencias_divididas_count(x, y)
    n = length(x)
    A(1:n,1) = y'
    for j = 2:n // orden
        for i = j:n
            A(i, j) = (A(i, j-1) - A(i-1, j-1)) / (x(i) - x(i-j+1))
            cgood = cgood + 1
        end
    end
endfunction

function p = mNewtonDiferenciasDivididas_count(x, y)
    n = length(x)
    A = tabla_diferencias_divididas_count(x,y);
    equis = poly(0, "x")
    q = 1
    p = 0
    for i = 1:n 
        p = p + A(i,i) * q
        q = q * (equis-x(i))
        cgood = cgood + 1
    end
endfunction

p = mNewtonDiferenciasDivididas_count(x1,y1)


function w = DD_count(x, y)
    n = length(x);
    cmocho = cmocho + 1
    if n==1 then
        w = y(1)
    else
        w = (DD_count(x(2:n),y(2:n))-DD_count(x(1:n-1),y(1:n-1)))/(x(n)-x(1))
    end;
endfunction

function p = newtonMocho_count(x,y)
    r = poly(0,"x");
    p = 0;
    n= length(x);
    for i=n:(-1):2
        p = (p+DD_count(x(1:i),y(1:i)))*(r-x(i-1))
        cmocho = cmocho + 1
    end;
    p = p + y(1);
endfunction

pMocho = newtonMocho_count(x1,y1)

disp(cgood)
disp(cmocho)
