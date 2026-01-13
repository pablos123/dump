/*
Ejercicio 1
*/

function y = sistemaSuperior(m)
    i = size(m, "r")
    respuesta = m(:, i + 1) //hack
    while i > 0
        j = size(m, "r")
        while j >= i
            if (j > i)
                respuesta(i) = respuesta(i) - m(i,j) * respuesta(j)
            else
                respuesta(i) = respuesta(i)/ m(i,i)
            end
            j = j - 1
        end
        i = i -1
    end
    y = respuesta
endfunction

function y = sistemaInferior(m)
    i = 1
    respuesta = m(:, size(m, "c")) //hack
    while i < size(m, "r") + 1
        j = 1
        while j <= i
            if (j < i)
                respuesta(i) = respuesta(i) - m(i,j) * respuesta(j)
            else
                respuesta(i) = respuesta(i)/ m(i,i)
            end
            j = j + 1
        end
        i = i + 1
    end
    y = respuesta
endfunction

/*
Ejercicio 2
b)
Los resultados nos quedan:

A = [1 1 0 3; 2 1 -1 1; 3 -1 -1 2; -1 2 3 -1]
b = [4 1 -3 4]'

gausselim(A, b):

  -1.
   2.
   0.
   1.

   1.   1.   0.   3.    4. 
   0.  -1.  -1.  -5.   -7. 
   0.   0.   3.   13.   13.
   0.   0.   0.  -13.  -13.


A2 = [1 -1 2 -1; 2 -2 3 -3; 1 1 1 0; 1 -1 4 3]
b2 = [-8 -20 -2 4]'

gausselim(A2,b2):

   Nan
   Nan
   Nan
   Nan

   1.  -1.   2.   -1.   -8. 
   0.   0.  -1.   -1.   -4. 
   0.   0.   Inf   Inf   Inf
   0.   0.   0.    Nan   Nan

No devuelve este resultado ya que uno de los pivotes se hace cero para alguna de las iteraciones.


A3 = [1 1 0 4; 2 1 -1 1; 4 -1 -2 2; 3 -1 -1 2]
b3 = [2 1 0 -3]'

gausselim(A3, b3):

  -4.
   0.6666667
  -7.
   1.3333333

   1.   1.   0.   4.    2.
   0.  -1.  -1.  -7.   -3.
   0.   0.   3.   21.   7.
   0.   0.   0.  -3.   -4.
   
c)
*/


function [x,a] = gausselimWithCounter(A,b)
    // Esta función obtiene la solución del sistema de ecuaciones lineales A*x=b, 
    // dada la matriz de coeficientes A y el vector b.
    // La función implementa el método de Eliminación Gaussiana sin pivoteo.  
    dm = 0
    sr = 0
    [nA,mA] = size(A) 
    [nb,mb] = size(b)
    
    if nA<>mA then
        error('gausselim - La matriz A debe ser cuadrada');
        abort;
    elseif mA<>nb then
        error('gausselim - dimensiones incompatibles entre A y b');
        abort;
    end;
    
    a = [A b]; // Matriz aumentada
    
    // Eliminación progresiva
    n = nA;
    for k=1:n-1
        for i=k+1:n
            for j=k+1:n+1
                a(i,j) = a(i,j) - a(k,j)*a(i,k)/a(k,k);
                sr = sr + 1
                dm = dm + 2
            end;
            for j=1:k        // no hace falta para calcular la solución x
                a(i,j) = 0;  // no hace falta para calcular la solución x
            end              // no hace falta para calcular la solución x
        end;
    end;
    
    // Sustitución regresiva
    x(n) = a(n,n+1)/a(n,n);
    dm = dm + 1
    for i = n-1:-1:1
        sumk = 0
        for k=i+1:n
            sumk = sumk + a(i,k)*x(k);
            sr = sr + 1
            dm = dm + 1
        end;
        x(i) = (a(i,n+1)-sumk)/a(i,i);
        sr = sr + 1
    end;
    disp(sr, dm)
endfunction

//3) a)

function [x, a] = gausselimMultiplesb(A, B)
    // Esta función obtiene la solución del sistema de ecuaciones lineales A*x=b, 
    // dada la matriz de coeficientes A y el vector b.
    // La función implementa el método de Eliminación Gaussiana sin pivoteo.
    x = []
    [nA,mA] = size(A) 
    [nb,mb] = size(B)
    
    if nA<>mA then
        error('gausselim - La matriz A debe ser cuadrada');
        abort;
    elseif mA<>nb then
        error('gausselim - dimensiones incompatibles entre A y b');
        abort;
    end;
    
    a = [A B]; // Matriz aumentada
    
    // Eliminación progresiva
    n = nA;
    for k=1:n-1
        for i=k+1:n
            for j=k+1:n+mb
                a(i,j) = a(i,j) - a(k,j)*a(i,k)/a(k,k);
            end;
            for j=1:k        // no hace falta para calcular la solución x
                a(i,j) = 0;  // no hace falta para calcular la solución x
            end              // no hace falta para calcular la solución x
        end;
    end;
   
    adeverdad = a(1:nA, 1:mA)
    bdeverdad = a(1:nA, (mA+1):(mA+mb))
   
    for i = 1:mb
        parametro = [adeverdad, bdeverdad(:, i)]
        x(:,i) = sistemaSuperior(parametro)
    end
endfunction


/*
b)

Nos queda:

--> gausselimMultiplesb(A, B)
 ans  =

   1.   2.   2.   1.   2.   3.   14.   9.   -2. 
   2.   5.   1.   0.  -8.  -8.  -40.  -32.   8. 
   3.  -1.  -2.   0.   0.  -7.  -21.   7.    14.

*/

/*
c)

Lo resolvemos pasando la matriz identidad nxn planteando de este modo n sistemas de ecuaciones donde cada uno corresponde a una columna de la identidad.

--> gausselimMultiplesb(A, B)
 ans  =

   0.      0.1428571   0.1428571   1.   2.   3.   1.     0.     0.
   0.125  -0.2321429   0.1428571   0.  -8.  -8.  -3.     1.     0.
   0.25    0.1071429  -0.1428571   0.   0.  -7.  -1.75  -0.75   1.
   
   
Aca vemos por lo tanto que la inversa de la matriz A es:

   0.      0.1428571   0.1428571
   0.125  -0.2321429   0.1428571
   0.25    0.1071429  -0.1428571
*/



function y = gausselimDeterminante(A)
    // Esta función obtiene la solución del sistema de ecuaciones lineales A*x=b, 
    // dada la matriz de coeficientes A y el vector b.
    // La función implementa el método de Eliminación Gaussiana sin pivoteo.
    y = 1
    [nA,mA] = size(A)
    
    if nA<>mA then
        error('gausselim - La matriz A debe ser cuadrada');
        abort;
    end;
    
    a = A
    // Eliminación progresiva
    n = nA;
    for k=1:n-1 //es -1 ya que la ultima fila no es necesario calcularla
        for i=k+1:n 
            for j=k+1:n
                a(i,j) = a(i,j) - a(k,j)*a(i,k)/a(k,k)
            end;

            if i == k+1 //importante para que se ejecute una sola vez por fila
               y = y * a(i, i) //importante (i,i) (tambien podriamos poner (i, k+1)) porque nos aseguramos de que esa fila ya esta hecha (por el for de arriba)
            end
            for j=1:k        // no hace falta para calcular la solución x
                a(i,j) = 0;  // no hace falta para calcular la solución x
            end              // no hace falta para calcular la solución x
        end;
    end;
    
    y = y * a(1,1) //multiplicamos por el primer elemento ya que no estaba contemplado en el for.
endfunction


/*

Ejemplos de aplicacion:

A = [1 2 3; 3 -2 1; 4 2 -1]
 A  = 

   1.   2.   3.
   3.  -2.   1.
   4.   2.  -1

gausselimDeterminante(A)

   1.   2.   3.
   0.  -8.  -8.
   0.   0.  -7.
 ans  =

   56.
   
A = [5 2 1; 3 -2 1; 4 2 -1]
 A  = 

   5.   2.   1.
   3.  -2.   1.
   4.   2.  -1.

   
gausselimDeterminante(A)

   5.   2.    1.  
   0.  -3.2   0.4 
   0.   0.   -1.75
 ans  =

   28.

*/


/*
5)
b)

A2 = [1 -1 2 -1; 2 -2 3 -3; 1 1 1 0; 1 -1 4 3]
b2 = [-8 -20 -2 4]'

gausselimPP(A2, b2)
 ans  =

  -7.
   3.
   2.
   2.
*/

/*
6)
*/


function y = gausselimTridiagonal(A, b)
    [nA,mA] = size(A) 
    [nb,mb] = size(b)
    
    if nA<>mA then
        error('gausselim - La matriz A debe ser cuadrada');
        abort;
    elseif mA<>nb then
        error('gausselim - dimensiones incompatibles entre A y b');
        abort;
    end;
    a = [A, b]; // Matriz aumentada
    n = nA;

    for k = 1:n-1
        i = k + 1
        a(i, n+1) =  a(i, n+1) - a(k, n+1) * a(i,k)/a(k,k)
        a(i,i) = a(i,i) - a(k,i) * a(i,k)/a(k,k) //con esto logramos eliminar la diagonal de a's logrando                                                  //una matriz triangular superior       
        for j=1:k        // no hace falta para calcular la solución x
            a(i,j) = 0;  // no hace falta para calcular la solución x
        end
    
    end

    k = n
    while k >= 2
        i = k - 1
        j = k 
        a(i, n+1) =  a(i, n+1) - a(k, n+1) * a(i,k)/a(k,k)
        while j >= k-1
            if i <> j
                a(i,j) = 0        
            end
            j = j - 1
        end
        k = k - 1
    end
    
    for i = 1:n
        y(i) = a(i,n+1)/a(i,i)
    end
endfunction


/*
7)

Queremos obtener la factorización PA = LU de mi matriz A con P matriz de permutación.

*/


function [U, L, P] = elimGaussPLU(A)
    i = size(A, "r")
    for k=1:i
        I(k,k) = 1
    end
    
    U = A
    L = I
    P = I
    
    maxiter = size(A, "c")-1
    for k = 1:maxiter
        kpivot = k; amax = abs(U(k,k));  //pivoteo
        for i=k+1:maxiter+1
            if abs(U(i,k))>amax then
                kpivot = i; amax = U(i,k);
            end;
        end;
        
        temp = U(kpivot,k:maxiter+1);
        U(kpivot,k:maxiter+1) = U(k,k:maxiter+1);
        U(k,k:maxiter+1) = temp;
        
        temp = L(kpivot,1:k-1);
        L(kpivot,1:k-1) = L(k,1:k-1);
        L(k,1:k-1) = temp;     
        
        temp = P(kpivot,:);
        P(kpivot,:) = P(k,:);
        P(k,:) = temp;
        
        
        
        for j = k+1:maxiter+1
            L(j,k) = U(j,k)/U(k,k)
            
            U(j, k:maxiter+1) = U(j, k:maxiter+1) - L(j,k) * U(k, k:maxiter+1)          
        end
    end
endfunction

/*
Ejecutanto el codigo con la matriz del ejercicio
--> elimGaussPLU(A)

   0.   0.   1.   0.
   0.   0.   0.   1.
   0.   1.   0.   0.
   1.   0.   0.   0.

   1.     0.          0.          0.
   0.75   1.          0.          0.
   0.5   -0.2857143   1.          0.
   0.25  -0.4285714   0.3333333   1.

   8.   7.     9.          5.       
   0.   1.75   2.25        4.25     
   0.   0.    -0.8571429  -0.2857143
   0.   0.     0.          0.6666667
*/

/*
8)
 A = [1.012 -2.132 3.104; -2.132 4.096 -7013; 3.104 -7013 0.014]
 A  = 

   1.012  -2.132   3.104
  -2.132   4.096  -7013.
   3.104  -7013.   0.014


--> elimGaussPLU(A)

   0.   0.   1.
   0.   1.   0.
   1.   0.   0.

   1.          0.          0.
  -0.6868557   1.          0.
   0.3260309  -0.4746327   1.

   3.104  -7013.       0.014    
   0.     -4812.8228  -7012.9904
   0.      0.         -3325.4948

Comparando...

--> [l, u, p] = lu(A)
 p  = 

   0.   0.   1.
   0.   1.   0.
   1.   0.   0.

 u  = 

   3.104  -7013.       0.014    
   0.     -4812.8228  -7012.9904
   0.      0.         -3325.4948

 l  = 

   1.          0.          0.
  -0.6868557   1.          0.
   0.3260309  -0.4746327   1.
   

 B = [2.1756 4.0231 -2.1732 5.1967;-4.0231 6.0000 0 1.1973;-1.0000 5.2107 1.111 0;6.0235 7.0000 0 4.1561]
 B  = 

   2.1756   4.0231  -2.1732   5.1967
  -4.0231   6.       0.       1.1973
  -1.       5.2107   1.111    0.    
   6.0235   7.       0.       4.1561


--> elimGaussPLU(B)

   0.   0.   0.   1.
   0.   1.   0.   0.
   1.   0.   0.   0.
   0.   0.   1.   0.

   1.          0.          0.          0.
  -0.6679007   1.          0.          0.
   0.3611854   0.1400243   1.          0.
  -0.1660164   0.596968   -0.5112277   1.

   6.0235   7.          0.       4.1561   
   0.       10.675305   0.       3.9731622
   0.       0.         -2.1732   3.1392381
   0.       0.          0.      -0.0770042
   
Comparando...

 [l, u, p] = lu(B)
 p  = 

   0.   0.   0.   1.
   0.   1.   0.   0.
   1.   0.   0.   0.
   0.   0.   1.   0.

 u  = 

   6.0235   7.          0.       4.1561   
   0.       10.675305   0.       3.9731622
   0.       0.         -2.1732   3.1392381
   0.       0.          0.      -0.0770042

 l  = 

   1.          0.          0.          0.
  -0.6679007   1.          0.          0.
   0.3611854   0.1400243   1.          0.
  -0.1660164   0.596968   -0.5112277   1.


*/



// 9)

function x = Ejercicio9(A,b)
    [U, L, P] = elimGaussPLU(A)
    
    y = sistemaInferior([L P*b])
    x = sistemaSuperior([U y])
endfunction

AEj9 = [1 2 -2 1;4 5 -7 6;5 25 -15 -3;6 -12 -6 22]
b = [1 2 0 1]'
bSombrero = [2 2 1 0]'
/*
a)

--> Ejercicio9(AEj9,b)
 ans  =

   9.8333333
  -6.1666667
  -5.5
  -7.5
  
b)

--> Ejercicio9(AEj9,bSombrero)
 ans  =

   19.5
  -17.
  -18.
  -19.5



10)
*/

function [L,U] = doolittle(A)
    n = size(A, "r")
    L = eye(n,n)
    U = eye(n,n)
    
    U(1, :) = A(1, :)
    

    for i = 2:n
        L(i, 1) = A(i,1)/U(1,1)
    end

    for i=2:n
        for j = 2:n
            if i > j
                L(i, j) = (A(i, j) - L(i, 1:j-1)*U(1:j-1, j))/U(j, j)
            else
                U(i, j) = A(i, j) - (L(i, 1:i-1)*U(1:i-1, j))
            end
        end
    end
endfunction


function res = ejercicio10(A, b)
    [L, U] = doolittle(A)
    
    g = sistemaInferior([L b])
    res = sistemaSuperior([U g])
endfunction

/*
A = [1 2 3 4; 1 4 9 16;1 8 27 64;1 16 81 256]
 A  = 

   1.   2.    3.    4.  
   1.   4.    9.    16. 
   1.   8.    27.   64. 
   1.   16.   81.   256.
   
 b = [2 10 44 190]
 b  = 

   2.   10.   44.   190.


--> ejercicio10(A, b)
 ans  =

  -1.
   1.
  -1.
   1.
*/


/*
11)
b)
A = [16 -12 8 -16;-12 18 -6 9;8 -6 5 -10; -16 9 -10 46]

--> cholesky(A)
 ans  =

   4.  -3.   2.  -4.
   0.   3.   0.  -1.
   0.   0.   1.  -2.
   0.   0.   0.   5.
   

B = [4 1 1; 8 2 2; 1 2 3]
 B  = 

   4.   1.   1.
   8.   2.   2.
   1.   2.   3.

Podemos ver que esta factorización no es correcta ya que la matriz B no es simetrica positiva.


--> cholesky(B)
 ans  =

   2.   0.5         0.5      
   0.   1.3228757   1.3228757
   0.   0.          1. 
   

cholesky(C)
Matriz no definida positiva.
 ans  =

   1.   2.
   0.   0.

La U resultante no es inversible, por lo tanto no existe la factorización de Cholesky
*/

/*
12)


*/

function y = ejercicio12(A, b)
    [U, def] = cholesky(A)
       
    if def == 0 then
        y = []
    else
        L = U'
        g = sistemaInferior([L b])
        y = sistemaSuperior([U g])
    end
endfunction

/*
Resolviendo tenemos:

--> A = [16 -12 8; -12 18 -6; 8 -6 8]
 A  = 

   16.  -12.   8.
  -12.   18.  -6.
   8.   -6.    8.
   

--> b = [76 -66 46]
 b  = 

   76.  -66.   46.


--> ejercicio12(A, b)
 ans  =

   3.
  -1.
   2.

*/

function [U,ind] = cholesky(A)
// Factorización de Cholesky.
// Trabaja únicamente con la parte triangular superior.
//
// ind = 1  si se obtuvo la factorización de Cholesky.
//     = 0  si A no es definida positiva
//
//******************
eps = 1.0e-8
//******************

n = size(A,1)
U = zeros(n,n)

t = A(1,1)
if t <= eps then
    printf('Matriz no definida positiva.\n')
    ind = 0
    return
end
U(1,1) = sqrt(t)
for j = 2:n
    U(1,j) = A(1,j)/U(1,1)
end
    
for k = 2:n
    t = A(k,k) - U(1:k-1,k)'*U(1:k-1,k)
    if t <= eps then
        printf('Matriz no definida positiva.\n')
        ind = 0
        return
    end
    U(k,k) = sqrt(t)
    for j = k+1:n
        U(k,j) = ( A(k,j) - U(1:k-1,k)'*U(1:k-1,j) )/U(k,k)
    end
end
ind = 1

endfunction


/*
CROUT (metodo plus)
*/

function [L,U] = crout(A)
    n = size(A, "r")
    L = eye(n,n)
    U = eye(n,n)   
    L(:, 1) = A(:, 1)

    for j = 2:n
        U(1, j) = A(1,j)/L(1,1)
    end

    for i=2:n
        for j = 2:n
            if i >= j
                L(i, j) = (A(i, j) - L(i, 1:j-1)*U(1:j-1, j))
            else
                U(i, j) = (A(i, j) - (L(i, 1:i-1)*U(1:i-1, j)))/L(i, i)
            end
        end
    end
endfunction

/*
Factorización QR
*/

function [q, R] = QR(A)
    
    [nA, mA] = size(A)
    v(1) = norm(A(:,1))
    q(:,1) = A(:, 1)/v(1)
    
    for k = 2:nA
        v(k) = norm(A(:,k) - ((A(:,k)' * q(:, k-1)) * q(:, k-1)))
        
        q(:,k) =  (A(:,k) - (A(:,k)' * q(:, k-1)) * q(:, k-1))/v(k)
    end
    
    for i = 1:nA
        R(i,i) = v(i)
        for j = i+1:nA
            R(i,j) = A(:, j)' * q(:, i)
        end
    end
endfunction
























