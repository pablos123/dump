// Argumentos: Matriz, Vector, Aproximacion Inicial, Condicion de corte
function x = jacobi(A,b,x0,eps)
    n = size(A,1);
    x = x0;
    xk = x;
    suma = 0;

    // Calculo x1 
    for i=1:n
    	suma = 0
        for j = 1:n
            if (i<>j)
                suma = suma + A(i,j)*xk(j)
            end
        end
    	x(i) = 1/A(i,i)*(b(i)-suma)
    end

    // Calculo xn
    while (abs(norm(x-xk))> eps)
        xk = x;
        for i=1:n
            suma = 0
            for j = 1:n
                if (i<>j)
                    suma = suma + A(i,j)*xk(j)
                end
            end
            x(i) = 1/A(i,i)*(b(i)-suma)
        end
    end
endfunction






















