/*
1)
Metodos de de iteraciones
*/

function y = metodoJacobi(x, A, b, eps)
    n = size(x, "r")
    
    errorActual = x 
    for i=1:n
        suma = 0
        for j=1:n
            if j <> i then
                suma = suma + A(i,j)*x(j)
            end
        end
        x(i) = (1/ A(i,i)) * (b(i) - suma)
    end

    while eps < norm(errorActual - x)
        errorActual = x
        for i=1:n
            suma = 0
            for j=1:n
                if j <> i then
                    suma = suma + A(i,j)*x(j)
                end
            end
            x(i) = (1/ A(i,i)) * (b(i) - suma)
        end
    end
    
    y = x
endfunction



function y = metodoGauss_Seidel(x, A, b, eps)
    n = size(x,"r")
    
    xAnt = x
    for i=1:n
        suma = 0
        //suma que usa el x actual
        for j=1:(i-1)
            suma = suma + A(i,j)*x(j)
        end
        //suma que usa el x de la it. anterior
        for j=(i+1):n
            suma = suma + A(i,j)*xAnt(j)
        end
        x(i) = (1/A(i,i)) * (b(i) - suma)
    end
    
    while eps < norm(xAnt - x)
        xAnt = x
        for i=1:n
            suma = 0
            //suma que usa el x actual
            for j=1:(i-1)
                suma = suma + A(i,j)*x(j)
            end
            //suma que usa el x de la it. anterior
            for j=(i+1):n
                suma = suma + A(i,j)*xAnt(j)
            end
            x(i) = (1/A(i,i)) * (b(i) - suma)
        end
    end
    
    y = x
endfunction



function [y, c] = metodoIteraciones(A, N, b, x, eps)
    
    [nA, mA] = size(A)

    if max(abs(spec(eye(nA,nA) - inv(N)*A))) >= 1 then
        disp("No converge") //corolario 1
        c = 0
    else
        counter = 1 //para contar el numero de iteraciones (ejercicio 2)
        c = 1
        invn = inv(N)
        restna = N - A
        I = eye(nA,nA)
        erroractual=x
        x = invn * (restna * x + b)
        while eps < norm(erroractual - x)
            erroractual = x
            x = invn * (restna * x + b)
            counter = counter + 1
        end
    end
    disp(counter)
    y = x
    
endfunction


function y = metodojacobiMatricial(A, b, x, eps)
    [nA, mA] = size(A)
    
    if mA<>nA then
        disp("No es cuadrada")
        y = []
    else
        N = eye(nA, nA)
        
        for i = 1:nA
            N(i,i) = A(i,i)
        end
        y = metodoIteraciones(A, N, b, x, eps)
    end
    
endfunction

function y = metodogaussseidelMatricial(A, b, x, eps)
    [nA, mA] = size(A)
    
    if mA<>nA then
        disp("No es cuadrada")
        y = []
    else
        N = tril(A)
        [y,c] = metodoIteraciones(A, N, b, x, eps)
    end
endfunction

A1 = [0 2 4;1 -1 -1;1 -1 2]
b1 = [0 0.375 0]'

A2 = [1 -1 0;-1 2 -1;0 -1 1.1]
b2 = [0 1 0]'

/*
Evaluamos el sistema que converge.


metodojcobi(A, [0 1 0]', [0 0 0]', 0.01)
 ans  =

   10.789086
   10.798673
   9.8082602

metodogaussseidel(A, [0 1 0]', [0 0 0]', 0.01)
 ans  =

   10.873565
   10.879312
   9.8902836
   
Vamos a resolver ahora el sistema que no converge

metodojcobi(A, [0 0.375 0]', [0 0 0]', 0.01)

 No converge
 ans  =

   0.
   0.
   0.
   
   
   
metodogaussseidel(A, [0 0.375 0]', [0 0 0]', 0.01)

 No converge
 ans  =

   0.
   0.
   0.
   
   
*/


/*
2)
Ejecutamos:

A = [10 1 2 3 4; 1 9 -1 2 -3;2 -1 7 3 -5;3 2 3 12 -1; 4 -3 -5 -1 15]
 A  = 

   10.   1.   2.   3.    4. 
   1.    9.  -1.   2.   -3. 
   2.   -1.   7.   3.   -5. 
   3.    2.   3.   12.  -1. 
   4.   -3.  -5.  -1.    15.
   
   x = zeros(5, 1)
 x  = 

   0.
   0.
   0.
   0.
   0.
   
   b = [12 -27 14 -17 12]'
 b  = 

   12.
  -27.
   14.
  -17.
   12.
   
   metodogaussseidel(A,b,x,0.000001)

   38.
   
   metodojacobi(A,b,x,0.000001)

   67
*/


/*
4)
*/

function [y,b, x] = crearA(N)
    y = 8*eye(N,N) + 2*diag(ones(N-1,1),1) + 2*diag(ones(N-1,1),-1)+ diag(ones(N-3,1),3) + diag(ones(N-3,1),-3)
    b = ones(N,1)
    x = zeros(N, 1)
endfunction


function y = tempGS(A,b,x,eps)
    tic();
    metodogaussseidel(A,b,x,eps)
    y = toc();
endfunction

function y = tempGEPP(A,b)
    tic();
    gausselimPP(A,b)
    y = toc();
endfunction

/*
Ejecutamos
[A,b,x] = crearA(100)

tempGS(A, b, x, 0.000000000001)
 ans  =

   0.01611

tempGEPP(A, b)
 ans  =

   1.041839


[A,b,x] = crearA(500)
tempGS(A, b, x, 0.000001)
 ans  =

   0.256821

tempGEPP(A, b)
 ans  =

   110.63873

*/

/*
5)


*/

function y = ejercicio5(A, b, x, eps)
    /*calculamos el w optimo que pide el ejercicio*/
    [nA, mA] = size(A)
    
    N = eye(nA, nA)
        
    for i = 1:nA
        N(i,i) = A(i,i)
    end
    
    ro = max(abs(spec(eye(nA,nA) - inv(N)*A)))
    
    w = 2/(1 + sqrt(1-(ro^2)))
    
    if(w <= 1)
        disp("El w es mayor a uno no se llama SOR el algoritmo")
    end
    
    y = metodoGSSOR(A, b, x, eps, w)
endfunction

function y = metodoGSSOR(A, b, x, eps, w)
    [nA, mA] = size(A)
    erroractual=x
    counter = 1
    x(1) = (1-w)*x(1) + w/A(1,1) * (b(1) - A(1,2:nA) * x(2:nA))       
    
    for i=2:nA-1         
      x(i) = (1-w)*x(i) + w/A(i,i) * (b(i) - A(i,1:i-1) * x(1:i-1) - A(i,i+1:nA) * x(i+1:nA))       
    end
    
    x(nA) = (1-w)*x(nA) + w/A(nA,nA) * (b(nA) - A(nA,1:nA-1) * x(1:nA-1)) 
        
    while eps < norm(erroractual - x)
        counter = counter + 1
        erroractual = x
        
        x(1) = (1-w)*x(1) + w/A(1,1) * (b(1) - A(1,2:nA) * x(2:nA))
        
        for i=2:nA-1
            
            x(i) = (1-w)*x(i) + w/A(i,i) * (b(i) - A(i,1:i-1) * x(1:i-1) - A(i,i+1:nA) * x(i+1:nA))       
        end
        
        x(nA) = (1-w)*x(nA) + w/A(nA,nA) * (b(nA) - A(nA,1:nA-1) * x(1:nA-1)) 
        
    end
    disp(counter)
    y = x
endfunction

/*
Evaluando tenemos:

a)

metodogaussseidel(A, b, x, 0.0000001)

   36.
 ans  =

   3.0000001
   3.9999999
  -5.

ejercicio5(A, b, x, 0.0000001)

   16.
 ans  =

   3.
   4.
  -5.
*/

