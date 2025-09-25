// Test functions
function y = cuadrado_menos_uno(x)
    y = x * x - 1
endfunction

function y = F(x)
    f1 = x(1)^2+x(2)^2-290;
    f2 = x(1)+x(2)-24;
    y = [f1;f2];
endfunction

// ej3
function y = multiple_cos(x0, n)
    y = x0
    for i = 1:n
        y = cos(y)
    end
endfunction
