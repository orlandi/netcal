function [H, C] = measureQcomplexityEntropyCurve(P, d, qList)
% As in Ribeiro, PRE 2017 - DOI 10.1103/PhysRevE.95.062106
% P the PDF
% d - the embedding dimension
% q - values of q to explore

  H = zeros(size(qList));
  C = zeros(size(qList));
  facd = factorial(d);
  for it = 1:length(qList)
    q = qList(it);

    if(q ~= 1)
      SqP = 1./(q-1)*(1-nansum(P.^q));
    else
      SqP = nansum(-P.*log(P));
    end
    SqU = qlog(facd, q);
    DqPU = -0.5*nansum(P.*qlog((P+1/facd)./(2*P), q))-0.5*sum(1/facd*qlog((P+1/facd)/(2/facd), q));
    if(q ~= 1)
      DqStar = (2^(2-q)*facd-(1+facd)^(1-q)-facd*(1+1/facd)^(1-q)-facd+1)/((1-q)*2^(2-q)*facd);
    else
      DqStar = -1/2*((facd+1)/facd*log(facd+1)-log(facd)-2*log(2));
    end

    H(it) = SqP./SqU;
    C(it) = DqPU*H(it)/DqStar;
  end
end