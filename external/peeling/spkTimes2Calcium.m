function [y, x] = spkTimes2Calcium(spkT,tauOn,ampFast,tauFast,ampSlow,...
    tauSlow,frameRate,duration)
% for OGB1-AM (from Grewe et al., Nat Meth, 2010)
% tauOn ... 10ms
% ampFast ... 8% tauFast ... 60ms
% ampSlow ... 3% tauSlow ... 800ms

% Henry Luetcke (hluetck@gmail.com)
% Brain Research Institut
% University of Zurich
% Switzerland

x = 0:(1/frameRate):duration;
y = (1-(exp(-(x-spkT)./tauOn))).*...
    (ampFast.*exp(-(x-spkT)./tauFast))+(ampSlow.*exp(-(x-spkT)./tauSlow)); 
% y = (1-(exp(-(x-spkT)./tauOn))).*(ampFast*exp(-(x-spkT)./tauFast));
y(x<spkT) = 0;
y(isnan(y)) = 0;