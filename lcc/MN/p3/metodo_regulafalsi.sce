funcprot(0)

function y = metodo_regulafalsi_iterativo(f, a, b, e, it);
    fb = f(b)
    fa = f(a)

    c = b - fb * (b - a) / (fb - fa)

    i = 0
    while (b - c) > e && i < it
        fc = f(c)
        if fb * fc <= 0
            a = c
            fa = fc
        else
            b = c
            fb = fc
        end

        c = b - fb * (b - a) / (fb - fa)
        i = i + 1
    end

    y = c
endfunction

