function y = modelCalciumTransient(t,onsettime,onsettau,amp1,tau1)

offset = 0;
y = repmat(offset,numel(t),1);

ind = t > onsettime;
y(ind) = offset + (1-exp(-(t(ind)-onsettime)./onsettau)) .* ...
          (amp1.*exp(-(t(ind)-onsettime)./tau1));