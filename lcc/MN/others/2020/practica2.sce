//-------------------------------------------------------------
//1)
/*
Crear una función en Scilab que calcule en forma robusta las raíces de una ecuación cuadrática con discriminante positivo. Usar dicha función para evaluar la raíz positiva de la ecuación cuadrática (10) con ǫ = 0,0001 y estimar su error.
*/

function y = raicesRobustas(polinomio)
    //Tenemos discriminante positivo
    
    //Tomamos los coeficientes
    a = coeff(polinomio, 2)
    b = coeff(polinomio, 1)
    c = coeff(polinomio, 0)
    
    if a == 0 then
        y = error("a es cero ")
        return y
    end
    
    //Implementamos el algoritmo para calculo robusto
    
    if b < 0 then
        y(1) = (2*c)/(-b + (b^2 - 4*a*c)^(1/2))
        y(2) = (-b + (b^2 - 4*a*c)^(1/2))/(2*a)
    end
   
    if b > 0 then
        y(1) = (-b - ((b^2) - (4*a*c))^(1/2))/(2*a)
        
        y(2) = (2*c)/(-b - (b^2 - 4*a*c)^(1/2))
    end
endfunction


//Ejemplo pedido

e = 0.0001;

p1 = poly([-e, (1/e), e], "x","coeff");

respuestaEj1 = raicesRobustas(p1);

//Rta:

//Error cometido:
//Calculamos el error relativo: 
//|valorReal - valorObtenido|/|valorReal| = 
//raíz1 = |-100000000-(-100000000)|/|-100000000| = 0
//raíz2 = |1*10^(-8) - 1*10^(-8)|/1*10^(-8) = 0


//Ejercicio 3

//b)

function resultadoHorner = ejercicio3b(polinomio, x)
    //Variable para elresultado
    resultadoHorner = 0

    //Itero sobre el polinomio aplicando para cada coeficiente el algoritmo de Horner
    for i = flipdim(coeff(polinomio), 2) //utilizamos la función flipdim para poder recorrer los coeficientes de mayor a menor grado.
        resultadoHorner = resultadoHorner * x
        resultadoHorner = resultadoHorner + i
    end
endfunction


//Ejemplos

p2 = poly([2 6 3 7 4], "x", "coeff");

respuestaEj3b = ejercicio3b(p2, 8)


//d)
function resultadoHorner = ejercicio3d(p, x)
    //Variable para elresultado
    resultadoHorner(1) = 0
    resultadoHorner(2) = 0
    //Itero sobre el polinomio aplicando para cada coeficiente el algoritmo de Horner
    l = flipdim(coeff(p), 2) //utilizamos la función flipdim para poder recorrer los coeficientes de mayor a menor grado.
    tam = length(l) //tam representa el grado de p + 1
    
    for i = l
        resultadoHorner(1) = resultadoHorner(1) * x
        resultadoHorner(1) = resultadoHorner(1) + i
        
        if tam > 1 //no permitimos que se sume el valor b_0, (la evaluación de x_0 en p)
            resultadoHorner(2) = resultadoHorner(2) + resultadoHorner(1) * x^(tam-2) // implementamos lo visto en el apartado c)
            tam = tam - 1
        end
    end
endfunction

//Ejemplos

p3 = poly([2 6 3 7 4], "x", "coeff");

respuestaEj3d = ejercicio3d(p3, 8)

//Ejercicio 4

//Forma recursiva
function derivada = derivar1(f, v, n, h)
    if n == 0 then //Si el orden de la derivada es 0 entonces devuelvo el valor en la función
        derivada = f(v) 
    else
        derivada = (derivar1(f,v+h,n-1,h) - derivar1(f,v,n-1,h)) / h //aplicamos la fórmula de cociente incremental de f^n
    end
endfunction


//Forma iterativa
function valor=derivada(f,v,n,h)
    //construimos cada derivada hasta llegar a n y guardamos el valor en la última derivada
    deff("y=DF0(x)","y="+f);
    if n == 0 then valor = DF0(v);
    else 
        for i=1:(n-1)
            deff("y=DF"+string(i)+"(x)","y=(DF"+string(i-1)+"(x+"+string(h)+")-DF"+string(i-1)+"(x))/"+string(h));
        end
        deff("y=DFn(x)","y=(DF"+string(n-1)+"(x+"+string(h)+")-DF"+string(n-1)+"(x))/"+string(h));
        valor = DFn(v);
    end
endfunction

//Forma con numderivative
function valorD = derivadaNum(f,v,n,h)
        //construimos cada derivada hasta llegar a n utilizando la función numderivative() y guardamos el valor en la última derivada
    deff("y=DF0(x)","y="+f);
    if n == 0 then valorD = DF0(v);
    else 
        for i=1:n
            deff("y=DF"+string(i)+"(x)","y=numderivative(DF"+string(i-1)+",x,"+string(h)+",4)");
        end
        deff("y=DFn(x)","y=numderivative(DF"+string(i-1)+",x,"+string(h)+",4)");
        valorD = DFn(v);
    end
endfunction

/*
//a) ¿Cómo son los errores cometidos en cada caso?
    El error cometido en la versión que usa numderivativa es mucho menor que el del cociente incremental.
    
//b)¿Qué hace que el error en la implementación por cociente incremental crezca?
    Esto se debe a que tenemos una división sobre un h muy chico, esto es, una división con denominador igual a h^n.
*/
   
//Ejemplos

function y = foo(x)
    y = x^4
endfunction

respuesta1Ej4 = derivar1(foo, 2, 1, 0.001);

respuesta2Ej4 = derivadaNum("x^4", 2, 1, 0.001)


//Ejercicio 5

function y = taylor(f, v, n, a) //Agregamos el parámetro a para que podamos calcular taylor en un entorno de otro punto además de cero
    y = 0
    i = 0
    while i <= n //Implementamos taylor dado la definición, usando la función derivadaNum ya que presenta un error relativo más chico.
        y = y + (((derivadaNum(f, a, i, 0.001)) * (v-a)^i)/ factorial(i))
        i = i + 1
    end
endfunction


//Ejemplos

respuesta1Ej5 = taylor("sin(x)", 1, 4, 0)

respuesta2Ej5 = taylor("x^4", 2, 3,  0)

//Ejercicio 6


/*
orden = [0:10]
coeficientes = factorial(orden)
coeficientes = 1./coeficientes
taylor = poly(coeficientes,"x","coeff")
horner(taylor,-2)
horner(taylor,2)
1/ans
abs(0.1353353 - 0.1353792) / 0.1353353
abs(0.1353353 - 0.1353364) / 0.1353353
*/
