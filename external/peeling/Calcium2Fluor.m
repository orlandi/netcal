function fout = Calcium2Fluor(ca,ca_rest,kd, dffmax)
% Conversion function, transform calcium concentration to DFF value 
% 
% Fritjof Helmchen (helmchen@hifo.uzh.ch)
% Brain Research Institute,University of Zurich, Switzerland
% created: 7.10.2013 fh

fout = dffmax.*(ca - ca_rest)./(ca + kd);


      