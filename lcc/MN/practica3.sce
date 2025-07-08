//1) 
deff('y=f1(x)', 'y=1 + (cos(x) * ((exp(x) + exp(-x))/ 2))')
function y = dibujar(f, x)
  plot(x,f)
  a=gca();
  a.x_location = "origin";
  a.y_location = "origin";
  xgrid(2)
  y = 0
endfunction

// --> dibujar(f1, [0:0.1:8])
// Podemos ver que las primeras 3 raices positivas son aproximadamente:
// x1 = 2
// x2 = 4.5
// x3 = 8



//2) 

function c = metodoBiseccion(a,b,funcion,eps)
    c = (a+b)/2
    f_b = funcion(b)
    while(b - c > eps)
        f_c = funcion(c)
        if(f_b * f_c <= 0)
            a = c
            f_a = f_c
            c = (b+a)/2
        else
            b = c
            f_b = f_c
            c = (a+b)/2
        end  
    end
endfunction



function y = fTest1(x)
    y = ((x^2)/2) - sin(x)
endfunction

/*
metodoBiseccion(-0.01, 0.01, fTest1, 0.01)
 ans  =

   0.
   
metodoBiseccion(1.2, 1.6, fTest1, 0.01)
 ans  =

   1.4043457
*/

/*
3)
*/

function res = fTest(x)
    res = (x^2)/4 - sin(x)
endfunction

function raiz = metodoSecante(x0, x1, funcion, eps, maxIteraciones)
    bandera = %F;
    iteraciones = 0;
    while(~bandera && (iteraciones < maxIteraciones))
        f_x0 = funcion(x0)
        f_x1 = funcion(x1)
        raiz = x1 - f_x1*((x1-x0)/(f_x1 - f_x0))
        if((funcion(raiz) < eps))
            bandera = %T
            iteraciones = iteraciones + 1;
        else
            x0 = x1
            x1 = raiz
            iteraciones = iteraciones + 1;
        end
    end
    if(iteraciones == maxIteraciones)
        raiz = %nan
    end
    printf("Numero de iteraciones realizadas: %d",iteraciones)
endfunction

/*
metodoSecante(2,2.5,fTest,0.00001,100000)
Numero de iteraciones realizadas: 4 ans  =

   1.9337538
   
metodoSecante(2,2.5,fTest,0.0001,100000)
Numero de iteraciones realizadas: 3 ans  =

   1.9337782

*/


/*
4)

Podemos observar que si se aplica reiteradamente la función coseno a un
valor, estos valores en el infinito convergen a un punto fijo.

metodoPuntoFijo(cos,1.51,0.0001,1000000)
 ans  =

   0.7391299
*/

/*
5)

Tenemos que g(x) = 2^(x-1)

Sea a = -1 (arbitrariamente) y b = 1.51

Vemos que g(a) = 2^(a-1) = 2 ^ ((-1) -1) = 1/4 = 0.25
y que g(b) = 2^(1.51-1) = 1.42


x < 1.5287 => |g'(x)| < 1 :D (*)

Ya vimos para que valores converge*, veamos a qué converge:

*/

function y = metodoPuntoFijo(g, x0, eps, maxIteraciones)
    iteraciones = 0
    
    while ( abs(g(x0)-x0) >= eps && iteraciones < maxIteraciones)
        x0 = g(x0)
        iteraciones = iteraciones + 1
    end
    
    if iteraciones == maxIteraciones then
        printf("Se alcanzaron el maximo de iteraciones")
        y = %nan
    else 
        y = x0
    end
endfunction

function y = fTest5(x)
    y = 2^(x-1)
endfunction

/*
metodoPuntoFijo(fTest5,1.51,0.0001,1000000)
 ans  =

   1.0002487


--> metodoPuntoFijo(fTest5,0.51,0.0001,1000000)
 ans  =

   0.9997048


--> metodoPuntoFijo(fTest5,-0.51,0.0001,1000000)
 ans  =

   0.9997585


--> metodoPuntoFijo(fTest5,-1.51,0.0001,1000000)
 ans  =

   0.9997264

Vemos que para x = 1.8 no podemos saber cual sera el comportamiento, aunque vemos que converge a 1 en el testeo.
metodoPuntoFijo(fTest5,1.8,0.0001,100000)
 ans  =

   1.0002466
   
y esto?

metodoPuntoFijo(fTest5,2,0.0001,1000000)
 ans  =

   2.

Vemos que converge a alfa = 1 por lo que el límite es 1.
*/

/*
6)
x+c(x^2−5) :=g(x)
g'(x) = 1 + 2x*c

g(-raiz(5)) = -raiz(5) y g y g' son re continuas

El enunciado pide que converja a este alfa=-raiz(5), por lo que
si usamos el Corolario 1, queremos obtener el resultado a)

Queremos entonces |g'(alfa)| < 1 => |g'(-raiz(5))| < 1 => |1 + 2-sqrt(5)*c| < 1
=> -1 < 1 + 2-sqrt(5)*c < 1

Si resolvemos la inecuación obtenemos:

0 < c < 1 / raiz(5)
*/

/*
7)
w^2 = gdtanh(hd)
<=>
(2pi/T) = g(2pi/l)tanh(h(2pi/l))
...
*/

function y = longOnda(d)
    y = (25 * 9.8 * tanh(4 * d) * 2) / (4*%pi)
endfunction


/*
a)
l = metodoPuntoFijo(longOnda,2,0.0001,1000)

eps = 0.1 porque quiero que mi presición sea de un digito

metodoPuntoFijo(longOnda,1, 0.1, 1000)
 ans  =

   38.966808

b)
*/

function y = metodoNewton(f, x0, eps, maximoIteraciones)
    y = x0 - (f(x0)/numderivative(f, x0))
    iteracion = 0
    while(iteracion < maximoIteraciones && eps < abs(y - x0))
        y = y -  (f(y)/numderivative(f, y))
        iteracion = iteracion + 1
    end
   
    if iteracion == maximoIteraciones then
        y = %nan
    end
    
endfunction


/*
8)
Podemos ver para que valores, las derivadas de las funciones que tengo son menores que uno.

La derivada de g1 = e^x/3. Luego nos queda que g1' < 1 sii x < ln3

Tomamos un valor menor supongamos 1 y aplicamos punto fijo.

metodoPuntoFijo(g1, 1, 0.001, 100)
 ans  =

   0.6213663

Por lo tanto g1 sirve para sacar una de las soluciones de la raiz.

g2 actua de la misma manera con la derivada = g2' = 1/2 (e^x - 1) tenemos que g2' es menor a uno sii x < ln3. Luego probando con 1 tenemos: 

metodoPuntoFijo(g2, 1, 0.001, 100)
 ans  =

   0.6201262

g3 derivada nos queda 1/x  luego tenemos que los valores donde es menor a uno sii  x > 1 o x < -1 y logaritmo esta definido apra los positivos. si calculamos el punto fijo con x = 1.5:

metodoPuntoFijo(g3, 1.5, 0.001, 100)
 ans  =

   1.5097911

g4 derivada nos queda e^x - 2 que nos da menor a 1 sii ln3 > x > 0, probando con 1 tenemos:

metodoPuntoFijo(g4, 1, 0.001, 100)
 ans  =

   0.6197558

*/


function y = g1(x)
    y = exp(x)/3
endfunction

function y = g2(x)
    y = (1/2) * (exp(x) - x)
endfunction

function y = g3(x)
    y = log(3 * x)
endfunction

function y = g4(x)
    y = exp(x) - (2 * x)
endfunction

/*
0 = 1 +x2−y2+e^xcosy

0 = 2xy+e^xsiny

9)
Pasar maximo iteraciones igual a 5
*/

function y = newtonMultivariable(functionlist, vx, eps, maximoIteraciones)
    vx = vx'
    y = vx
    J = numderivative(functionlist, y) 
    invJ = inv(J)
    y = y - (invJ * functionlist(y))
    iteracion = 1
    while (norm(y - vx) >= eps && iteracion < maximoIteraciones)
        J = numderivative(functionlist, y) 
        invJ = inv(J)
        vx = y
        y = y - (invJ * functionlist(y))
        iteracion = iteracion + 1
    end   
endfunction


function f = functionlist9(x)
    f1 = 1 + x(1)^2 - x(2)^2 + exp(x(1)) * cos(x(2))    
    f2 = 2 * x(1) * x(2) + exp(x(1)) * sin(x(2))
    f = [f1; f2]
endfunction

/*
10) PASARLE VX con lo que pide el ENUNCIADO

11)

Calculamos primero las dos derivadas parciales para poder aplicar el metodo de newton al sistema de ecuaciones dado por el vector del gradiente igualado al vector nulo. Tenemos las funciones:
f1 = 2 + e^(2 * x_1^2 + x_2^2) * 4 * x_1 
f2 = 6x_2 + e^(2 * x_1^2 + x_2^2) * 2 * x_2
*/

//Definimos la función f

function y = functionlist11(x)
    f1 = 2 + exp(2 * x(1)^2 + x(2)^2) * 4 * x(1)
    f2 = 6 * x(2) + exp(2 * x(1)^2 + x(2)^2) * 2 * x(2)
    y = [f1; f2]
endfunction

/*Primer resultado para cumplir (i), resolvemos newtonMultivariable(function11, [1, 1], 1.000D-12, 1000)

newtonMultivariable(functionlist11, [1, 1], 1.000D-12, 1000)
 ans  =

  -0.3765446
   4.162D-28
 
b)
Para verificar el resultado, calculemos las cuatro derivadas de la matriz hessiana, luego reemplazamos con los valores de a) y nos fijamos que todas las entradas sean positivas.
*/

/*
12)
Creamos nuestras 3 funciones:
*/

function y = functionlist12(x)
    f1 = x(1) * exp(x(2)) + x(3) - 10
    f2 = x(1) * exp(x(2) * 2) + x(3) * 2 - 12
    f3 = x(1) * exp(x(2) * 3) + x(3) * 3 - 15
    y = [f1; f2; f3]
endfunction


/*
Aplicando el metodo de newton con [1,2,3], la distancia en pies, tenemos que:

newtonMultivariable(functionlist12, [1 2 3], 0.00001, 100)
 ans  =

   8.7712864
   0.2596954
  -1.3722813


b)
tenemos la derivada primera cuando da 0 y la derivada segunda nos fijamos que da xd y listo  VER nuestra funcion nueva pensada por lxs chicxs es: 0 =  k_1 * e^(k_2 * r) + k_3 * r - 500/pi*r^2
*/


/*
Metodo regula falsi
*/


function y = metodoRegulaFalsi(f, x0, x1,eps)
    //tenemos convergencia garantizada
    f_x0 = funcion(x0)
    f_x1 = funcion(x1)
    
    if f_x0 * f_x1 < 0 then
        y = []
    else
        while f(c) >= eps
            c = x1 - f_x1*((x1-x0)/(f_x1 - f_x0))
            if f_x0*f(c) < 0 then
                x1 = c
            end
            if f_x0*f(c) < 0 then
                x0 = c
            end
        end
    end
    y = c
endfunction








