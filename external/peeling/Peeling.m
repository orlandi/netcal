function [ca_p, peel_p, exp_p, data] = Peeling(dff, rate, varargin)
% this is the main routine of the peeling algorithm
%
% Peeling algorithm was developed by Fritjof Helmchen
% Brain Research Institute
% University of Zurich
% Switzerland
%
% Matlab implementation and spike timing optimization by Henry Luetcke & Fritjof Helmchen
% Brain Research Institute
% University of Zurich
% Switzerland
%
% Please cite:
% Grewe BF, Langer D, Kasper H, Kampa BM, Helmchen F. High-speed in vivo calcium imaging
% reveals neuronal network activity with near-millisecond precision.
% Nat Methods. 2010 May;7(5):399-405. 

maxRate_peel = Inf;

if rate > maxRate_peel
    peel_rate = maxRate_peel;
    fit_rate = rate;
    x = 1/rate:1/rate:numel(dff)/rate;
    xi = 1/peel_rate:1/peel_rate:max(x);
    peel_dff = interp1(x,dff,xi);
else
    peel_rate = rate;
    fit_rate = rate;
    peel_dff = dff;
end

[ca_p,exp_p,peel_p, data] = InitPeeling(peel_dff, peel_rate);

if nargin > 2
    for n = 1:numel(varargin)
        S = varargin{n};
        if n == 1
            ca_p = overrideFieldValues(ca_p,S);
        elseif n == 2
            exp_p = overrideFieldValues(exp_p,S);
        elseif n == 3
            peel_p = overrideFieldValues(peel_p,S);
        end
    end
end

data.model = 0;
data.freecamodel = ca_p.ca_rest; 
data.spikes = zeros(1,1000);
data.numspikes = 0;

data.peel = data.dff;

wsiz = round(peel_p.slidwinsiz*exp_p.acqrate);
checkwsiz = round(peel_p.negintwin*exp_p.acqrate);

peel_p.smttmindurFrames = ceil(peel_p.smttmindur*exp_p.acqrate);
peel_p.smttlowMinEvents = 1;

nexttim = 1/exp_p.acqrate;

[ca_p, peel_p, data] = FindNextEvent(ca_p, exp_p, peel_p, data, nexttim);
if (peel_p.evtfound == 1)
    data.numspikes = data.numspikes + 1;
    data.spikes(data.numspikes) = peel_p.nextevt;
    [ca_p, exp_p, data] = SingleFluorTransient(ca_p, exp_p, data, peel_p.spk_recmode, peel_p.nextevt);
    data.model = data.model + data.singleTransient;
end

maxiter = 999999;
iter = 0;
nexttimMem = Inf;
nexttimCounter = 0;
timeStepForward = 2./exp_p.acqrate;

%textprogressbar('Peeling: ');

while (peel_p.evtfound == 1)
    % check integral after subtracting Ca transient
    if (strcmpi(peel_p.spk_recmode,'linDFF'))
    elseif (strcmpi(peel_p.spk_recmode,'satDFF'))
       ca_p.onsetposition = peel_p.nextevt;
       ca_p = IntegralofCaTransient(ca_p, peel_p, exp_p, data);
    end
    
    dummy = data.peel - data.singleTransient;
    [~,startIdx] = min(abs(data.tim-data.spikes(data.numspikes)));
    [~,stopIdx] = min(abs(data.tim-(data.spikes(data.numspikes)+...
        peel_p.intcheckwin)));
    if startIdx < stopIdx
        currentTim = data.tim(startIdx:stopIdx);
        currentPeel = dummy(startIdx:stopIdx);
        currentIntegral = trapz(currentTim,currentPeel);
    else
        % if this is true, startIdx is the last data point and we should
        % not accept it as a spike
        currentIntegral = ca_p.negintegral*peel_p.negintacc;
    end
    if currentIntegral > (ca_p.negintegral*peel_p.negintacc)
        data.peel = data.peel - data.singleTransient;
        nexttim = data.spikes(data.numspikes) - peel_p.stepback;
        if (nexttim < 0)
            nexttim = 1/exp_p.acqrate;
        end
    else
        data.spikes(data.numspikes) = [];
        data.numspikes = data.numspikes-1;
        data.model = data.model - data.singleTransient;
        nexttim = peel_p.nextevt + timeStepForward;
    end
    
    peel_p.evtaccepted = 0;
    
    [ca_p, peel_p, data] = FindNextEvent(ca_p, exp_p, peel_p, data, nexttim);
    
    if peel_p.evtfound
            data.numspikes = data.numspikes + 1;
            data.spikes(data.numspikes) = peel_p.nextevt;
            [ca_p, exp_p, data] = SingleFluorTransient(ca_p, exp_p, data, peel_p.spk_recmode, peel_p.nextevt);
            data.model = data.model + data.singleTransient;
    else
        break
    end
    
    iter = iter + 1;
    
    if nexttim == nexttimMem
        nexttimCounter = nexttimCounter + 1;
    else
       nexttimMem = nexttim; 
       nexttimCounter = 0;
    end
    %%
    
    if nexttimCounter > 50
       nexttim = nexttim + timeStepForward; 
    end
    %if(mod(iter,floor(10)) == 0)
    %    textprogressbar(round(nexttim/(exp_p.numpnts/exp_p.acqrate)*100));
    %end
    if (iter > maxiter)
%         warning('Reached maxiter (%1.0f). nexttim=%1.2f. Timeout!',maxiter,nexttim);
%         save
%         error('Covergence failed!')
        break
    end
end

%textprogressbar(100);
%textprogressbar('Done!');

if length(data.spikes) > data.numspikes
    data.spikes(data.numspikes+1:end) = [];
end

% go back to original frame rate
if rate > maxRate_peel
    spikes = data.spikes;
    [ca_p,exp_p,peel_p, data] = InitPeeling(dff, fit_rate);
    if nargin > 2
        for n = 1:numel(varargin)
            S = varargin{n};
            if n == 1
                ca_p = overrideFieldValues(ca_p,S);
            elseif n == 2
                exp_p = overrideFieldValues(exp_p,S);
            elseif n == 3
                peel_p = overrideFieldValues(peel_p,S);
            end
        end
    end
    data.spikes = spikes;
end

% optimization of reconstructed spike times to improve timing
optMethod = 'pattern search';
optMaxIter = 100000;
%lowerT = 1; % relative to x0
%upperT = 1; % relative to x0
lowerT = 0.1; % relative to x0
upperT = 0.1; % relative to x0

if numel(data.spikes) && peel_p.optimizeSpikeTimes
    if (peel_p.spk_recmode == 'linDFF')
        spikes = PeelingOptimizeSpikeTimes(data.dff,data.spikes,lowerT,upperT,...
                    exp_p.acqrate,ca_p.onsettau,ca_p.amp1,ca_p.tau1,optMethod,optMaxIter,0);
    elseif (peel_p.spk_recmode == 'satDFF')
        spikes = PeelingOptimizeSpikeTimesSaturation(data.dff,data.spikes,lowerT,upperT,...
                    ca_p.ca_amp,ca_p.ca_gamma,ca_p.ca_onsettau,ca_p.ca_rest,ca_p.ca_kappas, exp_p.kd,...
                    exp_p.conc,exp_p.dffmax, exp_p.acqrate, length(data.dff)./exp_p.acqrate, optMethod,optMaxIter,0);
    else
        error('Undefined mode');
    end
    data.spikes = sort(spikes);
end

% fit onset to improve timing accuracy
if peel_p.fitonset
    onsetfittype = fittype('modelCalciumTransient(t,onsettime,onsettau,amp1,tau1)',...
        'independent','t','coefficients',{'onsettime','onsettau','amp1'},...
        'problem',{'tau1'});
    
    wleft = round(peel_p.fitwinleft*exp_p.acqrate);     % left window for onset fit
    wright = round(peel_p.fitwinright*exp_p.acqrate);    % right window for onset fit
    for i = 1:numel(data.spikes)
        i
        [~,idx] = min(abs(data.spikes(i)-data.tim));
        if (idx-wleft) < 1
            currentwin = data.dff(1:idx+wright);
            currenttim = data.tim(1:idx+wright);
        elseif (idx+wright) > numel(data.dff)
            currentwin = data.dff(idx-wleft:numel(data.dff));
            currenttim = data.tim(idx-wleft:numel(data.dff));
            currentwin = currentwin - mean(data.dff(idx-wleft:idx));
        else
            currentwin = data.dff(idx-wleft:idx+wright);
            currenttim = data.tim(idx-wleft:idx+wright);
            currentwin = currentwin - mean(data.dff(idx-wleft:idx));
        end
        lowerBounds = [currenttim(1) 0.1*ca_p.onsettau 0.5*ca_p.amp1];
        upperBounds = [currenttim(end) 5*ca_p.onsettau 10*ca_p.amp1];
        startPoint = [data.spikes(i) ca_p.onsettau ca_p.amp1];
        problemParams = {ca_p.tau1};
        
        fOptions = fitoptions('Method','NonLinearLeastSquares','Lower',...
            lowerBounds,...
            'Upper',upperBounds,'StartPoint',startPoint);
        [fitonset,gof] = fit(currenttim',currentwin',onsetfittype,...
            'problem',problemParams,fOptions);
        
        if gof.rsquare < 0.95
%                         fprintf('\nBad onset fit (t=%1.3f, r^2=%1.3f)\n',...
%                             data.spikes(i),gof.rsquare);
        else
            %             fprintf('\nGood onset fit (r^2=%1.3f)\n',gof.rsquare);
            data.spikes(i) = fitonset.onsettime;
        end
    end
end

% loop to create spike train vector from spike times
data.spiketrain = zeros(1,numel(data.tim));
for i = 1:numel(data.spikes)
    [~,idx] = min(abs(data.spikes(i)-data.tim));
    data.spiketrain(idx) = data.spiketrain(idx)+1;
end

% re-derive model and residuals after optimization

if (peel_p.spk_recmode == 'linDFF')
    modelTransient = spkTimes2Calcium(0,ca_p.onsettau,ca_p.amp1,ca_p.tau1,...
                                     ca_p.amp2,ca_p.tau2,exp_p.acqrate,max(data.tim));
    data.model = conv(data.spiketrain,modelTransient);
    data.model = data.model(1:length(data.tim));
elseif (peel_p.spk_recmode == 'satDFF')
    modeltmp = spkTimes2FreeCalcium(data.spikes,ca_p.ca_amp,ca_p.ca_gamma,ca_p.ca_onsettau,ca_p.ca_rest, ca_p.ca_kappas,...
                                    exp_p.kd, exp_p.conc,exp_p.acqrate,max(data.tim));
    data.model = Calcium2Fluor(modeltmp,ca_p.ca_rest,exp_p.kd, exp_p.dffmax);
end

data.peel = data.dff - data.model;

% plotting parameter
if isfield(peel_p,'doPlot')
    if peel_p.doPlot
        doPlot = 1;
    else
        doPlot = 0;
    end
else
    doPlot = 1;
end
if doPlot % plots at interpolation rate
    figure; plot(data.tim,data.peel); hold all
    plot(data.tim,data.dff); hold all
    plot(data.tim,data.spiketrain,'LineWidth',2)
    legend({'Residual','Calcium','UPAPs'}) % unverified putative action potential
end

end

function Sout = overrideFieldValues(Sout,Sin)
fieldIDs = fieldnames(Sin);
for n = 1:numel(fieldIDs)
    Sout.(fieldIDs{n}) = Sin.(fieldIDs{n});
end

end


