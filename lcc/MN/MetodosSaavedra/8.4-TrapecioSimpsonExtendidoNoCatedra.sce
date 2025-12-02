function I = trapecio(f,x0,x1)
     I = (x1-x0)*(f(x0)+f(x1))/2
endfunction

// Funcion cota error traprecio

function I = trapecioComp(f,a,b,n)
    h = (b-a)/n
    accum = f(a)/2 + f(b)/2
    for j=1:n-1
        accum = accum + f(a + j*h)
    end
    I = h*accum
endfunction

// Funcion cota error trapecioComp

function I = simpson(f,a,b)
    h = (b-a)/2
    I = h*(f(a)+4*f(a+h)+f(b))/3
endfunction

function I = simpsonComp(f,a,b,n)
    if modulo(n,2) <> 0 then
        printf("Error Simpson Compuesto, n no es par")
        abort
    end
    h = (b-a)/n
    accum = f(a) + f(b)
    for j=1:2:n-1
            accum = accum + 4*f(a + j*h)
    end
    for j=2:2:n-1
            accum = accum + 2*f(a + j*h)
    end
    I = (h/3)*accum
endfunction

// -------------- Integracion Numerica en dominio bidimensional ---------

function I = trapecioExt(f,a,b,c,d)
    h = (b-a)*(d-c)/4
    I = h*(f(c,a)+f(c,b)+f(d,a)+f(d,b))
endfunction

// Trapecio para f de 2 variables con x fijo
function I = trapecioCompDoblex(f,xi,a,b,n)
    h = (b-a)/n
    contador = f(xi,a)*1/2 + f(xi,b)*1/2
    for j = 1:n-1
        contador = contador + f(xi,a+j*h)
    end
    I = h*contador
endfunction

// Trapecio para f de 2 variables con y fijo
function y = trapecioCompDobley(f,yi,a,b,n)
    h = (b-a)/n
    contador = f(a,yi)*1/2 + f(b,yi)*1/2
    for j = 1:n-1
        contador = contador + f(a+j*h,yi)
    end
    I = h*contador
endfunction

// Metdodo de simpson para f de dos variables con x fija
function I = simpsonCompDoblex(f,xi,a,b,n)
    if modulo(n,2) <> 0 then
        disp("N no es par")
        I = %nan
        return
    end
    h = (b-a)/n
    I = f(xi,a)+f(xi,b)
    for i = 1:2:n-1
        I = I+4*f(xi,a+i*h)
    end
    for i = 2:2:n-1
        I = I+2*f(xi,a+i*h)
    end
    I = I*h/3
endfunction

// Metdodo de simpson para f de dos variables con y fija
function I = simpsonCompDobley(f,yi,a,b,n)
    if modulo(n,2) <> 0 then
        disp("N no es par")
        I = %nan
        return
    end
    h = (b-a)/n
    I = f(a,yi)+f(b,yi)
    for i = 1:2:n-1
        I = I+4*f(a+i*h,yi)
    end
    for i = 2:2:n-1
        I = I+2*f(a+i*h,yi)
    end
    I = I*h/3
endfunction

// Metodo del Trapecio para f de 2 variables
// Con dydx (Primero se integra 'y' luego 'x')
function I = TrapecioBiYX(f,a,b,c,d,n,m)
    // a,b valores de integral exterior
    // c,d valores de integral interior (Se reciben como funcion, si se quiere constante ingresar funciones constantes)
    // n intervalos entre a y b
    // m intervalos en c(x) d(x)
    hx = (b-a)/n
    I = trapecioCompDoblex(f,a,c(a),d(a),m)/2 + trapecioCompDoblex(f,b,c(b),d(b),m)/2
    for i = 1:n-1
        xi = a+i*hx
        I = I + trapecioCompDoblex(f,xi,c(xi),d(xi),m)
    end
    I = hx*I
endfunction

// Metodo del Trapecio para f de 2 variables
// Con dxdy (Primero se integra 'x' luego 'y')
function I = TrapecioBiXY(f,a,b,c,d,n,m)
    // a,b valores de integral exterior
    // c,d valores de integral interior (Se reciben como funcion, si se quiere constante ingresar funciones constantes)
    // n intervalos entre a y b
    // m intervalos en c(y) d(y)
    hy = (b-a)/n
    I = trapecioCompDobley(f,a,c(a),d(a),m)/2 + trapecioCompDobley(f,b,c(b),d(b),m)/2
    for i = 1:n-1
        yi = a+i*hy
        I = I + trapecioCompDoblex(f,yi,c(yi),d(yi),m)
    end
    I = hx*I
endfunction

// Metodo de Simpson para f de 2 variables
// Con dydx (Primero se integra 'y' luego 'x')
function I = SimpsonCompBiYX(f,a,b,c,d,n,m)
    // a,b valores de integral exterior
    // c,d valores de integral interior (Se reciben como funcion, si se quiere constante ingresar funciones constantes)
    // n intervalos entre a y b
    // m intervalos en c(x) d(x)
    // m y n deben ser par
    if modulo(n,2) <> 0 then
        disp("N no es par")
        I = %nan
        return
    end
    hx = (b-a)/n
    I = simpsonCompDoblex(f,a,c(a),d(a),m) + simpsonCompDoblex(f,b,c(b),d(b),m)
    for i = 1:2:n-1
        xi = a+i*hx
        I = I + 4*simpsonCompDoblex(f,xi,c(xi),d(xi),m)
    end
    for i = 2:2:n-1
        xi = a+i*hx
        I = I + 2*simpsonCompDoblex(f,xi,c(xi),d(xi),m)
    end
    I = I*hx/3
endfunction

// Metodo de Simpson para f de 2 variables
// Con dxdy (Primero se integra 'x' luego 'y')
function I = SimpsonCompBiXY(f,a,b,c,d,n,m)
    // a,b valores de integral exterior
    // c,d valores de integral interior (Se reciben como funcion, si se quiere constante ingresar funciones constantes)
    // n intervalos entre a y b
    // m intervalos en c(y) d(y)
    // m y n deben ser par
    if modulo(n,2) <> 0 then
        disp("N no es par")
        I = %nan
        return
    end
    hy = (b-a)/n
    I = simpsonCompDobley(f,a,c(a),d(a),m) + simpsonCompDobley(f,b,c(b),d(b),m)
    for i = 1:2:n-1
        yi = a+i*hy
        I = I + 4*simpsonCompDoblex(f,yi,c(yi),d(yi),m)
    end
    for i = 2:2:n-1
        yi = a+i*hy
        I = I + 2*simpsonCompDoblex(f,yi,c(yi),d(yi),m)
    end
    I = I*hy/3
endfunction


// METODOS INTEGRACION BIDIMENSIONAL DADOS EN CLASE

// Funcion que toma una funcion, un intervalo y una cantidad de subIntervalos.
function res = metodoCompTrapecio(fx, a, b, n)
    // Inicializamos h y res
    h = (b-a)/n;
    res = 0;
    // Iteramos sobre todos los subintervalos.
    for i = 0:n
        xn = a + i*h;
        // Si el intervalo es el primero o el ultimo dividimos f(xn) por 2.
        if(i == 0 | i == n)
            res = res + fx(xn)/2;
        // En caso contrario no.
        else
            res = res + fx(xn);
        end
    end
    // Multiplicamos todo por h.
    res = res * h;
endfunction


// Fucnion que calcula el metodo compuesto de Simpson.
function res = metodoCompSimpson(fx, a, b, n)
    // Inicializamos h y res.
    h = (b-a)/n
    res = 0

   // Primer intervalo.
    res = res + fx(a + 0*h)
    // Iteramos sobre los n subintervalos.
    for i = 1:n-1

        // Si el subintervalo es par.
        if (pmodulo(i,2) == 0)
            res = res + 2*fx(a + i*h);
        // Caso impar.
        else
            res = res + 4*fx(a + i*h);
        end

    end
    // Ultimos intervalo.
    res = res + fx(a + n*h)
    // Multiplicamos por h/3
    res = res * h/3;
endfunction

// Funcion que calcula la integral numerica de dominio bidimensional,
// utilizando el metodo de Simpson.
// Toma la funcion, los extremos del primer intervalo, las fucniones del segundo
// y la cntidad de subintervalos de la primer integral y la cantidad de subintervalos
// de la segunda.
function y = dominioBiSimpson(f,a,b,cx,dx,n,m)
    // Inicializamos h
    h = (b-a)/n
    deff('z=fxa(x)','z=f(a,x)')
    deff('z=fxb(x)','z=f(b,y)')

    // Calculamos la segunda integral.
    temp = metodoCompSimpson(fxa,cx(a),dx(a),m) + metodoCompSimpson(fxb,cx(b),dx(b),m)

    // Calculamos la primera, en todos los subintervalos pedidos.
    for i=1:n-1
        xi = a+i*h
        deff('z=aux(y)','z=f(xi,y)')
        // Aplicamos el metodo como corresponde segun simpson.
        if pmodulo(i,2) == 0 then
            temp = temp + 2*(metodoCompSimpson(aux,cx(xi),dx(xi),m))
        else
            temp = temp + 4*(metodoCompSimpson(aux,cx(xi),dx(xi),m))
        end
    end
    y = (h/3) * temp
endfunction

// Funcion que calcula la integral numerica de dominio bidimensional,
// utilizando el metodo de Trapecio.
// Toma la funcion, los extremos del primer intervalo, las funciones del segundo
// y la cantidad de subintervalos de la primer integral y la cantidad de subintervalos
// de la segunda.
function y = dominioBiTrapecio(f,a,b,cx,dx,n,m)
    // Inicializamos h
    h = (b-a)/n

    deff('z=fxa(y)','z=f(a,y)')
    deff('z=fxb(y)','z=f(b,y)')

    // Calculamos la segunda integral.
    temp = (metodoCompTrapecio(fxa, cx(a),dx(a),m)/2) + (metodoCompTrapecio(fxb,cx(b),dx(b),m)/2)

    // Calculamos la primera, en todos los subintervalos pedidos.
    for i=1:n-1
        xi = a+i*h
        deff('z=aux(y)','z=f(xi,y)')
        temp = temp + (metodoCompTrapecio(aux,cx(xi),dx(xi),m))
    end
    y = h * temp
endfunction



// -------------------- Ejercicio 1 ----------------------
/*
printf("(#) - a)\n")
inf = 1
sup = 2

I1 = trapecio(log,inf,sup)
I2 = simpson(log,inf,sup)

printf("Aproximacion trapecio: %f\n",I1)
printf("Aproximacion simpson: %f\n",I2)
printf("Valor scilab: %f\n", intg(inf,sup,log))


printf("\n(#) - b)\n")
function y = funb(x)
    y = x^(1/3)
endfunction
inf = 0
sup = 0.1

I1 = trapecio(funb,inf,sup)
I2 = simpson(funb,inf,sup)

printf("Aproximacion trapecio: %f\n",I1)
printf("Aproximacion simpson: %f\n",I2)
printf("Valor scilab: %f\n", intg(inf,sup,funb))

printf("\n(#) - c)\n")

function y = funC(x)
    y = sin(x)**2
endfunction
inf = 0
sup = %pi/3

I1 = trapecio(funC,inf,sup)
I2 = simpson(funC,inf,sup)

printf("Aproximacion trapecio: %f\n",I1)
printf("Aproximacion simpson: %f\n",I2)
printf("Valor scilab: %f\n", intg(inf,sup,funC))*/


// -------------------- EJERCICIO 2 y 3 ---------------------------
/*
function y = fun1(x)
    y = 1/x
endfunction

function y = fun2(x)
    y = x**3
endfunction

function y = fun3(x)
    y = x*sqrt(1+x**2)
endfunction

function y = fun4(x)
    y = sin(%pi*x)
endfunction

function y = fun5(x)
    y = x*sin(x)
endfunction

function y = fun6(x)
    y = exp(x)*x**2
endfunction


printf("\n(#) - a)\n")
inf = 1
sup = 3
n = 4
rango = inf:((sup-inf)/n):sup
m =size(rango)(2)
valores = zeros(m,1)
for i=1:m
    valores(i)=fun1(rango(i))
end

I1 = trapecioComp(fun1,inf,sup,n)
I2 = simpsonComp(fun1,inf,sup,n)
I = inttrap(rango', valores)

printf("Aproximacion trapecio compuesto: %f\n", I1)
printf("Aproximacion trapecio compuesto Scilab: %f\n", I)
printf("Aproximacion simpson compuesto: %f\n", I2)

printf("\n(#) - b)\n")
inf = 0
sup = 2
n = 4
rango = inf:((sup-inf)/n):sup
m =size(rango)(2)
valores = zeros(m,1)
for i=1:m
    valores(i)=fun2(rango(i))
end

I1 = trapecioComp(fun2,inf,sup,n)
I2 = simpsonComp(fun2,inf,sup,n)
I = inttrap(rango', valores)

printf("Aproximacion trapecio compuesto: %f\n", I1)
printf("Aproximacion trapecio compuesto Scilab: %f\n", I)
printf("Aproximacion simpson compuesto: %f\n", I2)

printf("\n(#) - c)\n")
inf = 0
sup = 3
n = 6
rango = inf:((sup-inf)/n):sup
m =size(rango)(2)
valores = zeros(m,1)
for i=1:m
    valores(i)=fun3(rango(i))
end

I1 = trapecioComp(fun3,inf,sup,n)
I2 = simpsonComp(fun3,inf,sup,n)
I = inttrap(rango', valores)

printf("Aproximacion trapecio compuesto: %f\n", I1)
printf("Aproximacion trapecio compuesto Scilab: %f\n", I)
printf("Aproximacion simpson compuesto: %f\n", I2)

printf("\n(#) - d)\n")
inf = 0
sup = 1
n = 8
rango = inf:((sup-inf)/n):sup
m =size(rango)(2)
valores = zeros(m,1)
for i=1:m
    valores(i)=fun4(rango(i))
end

I1 = trapecioComp(fun4,inf,sup,n)
I2 = simpsonComp(fun4,inf,sup,n)
I = inttrap(rango', valores)

printf("Aproximacion trapecio compuesto: %f\n", I1)
printf("Aproximacion trapecio compuesto Scilab: %f\n", I)
printf("Aproximacion simpson compuesto: %f\n", I2)

printf("\n(#) - e)\n")
inf = 0
sup = 2*%pi
n = 8
rango = inf:((sup-inf)/n):sup
m =size(rango)(2)
valores = zeros(m,1)
for i=1:m
    valores(i)=fun5(rango(i))
end

I1 = trapecioComp(fun5,inf,sup,n)
I2 = simpsonComp(fun5,inf,sup,n)
I = inttrap(rango', valores)

printf("Aproximacion trapecio compuesto: %f\n", I1)
printf("Aproximacion trapecio compuesto Scilab: %f\n", I)
printf("Aproximacion simpson compuesto: %f\n", I2)

printf("\n(#) - f)\n")
inf = 0
sup = 1
n = 8
rango = inf:((sup-inf)/n):sup
m =size(rango)(2)
valores = zeros(m,1)
for i=1:m
    valores(i)=fun6(rango(i))
end

I1 = trapecioComp(fun6,inf,sup,n)
I2 = simpsonComp(fun6,inf,sup,n)
I = inttrap(rango', valores)

printf("Aproximacion trapecio compuesto: %f\n", I1)
printf("Aproximacion trapecio compuesto Scilab: %f\n", I)
printf("Aproximacion simpson compuesto: %f\n", I2)*/


// --------------------EJERCICIO 4--------------------
/*
function y = funCuatro(x)
    y = 1/(x+1)
endfunction

inf = 0
sup = 1.5
n = 10
//rango = inf:((sup-inf)/n):sup


I1 = trapecioComp(funCuatro,inf,sup,n)
I2 = simpsonComp(funCuatro,inf,sup,n)

Ireal = 0.9262907
printf("Aproximacion trapecio compuesto: %f\n", I1)
printf("Aproximacion simpson compuesto: %f\n", I2)
printf("Valor real: %f\n", Ireal)
printf("Error trapecio compuesto: %f\n",abs(I1-Ireal))
printf("Error simpson compuesto: %f\n",abs(I2-Ireal))*/


// ------------------- EJERCICIO 5 -------------------------------------
/*
function y = const0(x)
    y = 0
endfunction

function y = const1(x)
    y = 1
endfunction

function z = sin2(x,y)
    z = sin(x+y)
endfunction

inf = 0
sup = 2
I = TrapecioBiXY(sin2,inf,sup,const0,const1,2,2)

printf("Aproximacion trapecio compuesto bidimensional: %f\n", I)*/


// ---------------- EJERCICIO 6 ---------------------------------------

function y = cosenoinf(x)
    y = -sqrt(2*x - x**2)
endfunction
function y = cosenosup(x)
    y = sqrt(2*x - x**2)
endfunction

function z = circulo(x,y)
    z = 1
endfunction

inf = 0
sup = 2
n = 500
m = 500

I1 = TrapecioBiYX(circulo,inf,sup,cosenoinf,cosenosup,n,m)
I2 = SimpsonCompBiYX(circulo,inf,sup,cosenoinf,cosenosup,n,m)

printf("Aproximacion area circulo por trapecio compuesto bidimensional: %f\n", I1)
printf("Aproximacion area circulo por simpson compuesto bidimensional: %f\n", I2)
printf("Pi/2 == %f\n",%pi)
printf("error I1: %f\n",abs(I1-%pi))
printf("error I2: %f\n",abs(I2-%pi))






