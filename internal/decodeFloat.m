function num = decodeFloat(wholeData, fracData)
    whole = fromBytes(wholeData);
    frac = fromBytes(fracData);
    if(frac == 0)
        num = whole;
    else
        num = whole + frac*10^-(floor(log10(frac))+1);
    end
end
