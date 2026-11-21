function num = fromBytes(data)
    num = 0;
    for i = 1:length(data)
        num = num + bitshift(data(i), (i-1)*8);
    end
end