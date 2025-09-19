function aproximacion = metodoLagrangeSinPolinomio(x, y, valorAproximar)
    n = size(x,"c") //calculamos el grado del polinomio interpolador
    aproximacion = 0 //inicializamos ya que luego vamos a sumar sucesivamente
    L = ones(1,n) //inicializamos ya que luego vamos a multiplicar sucesivamente
    for k=1:n
        for i=1:n
            if i <> k then
                L(k) = L(k) * ((valorAproximar-x(i))/(x(k) - x(i))) //calculamos la k-esima L siguiendo el algoritmo
            end
        end
        aproximacion = aproximacion + L(k)*y(k) //evaluamos el polinomio interpolador en nuestro x de interés
    end
endfunction

//Toma un vector de x y un numero k y devuelve la función Lk correspondiente a utilizar en el método de Lagrange
function P = Lk(x,k)
    n = length(x)
    P = (poly(x(1:k-1),"x",['roots'])*poly(x(k+1:n),"x",['roots'])) //numerador
    divisor = 1
    for i=1:n
        if i <> k then
            divisor = divisor * (x(k) - x(i))
        end
    end
    P = P / divisor
endfunction

//Toma un vector de x y un vector de y con las imágenes de los x y aproxima la función dada por los puntos por el método de lagrange
function polinomio = metodoLagrange(x,y)
    n = length(x)
    polinomio = 0
    for i=1:n
        polinomio = polinomio + Lk(x,i) * y(i) //acumulo cada sumando
    end
endfunction
/*
Casos de prueba:

metodoLagrangeSinPolinomio([0 0.2 0.4 0.6], [1.0 1.2214 1.4918 1.8221], 0.5)
 ans  =

   1.6487812

--> pTest1 = metodoLagrange([0 0.2 0.4 0.6], [1.0 1.2214 1.4918 1.8221])
 pTest1  = 

                          2            3
   1 +1.0026667x +0.47625x  +0.2270833x 


--> horner(pTest1,0.5)
 ans  =

   1.6487813
     
metodoLagrangeSinPolinomio([-3 -2 -1 0], [0.0498 0.1353 0.3679 1], -0.5)
 ans  =

   0.6182375

--> pTest2 = metodoLagrange([-3 -2 -1 0], [0.0498 0.1353 0.3679 1])
 pTest2  = 

                          2            3
   1 +0.9159833x +0.32595x  +0.0420667x 
--> horner(pTest2,-0.5)
 ans  =

   0.6182375
      
metodoLagrangeSinPolinomio([-3 -2 -1 0], [0.0498 0.1353 0.3679 1], -2)
 ans  =

   0.1353

--> pTest3 = metodoLagrange([-3 -2 -1 0], [0.0498 0.1353 0.3679 1])
 pTest3  = 

                          2            3
   1 +0.9159833x +0.32595x  +0.0420667x
  
--> horner(pTest3,-2)
 ans  =

   0.1353
 
*/
//Devuelve el valor de D_i, donde i es el tamaño del vector x disminuido en 1.
function valor = diferenciasDivididas(x, y)
    n = size(x,"c")
    if n == 1 then //D_0
        valor = y(n) 
    else //orden n
        valor = (diferenciasDivididas(x(2:n),y(2:n)) - diferenciasDivididas (x(1:n-1),y(1:n-1))) / (x(n) - x(1))
    end
   
endfunction

//Metodo de Newton encajado
function aproximacion = metodoNewtonSinPolinomio(x, y, valorAproximar)
    n = size(x, "c")
    //corchete más interno
    aproximacion = diferenciasDivididas(x(1:n-1),y(1:n-1)) + ((valorAproximar - x(n-1)) * diferenciasDivididas(x,y))
    i = n-2
    while (i > 0)
        aproximacion = diferenciasDivididas(x(1:i),y(1:i)) + ((valorAproximar - x(i)) * aproximacion)
        i = i - 1
    end
endfunction

function aproximacion = metodoNewton(x, y)
    n = size(x, "c")
    //corchete más interno
    aproximacion = diferenciasDivididas(x(1:n-1),y(1:n-1)) + (poly(x(n-1),"x",["roots"]) * diferenciasDivididas(x,y))
    i = n-2 //avanzo hacia la izquierda
    while (i > 0)   
        aproximacion = diferenciasDivididas(x(1:i),y(1:i)) + (poly(x(i),"x",["roots"]) * aproximacion)
        i = i - 1
    end
endfunction

/*
Casos de prueba

--> metodoNewtonSinPolinomio([0 0.2 0.4 0.6], [1.0 1.2214 1.4918 1.8221], 0.5)
 ans  =

   1.6487813

--> pTestN1 = metodoNewton([0 0.2 0.4 0.6], [1.0 1.2214 1.4918 1.8221])
 pTestN1  = 

                          2            3
   1 +1.0026667x +0.47625x  +0.2270833x 


--> horner(pTestN1,0.5)
 ans  =

   1.6487813
   
--> metodoNewton([-3 -2 -1 0], [0.0498 0.1353 0.3679 1], -0.5)
 ans  =

   0.6182375

--> pTestN2 = metodoNewton([-3 -2 -1 0], [0.0498 0.1353 0.3679 1])
 pTestN2  = 

                          2            3
   1 +0.9159833x +0.32595x  +0.0420667x 


--> horner(pTestN2,-0.5)
 ans  =

   0.6182375
     
metodoNewton([-3 -2 -1 0], [0.0498 0.1353 0.3679 1], -2)
 ans  =

   0.1353


--> pTestN3 = metodoNewton([-3 -2 -1 0], [0.0498 0.1353 0.3679 1])
 pTestN3  = 

                          2            3
   1 +0.9159833x +0.32595x  +0.0420667x 


--> horner(pTestN3,-2)
 ans  =

   0.1353

*/

/*
VERSION NO ENCAJADA PROVISORIA

function P = metodoNewtonNoEncajado(v,w)
    n=length(v);
    P=w(1);
    for k = 2:n
    P = P + diferenciasDivididas(v(1 :k),w(1 :k)) * poly(v(1 :k-1),"x",["roots"]);
    end
endfunction
*/

    
/*
Ejercicio 1) a)

//Interpolacion lineal:

metodoLagrangeSinPolinomio([0.2 0.4], [1.2214 1.4918], 1/3)
 ans  =

   1.4016667

--> p1a = metodoLagrange([0.2 0.4], [1.2214 1.4918])
 p1a  = 

                
   0.951 +1.352x

--> horner(p1a,1/3)
 ans  =

   1.4016667
   
--> P1aN1 = metodoNewton([0.2 0.4], [1.2214 1.4918])
 P1aN1  = 

                
   0.951 +1.352x


--> horner(P1aN1,1/3)
 ans  =

   1.4016667

//Interpolacion cubica:

metodoLagrangeSinPolinomio([0 0.2 0.4 0.6], [1.0 1.2214 1.4918 1.8221], 1/3)
 ans  =

   1.3955494
   
--> p1a2 = metodoLagrange([0 0.2 0.4 0.6], [1.0 1.2214 1.4918 1.8221])
 p1a2  = 

                          2            3
   1 +1.0026667x +0.47625x  +0.2270833x
--> horner(p1a2,1/3)
 ans  =

   1.3955494

 
--> p1aN2 = metodoNewton([0 0.2 0.4 0.6], [1.0 1.2214 1.4918 1.8221])
 p1aN2  = 

                          2            3
   1 +1.0026667x +0.47625x  +0.2270833x 


--> horner(p1aN2,1/3)
 ans  =

   1.3955494

1) b)

Cota con interpolación lineal: 

En este caso f(x) = exp(x)

f''(x) = exp(x)

Luego, el error de interpolacion |f(x)-p1(x)| en [0.2,0.4] esta dado por:

|error| <= max |f(x) - p1(x)| \forall x0 <= x <= x1
<==> x = 1/3
|error <= 1/2 * max |(x-x0)(x-x1)| * max|exp(x)| \forall x \in [0.2,0.4]

Para el caso general:
Quiero encontrar el x \in [0.2,0.4] tal que maximice |(x-x0)(x-x1)|
es decir, quiero maximizar |(x-0.2)(x-0.4)| y al ser esta funcion una función concava, podemos encontrar el maximo en su punto estacionario (donde la derivada es nula), esto sucede en 0,3 ==> max|(x-0.2)(x-0.4)| = 0.01 

Pero, para nuestro caso x=1/3 nos queda:

|E| <= |1/2 * (1/3-0.2)*(1/3-0.4)| * max|exp(x)|

exp(x) es una funcion creciente, por lo tanto el maximo se obtendrá en 0.4

Quedando:

|E| <= 4.44x10-3 * |exp(0.4)| = 6.63x10-3
 
Error int. lineal : |1.395612425 - 1.4016667| = 0.0060543


Cota con interpolación cubica: 

f''(x) = exp(x)

Luego, el error de interpolacion |f(x)-p3(x)| en [0,0.6] esta dado por:

|error| <= max |f(x) - p3(x)| \forall x0 <= x <= x3
<==> x = 1/3
|error <= 1/fact(4) * max |(x-x0)(x-x1)(x-x2)(x-x3)| * max|exp(x)| \forall x \in [0,0.6]

Para nuestro caso x=1/3 nos queda:

|E| <= |1/24 * 1/3*(1/3-0.2)(1/3-0.4)(1/3-0.6)| * max|exp(x)|

exp(x) es una funcion creciente, por lo tanto el maximo se obtendrá en 0.6

Quedando:

|E| <= 3.29x10-5 * |exp(0.6)| = 5.99x10-5


Error int. cubica: |1.3955494 - 1.395612425| = 0.000063


Ejercicio 2 

// Por el Teorema 3 (Error de la Interpolación Polinómica)
// sabemos que para x0, x1,..., xn distintos en [a, b],
// para todo x en [a, b] existe ξ en (a, b) tal que

// f(x) - p(x) = (x - x0)(x - x1)...(x-xn) / (n+1)! * f^(n+1) (ξ) 

// donde p(x) es el polinomio interpolante de f para los puntos xi

// Sabiendo que f es un polinomio de orden menor o igual que n, 
// la derivada f^(n+1) (x) = 0 para todo x en [a, b]

// Por lo tanto f(x) = p(x) para todo x en [a, b]

// Dado que este razonamiento vale para cualquier conjunto [a, b]
// que contenga a los xi, vale para todo x en R

// Por lo tanto f(x) = p(x) para todo x



Ejercicios 3 EN PAPEL

Ejercicio 4. Nota: tabulacion = h

Calculo de error EN PAPEL
*/

x4 = [2 2.1 2.2 2.3 2.4 2.5]
y4 = [.2239 .1666 .1104 .0555 .0025 -.0484]

pol4 = metodoNewton(x4,y4)

/*
--> aprox1 = horner(pol4,2.15)
 aprox1  = 

   0.1383688


--> aprox2 = horner(pol4,2.35)
 aprox2  = 

   0.0287313
   
   
Ejercicio 5

f(0) = 1
f(1) = 3
f(2) = 3
f(3) = ?

Pero si se que: P_0,1,2,3(2.5) = L0*y0+L1*y1+L2*y2+L3*y3 = 3
<==>
y3 = 3-L0(2.5)y0-L1(2.5)y1-L2(2.5)y2 / L3(2.5)

L0(2.5) = (2.5-1)(2.5-2)(2.5-3) / (0-1)(0-2)(0-3) = 0.0625

L1(2.5) = (2.5-0)(2.5.2)(2.5-3) / (1-0)(1-2)(1-3) = -0.3125

L2(2.5) = (2.5 -0)(2.5-1)(2.5-3) / (2-0)(2-1)(2-3) = 0.9375

L3(2.5) = (2.5-0)(2.5-1)(2.5-2) / (3-0)(3-1)(3-2) = 0.3125

y3 = 3 - 0.0625*1 - -0.3125 * 3 - 0.9375 * 3 / 0.3125

y3 = 3.4

Por lo tanto,

--> pol5 = metodoLagrange([0 1 2 3], [1 3 3 3.4])
 pol5  = 

                2      3
   1 +3.8x -2.2x  +0.4x 
--> horner(pol5,2.5)
 ans  =

   3.
*/

//Ejercicio 6

//a)

/*
 2 + (x+1) + (x+1)(x-1)(-2) + (x+1)(x-1)(x-2)2
 
 <==>
 
 3 + x + (x^2-1)(-2) + (x^3-2x^2-x+2)2
 
 <==>
 
 3 + x - 2x^2 + 2 + 2x^3 -2x - 4x^2 + 4
 
 <==>
 
 2x^3 - 6x^2 - x + 9
*/

polyEj6 = poly([9 -1 -6 2],"x",["coeff"])

//b)

/*
--> horner(polyEj6,0)
 ans  =

   9.
*/
   
//c)

/*

Ya tenemos una de nuestras 2 cotas necesarias. 

Ahora nos queda maximizar \phi(x), es decir: 

phi(x) = (x+1)(x-1)(x-2)(x-4)

Podemos ver que phi'(x) = 4x^3-18x^2+14x+6.

Además, phi'(x) = 0 <==> x = -0.303 v x = 1.5 v x = 3.303

Evaluando la función en cada uno de los puntos, podemos ver
que x = 1.5 maximiza a phi en [-1,4] con phi(1.5)=1.563

Por lo tanto, la cota del error de aproximar f(0) nos queda expresada como:


|f(0) - p3(0)| <= 1/4! * 1.563 * 33.6 <= 2.1882

*/

//método de mínimos cuadrados en forma matricial.
//Toma los puntos x y sus imágenes y y calcula la aproximacion
//por minimos cuadrados con grado n y su correspondiente error.
function[P,ERR] = minimoscuadradosMatricial(x,y,n)
    m=length(x);
    A=zeros(m,n+1); //inicializo matriz de phi's
    
    for i = 1:m
        for j = 1:n+1
            A(i,j) =x(i)^(j-1); //actualizo el valor de la matriz a por el valor dado en la ecuacion
        end
    end
    
    Amin=A'*A; //A^T * A
    bmin=A'*y'; //A^T * b
    
    //Dado que Amin suele ser una matriz pequeña, calculamos los coeficientes (es decir la solucion al sistema)
    a=inv(Amin)*bmin;
    
    P=poly(a,"x",["coeff"]);    //armamos el polinomio con los coeficientes obtenidos
    ERR=norm(A*a-y');   //error de aproximación
endfunction
    
// Ejercicio 7 

x7 = [0  .15     .31     .5      .6      .75]
y7 = [1  1.004   1.31    1.117   1.223   1.422]

// polinomio grado 1

/*
--> minimoscuadradosMatricial(x7,y7,1)
 ans  =

                        
   0.9960666 +0.4760174x
*/

// polinomio grado 2

/*
--> minimoscuadradosMatricial(x7,y7,2)
 ans  =

                                   2
   1.007732 +0.3542987x +0.1635646x 
*/


// polinomio grado 3

/*
--> minimoscuadradosMatricial(x7,y7,3)
 ans  =

                                    2          3
   0.9653196 +1.6154731x -4.3450249x  +3.97241x 

*/

// Ejercicio 8

x8 = [4      4.2     4.5     4.7     5.1     5.5     5.9     6.3     6.8     7.1]
y8 = [102.56 113.18  130.11  142.05  167.53  195.14  224.87  256.73  299.5   326.72]

/*
a)
--> [p1_8,err1_8] = minimoscuadradosMatricial(x8,y8,1)
 err1_8  = 

   18.138721

 p1_8  = 

                        
  -194.13824 +72.084518x

[p2_8,err1_8] = minimoscuadradosMatricial(x8,y8,2)
 err1_8  = 

   0.0379857

 p2_8  = 

                                    2
   1.2355604 -1.1435234x +6.6182109x 
   
--> [p3_8,err1_8] = minimoscuadradosMatricial(x8,y8,3)
Ojota->
Warning :
matrix is close to singular or badly scaled. rcond = 2.3131E-10
 err1_8  = 

   0.0229639

 p3_8  = 

                                    2            3
   3.4290944 -2.3792211x +6.8455778x  -0.0136746x 

*/
/* 
b)

Graficos

[p1_8,err1_8] = minimoscuadradosMatricial(x8,y8,1)
plot(x8,horner(p1_8,x8))
scatter(x8,y8)

[p2_8,err2_8] = minimoscuadradosMatricial(x8,y8,2)
plot(x8,horner(p2_8,x8))


[p3_8,err3_8] = minimoscuadradosMatricial(x8,y8,3)
plot(x8,horner(p3_8,x8))
*/

//Ejercicio 9

//Armamos el siguiente conjunto de datos
//Tomamos los nodos uniformemente espaciados desde -5 a 5 con h = 1

x9 = [-5:5]

function y = leyFuncion9(x)
    y = 1./((x^2) + 1)
endfunction

function y = fEj9(x)
    tam = size(x,"c")
    for i=1:tam
        y(i) = leyFuncion9(x(i))
    end

endfunction

y9 = fEj9(x9)

function y = error9 (x, polinomio)
    y = leyFuncion9(x) - horner(polinomio,x) 
endfunction


[pol9Grado2, cotaError2] = minimoscuadradosMatricial(x9,y9',2)
[pol9Grado4, cotaError4] = minimoscuadradosMatricial(x9,y9',4)
[pol9Grado6, cotaError6] = minimoscuadradosMatricial(x9,y9',6)
[pol9Grado10, cotaError10] = minimoscuadradosMatricial(x9,y9',10)
[pol9Grado14, cotaError14] = minimoscuadradosMatricial(x9,y9',14)

pol9Grado2 = metodoLagrange(x9,y9)

intervaloPlot = [-5:.1:5]
/*

En este gráfico se puede observar que el error en 0 por ejemplo está cerca de 0.5
plot([-5:.1:5], list(error9, pol9Grado2), 'green')
plot([-5:.1:5], list(error9, pol9Grado4),'magenta')
plot([-5:.1:5], list(error9, pol9Grado6),'blue')
plot([-5:.1:5], list(error9, pol9Grado10),'red')
plot([-5:.1:5], list(error9, pol9Grado14),'cyan')
---------------------------------------------------
plot2d(intervaloPlot, leyFuncion9(intervaloPlot) - horner(pol9Grado2, intervaloPlot), style = color('green'))
plot2d(intervaloPlot, leyFuncion9(intervaloPlot) - horner(pol9Grado4, intervaloPlot), style = color('magenta'))
plot2d(intervaloPlot, leyFuncion9(intervaloPlot) - horner(pol9Grado6, intervaloPlot), style = color('blue'))
plot2d(intervaloPlot, leyFuncion9(intervaloPlot) - horner(pol9Grado10, intervaloPlot), style = color('red'))
plot2d(intervaloPlot, leyFuncion9(intervaloPlot) - horner(pol9Grado14, intervaloPlot), style = color('cyan'))

A medida que aumenta n, la diferencia aumenta. Gráficos simétricos. Es una clara observación del fenómeno de Runge.
*/

// Ejercicio 10

//Obtiene n raices del polinomio de Chebyshev
function r = raicesChebyshev(n)
    for k=0:n-1
        r(k+1) = cos(((%pi/2)*(1+2*k))/n)
    end
endfunction

//a)
x10 = raicesChebyshev(4)
y10 = exp(x10')

p3_10 = minimoscuadradosMatricial(x10,y10,3)

//b)


function y = error10 (x)
    y = exp(x) - horner(p3_10,x)
endfunction

//plot([-1:1], error10)


// Ejercicio 11

function r = raicesDesfasadas(n, a, b)
    rcp = raicesChebyshev(n)
    
    for k=0:n-1
        r(k+1) = ((b + a) + rcp(k+1) * (b - a) / 2)
    end
endfunction

x11 = raicesDesfasadas(4, 0, %pi/2)
y11 = cos(x11')

p11 = minimoscuadradosMatricial(x11,y11,3)

intervaloGraficar = linspace(0,%pi/2,20)
/*
plot(intervaloGraficar, cos(intervaloGraficar),'b')
plot(intervaloGraficar, horner(p11,intervaloGraficar),'r')
*/
