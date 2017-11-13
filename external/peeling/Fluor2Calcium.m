function caout = Fluor2Calcium(f,ca_rest,kd, dffmax)
% Conversion function. Transforms DFF value to calcium concentration absolute value 
% 
% Fritjof Helmchen (helmchen@hifo.uzh.ch)
% Brain Research Institute,University of Zurich, Switzerland
% created: 7.10.2013 fh

caout = (ca_rest + kd.*f./dffmax)./(1 - f./dffmax);


      