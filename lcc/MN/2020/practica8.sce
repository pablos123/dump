/***********Metodos***********/
function area = reglaDelTrapecio(x0,x1,f)
    h = x1 - x0  
    area = h/2 * (f(x0) + f(x1))
endfunction

function area = reglaDeSimpson(x0,x2,fx)
    h = (x2 - x0)/2
    x1 = x0 + h
    
    area = h/3 * (fx(x0) + 4*fx(x1)+fx(x2))
    
endfunction

//Usando log_e esta todo ok
//Usando deff tira unefined n si f no esta al final (xd?)
function area = reglaTrapecioCompuesta(x0, x1, n, fx)
    h = (x1 - x0)/n
    area = 1/2 * fx(x0) //a
    for i=1:(n-1)
        x0 = x0 + h //sobreescribimos a ya que no lo volveremos a usar
        area = area + fx(x0)
    end
    area = area + 1/2 * fx(x1)  //b
    area = h * area
endfunction

function area = reglaDeSimpsonCompuesta(x0, x1, n, fx)
    h = (x1 - x0)/n
    area = fx(x0) + fx(x1)  //a y b
    for i = 1:(n-1)
        x0 = x0 + h
        if modulo(i, 2) == 0 then   //caso indice sumando par
            area = area + 2*fx(x0)
        else
            area = area + 4*fx(x0)  //caso indice sumando impar
        end
    end
    area = area * (h/3)
    
endfunction


/******Auxiliares******/
function y = log_e(x)
    y = log(x)/log(%e)
endfunction

/*******Ejercicios**********/

//Ejercicio 1

// i)

/* 
a)
--> reglaDelTrapecio(1,2,log_e)
 ans  =

   0.3465736

--> reglaDeSimpson(1,2,log_e)
 ans  =

   0.3858346
   
b)
--> reglaDelTrapecio(0,0.1,deff('x = f(y)','x = y^(1/3)'))
 ans  =

   0.0232079
   
--> reglaDeSimpson(0,0.1,deff('x = f(y)','x = y^(1/3)'))
 ans  =

   0.0322962
   
c)
--> reglaDelTrapecio(0,%pi/3,deff('x = f(y)','x = sin(y)^2'))
 ans  =

   0.3926991
   
--> reglaDeSimpson(0,%pi/3,deff('x = f(y)','x = sin(y)^2'))
 ans  =

   0.3054326  

ii)

a) Valor real: 0.38629 Valor aproximado con regla del trapecio: 0.3465736 Valor aproximado con regla de Simpson: 0.3858346
b) Valor real: 0.03481 Valor aproximado con regla del trapecio: 0.0232079 Valor aproximado con regla de Simpson: 0.0322962
c) Valor real: 0.30709 Valor aproximado con regla del trapecio: 0.3926991 Valor aproximado con regla de Simpson: 0.3054326

Podemos ver que en general el método de Simpson aproxima mejor que el del trapecio. En el apartado
a) y sobretodo en el c) se puede observar una diferencia considerable entre los valores aproximados y el valor real.

iii)

a)
Veamos de acotar el error.
Error en la regla del trapecio:

Tenemos que |E| = |- h^3/12 * f''(c)|
Donde f''(x) = -1/x^2 y h = 2 - 1 = 1

Reescribiendo tenemos entonces
|E| = |- 1/12 * - 1/c^2|

Dado que el intervalo en análisis es el [1,2] y |f''(x)| es decreciente en este intervalo, podemos acotar el segundo restando por |f''(1)| = 1

|E| = |- 1/12 * - 1/x^2| <= |- 1/12 * 1| = 1/12
Por lo tanto el error está acotado por 1/12.

Error en la regla de Simpson:

Tenemos que |E| = |-h^5/90 * f^4(c)|
Donde f^4(x)= -6/x^4 y h = (2-1)/2 = 1/2

Reescribiendo tenemos entonces
|E| = |- (1/2)^5/90 * -6/c^4| = |- 1/2880 * -6/c^4|

Dado que el intervalo en análisis es el [1,2] y |f^4(x)| es decreciente en este intervalo, podemos acotar el segundo restando por f''(1) = 6

|E| = |- 1/2880 * -6/c^4| <= |- 1/2880 * 6| = 1/480
Por lo tanto el error está acotado por 1/480.

b)

Error método del trapecio:

Tenemos que |E| = |- h^3/12 * f''(c)|
Donde f''(x) = -2/9x^(5/3) y h = 0.1 - 0 = 0.1

Reescribiendo tenemos entonces
|E| = |- 1/12000 * - 2/9c^(5/3)|

Dado que el intervalo en análisis es el [0,0.1] y f''(x) es decreciente en este intervalo, podríamos intentar acotar el segundo restando por f''(0), pero esto no es posible ya que el límite de la función tiende a infinito en este punto. Por lo tanto, no es posible acotar este error.

Error en la regla de Simpson:

Tenemos que |E| = |-h^5/90 * f^4(c)|
Donde f^4(x)= -80/81x^(11/3) y h = (0.1-0)/2 = 1/20

Reescribiendo tenemos entonces
|E| = |- (1/20)^5/90 * -80/81c^(11/3)| = |- 3.4722x10-9 * -80/81c^(11/3)|

Dado que el intervalo en análisis es el [0,0.1] y f^4(x) es decreciente en este intervalo, podríamos intentar acotar el segundo restando por f''(0), pero esto no es posible ya que el límite de la función tiende a infinito en este punto. Por lo tanto, no es posible acotar este error.

c)
Error en la regla del trapecio:

Tenemos que E = -h^3 / 12 * f''(c)
donde f''(x) = cos(2x) * 2 y h = %pi/3 - 0 = %pi/3

Vemos que f''(x) es una funcion concava en el intervalo [0, %pi/3] por lo tanto para acotarlo buscamos los x en f''' tal que f'''(x) = 0

Luego tenemos que el segundo restando esta acotado por f''(0) = 2

|E| <= |- (%pi/3)^3/12 * 2| = 0.1913968


Error en la regla de Simpson:

Tenemos que |E| = |-h^5/90 * f^4(c)|
Donde f^4(x) = -8cos(2x) y h = (%pi/3 - 0)/2 = %pi/6

Vemos que f^4(x) está formada por un coseno,es decir, una función periodica que toma valores entre -1 y 1. Además,cos(0)= y 1 pertenece [0;pi/3], por lo tanto podemos acotar el segundo restando por f^4(0) = 8

|E| = |-4.37271x10-4 * -8cos(2c)| <= |-4.37271x10-4 * -8| = 3.49817x10-3


//Ejercicio 2

i)

a)

--> reglaTrapecioCompuesta(1, 3, 4, deff('y = f(x)', 'y = 1/x'))
 ans  =

   1.1166667
  
b)
--> reglaTrapecioCompuesta(0, 2, 4, deff('y = f(x)', 'y = x^3'))
 ans  =

   4.25

c)
--> reglaTrapecioCompuesta(0, 3, 6, deff('y = f(x)', 'y = x*((1+x^2)^(1/2))'))
 ans  =

   10.312201
   
d)
--> reglaTrapecioCompuesta(0, 1, 8, deff('y = f(x)', 'y = sin(%pi*x)'))
 ans  =

   0.6284174
e)
--> reglaTrapecioCompuesta(0, 2*%pi, 8, deff('y = f(x)', 'y = x * sin(x)'))
 ans  =

  -5.9568332

f)
--> reglaTrapecioCompuesta(0, 1, 8, deff('y = f(x)', 'y = x^2*exp(x)'))
 ans  =

   0.7288902
   
ii)

a) 

--> integrate('1/x','x',1,3)
 ans  =

   1.0986123

b)

--> integrate('x^3','x',0,2)
 ans  =

   4.
c)
--> integrate('x*((1+x^2)^(1/2))','x',0,3)
 ans  =

   10.207592
d)
--> integrate('sin(%pi*x)','x',0,1)
 ans  =

   0.6366198
   
e)
--> integrate('x*sin(x)','x',0,2*%pi)
 ans  =

  -6.2831853
  
f) 
--> integrate('x^2*exp(x)','x',0,1)
 ans  =

   0.7182818
   
//Ejercicio 3

i)

a)
--> reglaDeSimpsonCompuesta(1, 3, 4, deff('y = f(x)', 'y = 1/x'))
 ans  =

   1.1
b)
--> reglaDeSimpsonCompuesta(0, 2, 4, deff('y = f(x)', 'y = x^3'))
 ans  =

   4.

c)

--> reglaDeSimpsonCompuesta(0, 3, 6, deff('y = f(x)', 'y = x*((1+x^2)^(1/2))'))
 ans  =

   10.206346
   
d)
--> reglaDeSimpsonCompuesta(0, 1, 8, deff('y = f(x)', 'y = sin(%pi*x)'))
 ans  =

   0.6367055
   
e)
--> reglaDeSimpsonCompuesta(0, 2*%pi, 8, deff('y = f(x)', 'y = x*sin(x)'))
 ans  =

  -6.2975102

f)
--> reglaDeSimpsonCompuesta(0, 1, 8, deff('y = f(x)', 'y = x^2*exp(x)'))
 ans  =

   0.7183215
   
*/

//Ejercicio 4
/*

a)

--> reglaTrapecioCompuesta(0, 1.5, 10, deff('y = f(x)', 'y = (x+1)^(-1)'))
 ans  =

   0.9178617
   
b)
--> reglaDeSimpsonCompuesta(0, 1.5, 10, deff('y = f(x)', 'y = (x+1)^(-1)'))
 ans  =

   0.9163064

c)
Error con el método de trapecio compuesto: 0.9262907 - 0.9178617 = 0.008429

Error con el método de Simpson compuesto: 0.9262907 - 0.9163064 = 0.0099843

Podemos ver que para esta funcion y este intervalo, el método de los trapecios compuesto tiene mejor aproximación.
*/

//Ejercicio 5

function area = GTrapecio(y,c,d,f)
    h = d - c  
    area = h/2 * (f(c,y) + f(d,y))
endfunction

function area = reglaDelTrapecioExtendida(a,b,c,d,f)
    h = b - a  
    area = h/2 * (GTrapecio(a,c,d,f) + GTrapecio(b,c,d,f))
endfunction

//Otra version
function area = TrapecioExt(a,b,c,d,f)
    h = (b-a)*(d-c)/4
    area = h * (f(c,a)+f(c,b)+f(d,a)+f(d,b))
endfunction

/*
--> reglaDelTrapecioExtendida(0,1,0,2, deff('z = f(x,y)', 'z = sin(x+y)'))
 ans  =

   0.9459442


Ejercicio 6

*/
function z = uno(x,y)
    z = 1
endfunction

function y = c1x(x)
    y = -sqrt(2*x-x^2)
endfunction

function y = d1x(x)
    y = sqrt(2*x-x^2)
endfunction

function v = DobleTn(f,a,b,c,d,n,m)
    h = (b-a)/n
    deff("z=fxa(y)","z=f(a,y)") //auxiliares
    deff("z=fxb(y)","z=f(b,y)")
    v = (reglaTrapecioCompuesta(c(a),d(a),m,fxa)/2) + (reglaTrapecioCompuesta(c(b),d(b),m,fxb)/2)   //a y b
    for j = 1:n-1
        xi = a + j * h;
        deff("z=fxi(y)","z=f(xi,y)")    //recorro los x
        v = v + (reglaTrapecioCompuesta(c(xi),d(xi),m,fxi))
    end
    v = h * v
endfunction

/*

--> DobleTn(uno,0,2,c1x,d1x,2000,2000)
 ans  =

   3.1415555

*/

function v = DobleSn(f,a,b,c,d,n,m)
    h = (b - a)/n
    deff("z=fxa(y)","z=f(a,y)")
    deff("z=fxb(y)","z=f(b,y)")
    v = (reglaDeSimpsonCompuesta(c(a),d(a),m,fxa)) + (reglaDeSimpsonCompuesta(c(b),d(b),m,fxb)) //a y b
    for i = 1:(n-1)
        a = a + h
        deff("z=fxi(y)","z=f(a,y)")
        if modulo(i, 2) == 0 then
            v = v + 2*(reglaDeSimpsonCompuesta(c(a),d(a),m,fxi))
        else
            v = v + 4*(reglaDeSimpsonCompuesta(c(a),d(a),m,fxi))
        end
    end
    v = v * (h/3)
    
endfunction

/*
--> DobleSn(uno,0,2,c1x,d1x,2000,2000)
 ans  =

   3.1415781
   
Aproxima mejor, pero tarda considerablemente más tiempo.
*/
