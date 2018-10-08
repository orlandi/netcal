function [ca_p, exp_p, data] = SingleFluorTransient(ca_p, exp_p, data, mode, starttim)
% ca_p - parameter for calcium dynamics  
% data - data and analysis traces
% mode - 'linDFF' or 'satDFF'
% starttim - start of the fluorescence transient
%
%  Modifications:
%  30.9.2013, FH: included saturation mode
%  last update: 25.10.2013 fh

ca_p.onsetposition = starttim;
% data.singleTransient(1:end) = ca_p.offset;
if (mode == 'linDFF')
    data.singleTransient = repmat(ca_p.offset,1,numel(data.tim));
elseif (mode == 'satDFF')
    data.singleTransient = zeros(1,numel(data.tim));
end

% for n = 1:length(data.singleTransient)
%     if (data.tim(n) > ca_p.onsetposition)
%        data.singleTransient(n) = data.singleTransient(n) + ca_p.scale*(1-exp(-(data.tim(n)-ca_p.onsetposition)/ca_p.onsettau)) * ...
%            (ca_p.amp1*exp(-(data.tim(n)-ca_p.onsetposition)/ca_p.tau1)+ ca_p.amp2*exp(-(data.tim(n)-ca_p.onsetposition)/ca_p.tau2));
%     end
% end

% faster version - Felipe Gerhard
ind = data.tim >= ca_p.onsetposition; % relevant indices
firstind = find(ind, 1, 'first');
lastind = find(ind, 1, 'last');

if (strcmp(mode,'linDFF'))
    data.singleTransient(ind) = ca_p.offset + ...
    ca_p.scale.*(1-exp(-(data.tim(ind)-ca_p.onsetposition)./ca_p.onsettau)) .* ...
          (ca_p.amp1.*exp(-(data.tim(ind)-ca_p.onsetposition)./ca_p.tau1)+ ...
          ca_p.amp2.*exp(-(data.tim(ind)-ca_p.onsetposition)./ca_p.tau2));
elseif(strcmp(mode,'satDFF'))
    if (lastind - firstind <= 2) 
        firstind= lastind-2;  % have at least 3 points at end of trace for processing
    end
    
    %indoffset = round( 3.*ca_p.ca_onsettau.*exp_p.acqrate );
    
    if (firstind==1)
            ca_p.ca_current = Fluor2Calcium(data.dff(1),ca_p.ca_rest,exp_p.kd, exp_p.dffmax);  % set to rest when transsient at start of trace
    else
            ca_p.ca_current = Fluor2Calcium(data.dff(firstind-1),ca_p.ca_rest,exp_p.kd, exp_p.dffmax);  %calculate current, preAP Ca level
    end
    
    tspan = data.tim(firstind:lastind);
        
    % decay from pre AP level
    Y0 = ca_p.ca_current;
    [~,lowtmp] = CalciumDecay(ca_p.ca_gamma,ca_p.ca_rest,Y0, ca_p.ca_kappas, exp_p.kd, exp_p.conc, tspan);
    lowdff = Calcium2Fluor(lowtmp,ca_p.ca_rest,exp_p.kd, exp_p.dffmax);
    
    % decay from post AP level
    exp_p.kappab = exp_p.kd.*exp_p.conc./(ca_p.ca_current+exp_p.kd).^2;  % recalculate kappab and ca_amp1 
    ca_p.ca_amp1=ca_p.ca_amp./(1+ca_p.ca_kappas+exp_p.kappab);
    Y0 = ca_p.ca_current + ca_p.ca_amp1;
    [~,hightmp] = CalciumDecay(ca_p.ca_gamma,ca_p.ca_rest,Y0, ca_p.ca_kappas, exp_p.kd, exp_p.conc, tspan);
    highdff = Calcium2Fluor(hightmp,ca_p.ca_rest,exp_p.kd, exp_p.dffmax);
    
    difftmp = highdff' - lowdff';
    caonset = (1 - exp(-(tspan-tspan(1))./ca_p.ca_onsettau));  % filter with exponential rise 
    data.singleTransient(firstind:lastind) = difftmp.*caonset;
else
    error('Undefined mode for SingleTransient generation');
end
end


      