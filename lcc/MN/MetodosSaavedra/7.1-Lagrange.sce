funcprot(0);

function y = Lk(x, k)
    n = length(x);
    r = [x(1:k-1), x(k+1:n)];
    p = poly(r, "x", "roots");
    pk = horner(p, x(k));
    y = p / pk;
endfunction

function y = mlagrange(x,y)
    n = length(x);
    p = 0;
    for k = 1:n
        p = p + Lk(x,k) * y(k)
    end
    y = p;
endfunction

