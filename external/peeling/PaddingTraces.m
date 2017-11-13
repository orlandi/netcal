function data = PaddingTraces(exp_p, peel_p, data)

% padding of traces in working array
data.dff_pad = zeros(1,exp_p.numpnts+2*peel_p.padding);
data.dff_pad(peel_p.padding+1:peel_p.padding+exp_p.numpnts) = ...
    data.dff(1:exp_p.numpnts);
data.peel_pad = zeros(1,exp_p.numpnts+2*peel_p.padding);
data.peel_pad(peel_p.padding+1:peel_p.padding+exp_p.numpnts) = ...
    data.peel(1:exp_p.numpnts);
data.slide_pad = zeros(1,exp_p.numpnts+2*peel_p.padding);
data.temp_pad = zeros(1,exp_p.numpnts+2*peel_p.padding);
data.tim_pad = -peel_p.padding+1:length(data.peel_pad)-peel_p.padding; 
data.tim_pad = data.tim_pad./exp_p.acqrate;
