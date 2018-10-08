function [y, x] = spkTimes2FreeCalcium(spkT,Ca_amp,Ca_gamma,Ca_onsettau,Ca_rest, kappaS,...
    Kd, Conc,frameRate,duration)
% returns modeled free calcium trace derived from list of spike times (spkT)
% calculated based on buffered increment Ca_amp and taking indicator
% binding into account

% Fritjof Helmchen (helmchen@hifo.uzh.ch)
% Brain Research Institute
% University of Zurich
% Switzerland
% FH: 7.10.2013

x = 1/frameRate:(1/frameRate):duration;
y = zeros(1,length(x)); y(:) = Ca_rest;
unfilt = zeros(1,length(x)); unfilt(:) = Ca_rest;

for i = 1:numel(spkT)
    if i < numel(spkT)
        ind = find(x >= spkT(i), 1, 'first');
        lastind = find(x >= spkT(i+1), 1, 'first');
        if (lastind-ind) <= 2
            lastind = ind+2;  % have at least 3 points to process
        end
    else
        ind = find(x >= spkT(i), 1, 'first');
        lastind = find(x >= spkT(i), 1, 'last');
        if (lastind-ind) <= 2
            ind = lastind-2;  % have at least 3 points to process
        end
    end    
        
    tspan = x(ind:lastind);
    
    %currentCa = y(ind); 
    currentCa = unfilt(ind);
    
    Y0 = currentCa;   % current ca conc following increment due to next spike
    [~,ylow] = CalciumDecay(Ca_gamma,Ca_rest,Y0, kappaS, Kd, Conc, tspan);   % solving ODE for single comp model
        
    kappa = Kd.*Conc./(currentCa+Kd).^2;
    Y0 = currentCa + Ca_amp./(1+kappaS+kappa);   % current ca conc following increment due to next spike
    [~,yout] = CalciumDecay(Ca_gamma,Ca_rest,Y0, kappaS, Kd, Conc, tspan);   % solving ODE for single comp model
    
    unfilt(ind:lastind) = yout;
    
    % now onset filtering with rising exponential
    % caonset = (1 - exp(-(tspan-tspan(1))./Ca_onsettau));
    caonset = (1 - exp(-(tspan-spkT(i))./Ca_onsettau));
    caonset( caonset < 0) = 0;
    difftmp = yout - ylow;
    yout = difftmp.*caonset' + ylow;
          
    y(ind:lastind) = yout;
end
