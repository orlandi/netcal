function y = qlog(x, q)
% q-logarithm
  if( q ~= 1)
    y = (x.^(1-q)-1)./(1-q);
  else
    y = log(x);
  end
end