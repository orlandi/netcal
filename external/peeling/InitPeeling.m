function [ca_p,exp_p,peel_p, data] = InitPeeling(dff, rate)
%
% Initialization routine
% Peeling algorithm 
% by Henry Luetcke & Fritjof Helmchen
% Brain Research Institute
% University of Zurich
% Switzerland
%
% Last modifications: 
%
% 30.9.2013, FH: included free calcium transient to DF/F conversion; for
%                including saturation 
%

% ca_p: parameters of elementary (1 AP) calcium transient
ca_p.onsetposition =0.0;    % onset position(s)

%ca_p.usefreeca = 0;          % flag, 1 - use free calcium conc calculations and conversion to DF/F 
ca_p.ca_genmode = 'linDFF';   % flag for spike generation mode: 'linDFF' - simple linear DFF, or 'satDFF' - saturating indicator 
%ca_p.ca_genmode = 'satDFF';   % flag for spike generation mode: 'linDFF' - simple linear DFF, or 'satDFF' - saturating indicator 
ca_p.ca_onsettau=0.02;      % Ca transient - onset tau (s)
ca_p.ca_amp=7600;          % Ca transient - total amplitude 1 (nM)
ca_p.ca_gamma=400;          % Ca transient - extrusion rate (1/s)
ca_p.ca_amp1=0;             % Ca transient - free Ca amplitude 1  (nM)
ca_p.ca_tau1=0;             % Ca transient - free Ca tau (s)
ca_p.ca_kappas=100;         % Ca transient - endogenous Ca-binding ratio 
ca_p.ca_rest = 50;          % presumed resting calcium concentration (nM)
ca_p.ca_current = 50;       % current calcium concentration (nM)   

% now parameters for Indicator DF/F(or DR/R); used if 'useFreeCalcium' = 0; otherwise conversion equation is used                            
ca_p.onsettau=0.02;         % onset tau (s)
ca_p.offset=0;              % baseline offset (%)
ca_p.amp1=2.5;              % amplitude 1  (%)
ca_p.tau1=0.6;              % tau1 (s)
ca_p.amp2=0;                % amplitude 2 (%)
ca_p.tau2=1.0;              % tau2 (s)
ca_p.integral=0.0;          % integral below curve (%s)
ca_p.scale=1.0;             % scale factor to scale entire trace (s)

% exp_p: experiment parameters, including dye properties and data acquisition 
exp_p.numpnts = length(dff); % numpoints
exp_p.acqrate = rate;        % acquisition rate (Hz)
exp_p.noiseSD = 1.2;        % noise stdev of DF/F trace (in percent), should be specified by the user
exp_p.indicator = 'OGB-1';  % calcium indicator
exp_p.dffmax = 93;          % saturating dff max (in percent)
exp_p.kd = 250;             % dye dissociation constant (nM)
exp_p.conc = 50000;         % dye total concentration (nM)
exp_p.kappab = exp_p.kd.*exp_p.conc./(ca_p.ca_rest+exp_p.kd).^2;           % exogenous (dye) Ca-binding ratio
if (strcmpi(ca_p.ca_genmode,'linDFF'))
elseif (strcmpi(ca_p.ca_genmode,'satDFF'))
    ca_p.ca_amp1=ca_p.ca_amp./(1+ca_p.ca_kappas+exp_p.kappab);             % init for consistency
    ca_p.ca_tau1=(1+ca_p.ca_kappas+exp_p.kappab)./ca_p.ca_gamma;
end

% peel_p: parameters for peeling algorithm
peel_p.spk_recmode = 'linDFF'; % flag,for spike reconstruction mode: 'linearDFF', or 'saturatDFF'  
peel_p.padding = 20;        % number of points for padding before and after
peel_p.sdnoise = 1.4;       % expected SD baseline noise level
peel_p.smtthigh = 2.4*peel_p.sdnoise;      % Schmitt trigger - high threshold (FIX), 
peel_p.smttlow = -1.2*peel_p.sdnoise;      % Schmitt trigger - low threshold (FIX), 
peel_p.smttbox= 3;          % Schmitt trigger - smoothing box size (in points)
peel_p.smttmindur= 0.3;     % Schmitt trigger - minimum duration (s)

% HL: 2012-05-04
% new parameter: max. frames fro smttmindur
% if the frame rate is high, number of frames for smttmindur can be
% large, thereby increasing false negatives
% if smttminFrames is set, use binning to reduce the number of
% frames to this value for high frame rates
% peel_p.smttminFrames = 20;

peel_p.smttnumevts= 0;      % Schmitt trigger - number of found events
peel_p.slidwinsiz= 10.0;    % sliding window size - event detection (s)
peel_p.maxbaseslope= 0.5;   % maximum baseslope %/s
peel_p.evtfound=0;          % flag - 1: crossing found 
peel_p.nextevt=0;           % next crossing found (s)
peel_p.nextevtframe=0;      % next crossing found (frame number)
peel_p.intcheckwin=0.5;     % window to the right - for integral comparison (s)
peel_p.intacclevel=0.5;     % event integral acceptance level (0.5 means 50%)
peel_p.fitonset=0;          % flag - 1: do onset fit, only useful if 1/frameRate <= rise of CacliumTransient
peel_p.fitwinleft=0.5;     % left window for onset fit (s)
peel_p.fitwinright=0.5;    % right window for onset fit (s)
peel_p.negintwin=0.1;       % window to the right - for negativeintegral check(s)
peel_p.negintacc=0.5;       % negative acceptance level (0.5 means 50%)
peel_p.stepback=5.0;        % stepsize backwards for next iteration (s)
peel_p.fitupdatetime=0.5;     % how often the linear fit is updated (s)
peel_p.optimizeSpikeTimes = 1; % FIX
peel_p.doPlot = 0; %FIX
% data: data struct 
data.dff = dff;
data.freeca = zeros(1,exp_p.numpnts);           % free calcium transient, from which dff will need to be calculated 
data.tim = 1:length(data.dff); 
data.tim = data.tim./exp_p.acqrate;
data.intdff = 1:length(data.dff);                % integral curve
data.singleTransient = zeros(1,exp_p.numpnts);   % fluorescence transient for current AP, will take ca2fluor mode into account
data.freecamodel = zeros(1,exp_p.numpnts);
data.model = zeros(1,exp_p.numpnts);
data.spiketrain = zeros(1,exp_p.numpnts);
data.slide = zeros(1,exp_p.numpnts);            % sliding curve, zero corrected
data.temp = 1:length(data.dff);                 % temporary wave
data.peel = zeros(1,exp_p.numpnts);
data.peel = data.dff;
data.spikes = zeros(1,1000);                    % array for found spikes times
data.numspikes = 0;                             % number of spikes found
[ca_p, exp_p, data] = SingleFluorTransient(ca_p, exp_p, data, ca_p.ca_genmode, 1./exp_p.acqrate);



