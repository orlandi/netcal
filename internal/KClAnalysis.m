function experiment = KClAnalysis(experiment, varargin)
% KCLANALYSIS Analyzes the effect of the KCl protocol
%
% USAGE:
%   experiment = KClAnalysis(experiment, options)
%
% INPUT arguments:
%   experiment - structure containing an experiment
%
% INPUT optional arguments:
%   options - object from class KClProtocolOptions
%
% OUTPUT arguments:
%   experiment - structure containing an experiment
%
% EXAMPLE:
%   experiment = KClAnalysis(experiment, KClProtocolOptions)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also KClProtocolOptions

% EXPERIMENT PIPELINE
% name: KCl Analysis
% parentGroups: protocols: intra-experiment: KCl analysis
% optionsClass: KClProtocolOptions
% requiredFields: rawTraces, t, fps
% producedFields: KClProtocolData

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(KClProtocolOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Running KCl analysis');
%--------------------------------------------------------------------------

% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end

% Get ALL subgroups in case of parents
if(strcmpi(mainGroup, 'all'))
  groupList = getExperimentGroupsNames(experiment);
else
  groupList = getExperimentGroupsNames(experiment, mainGroup);
end

% Empty check
if(isempty(groupList))
  logMsg(sprintf('Group %s not found on experiment %s', mainGroup, experiment.name), 'w');
  return;
end

if(isfield(experiment, 'KClProtocolData') && length(experiment.KClProtocolData) ~= length(experiment.ROI))
  logMsg('Inconsistent length of KClProtocolData. Resetting', 'w');
  experiment.KClProtocolData = cell(length(experiment.ROI), 1);
elseif(~isfield(experiment, 'KClProtocolData'))
  experiment.KClProtocolData = cell(length(experiment.ROI), 1);
end


% Time to iterate through all the groups
for git = 1:length(groupList)
  if(params.pbar > 0)
    ncbar.setBarTitle(sprintf('Running KCl analysis from group: %s', groupList{git}));
  end
  if(strcmpi(groupList{git}, 'none'))
    members = 1:length(experiment.ROI);
    groupName = 'everything';
    groupIdx = 1;
  else
    [members, groupName, groupIdx] = getExperimentGroupMembers(experiment, groupList{git});
  end
  
  % Check for empty group
  if(isempty(members) && params.verbose)
    logMsg(sprintf('Found empty group: %s', groupList{git}), 'w');
    continue;
  end
  
  switch params.tracesType
    case 'smoothed'
      experiment = loadTraces(experiment, 'normal');
      t = experiment.t;
      traces = experiment.traces;
    case 'raw'
      experiment = loadTraces(experiment, 'raw');
      t = experiment.rawT;
      traces = experiment.rawTraces;
    case 'denoised'
      experiment = loadTraces(experiment, 'rawTracesDenoised');
      t = experiment.rawTDenoised;
      traces = experiment.rawTraces;
  end
  
  % The actual protocol goes here
  protocolData = computeProtocolStatistics(traces(:, members), t, params);
  
  % Now outputs and assignations
  experiment.KClProtocolData(members) = protocolData;
  
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------


function protocolData = computeProtocolStatistics(currentTraces, t, params)
  protocolData = cell(size(currentTraces, 2), 1);
  if(isempty(params.startTime))
    params.startTime = t(1);
  end
  if(isempty(params.windowOfInterest) || isinf(params.windowOfInterest))
    params.windowOfInterest = t(end)-params.startTime;
  end
  if(isempty(params.endTime) || isinf(params.endTime))
    params.endTime = t(end);
  end
  [~, firstBaseLineFrame] = min(abs(t-(params.startTime-params.baseLineDefinitionTime)));
  [~, lastBaseLineFrame] = min(abs(t-params.startTime));
  [~, endFrame] = min(abs(t-params.endTime));
  validResponseFrames = find(t >= params.startTime & t < (params.startTime + params.windowOfInterest));
  switch params.protocolType
    case 'positive'
      protocolSign = 1;
    case 'negative'
      protocolSign = -1;
  end
  
  for it = 1:length(protocolData)
    currentTrace = currentTraces(:, it);
    %%% Start with the baseline
    baseLine = mean(currentTrace(firstBaseLineFrame:lastBaseLineFrame));
    
    %%% Now the reaction time
    switch params.reactionTimeThresholdType
      case 'relative'
        reactionTimeThreshold = baseLine + protocolSign*params.reactionTimeThreshold*std(currentTrace(firstBaseLineFrame:lastBaseLineFrame));
      case 'absolute'
        reactionTimeThreshold = params.reactionTimeThreshold;
    end
    if(protocolSign == 1)
      reactionTimeIdx = validResponseFrames(1) - 1 + find(currentTrace(validResponseFrames) >= reactionTimeThreshold, 1, 'first');
    else
      reactionTimeIdx = validResponseFrames(1) - 1 + find(currentTrace(validResponseFrames) <= reactionTimeThreshold, 1, 'first');
    end
    if(~isempty(reactionTimeIdx))
      reactionTime = t(reactionTimeIdx)-params.startTime;
    else
      reactionTimeIdx = [];
      reactionTime = NaN;
    end
    
    %%% Now the response time and value
    switch params.maxResponseThresholdType
      case 'relative'
        maxResponse = prctile(currentTrace(validResponseFrames), (protocolSign*params.maxResponseThreshold+(protocolSign-1)/2)*100);
      case 'absolute'
        maxResponse = params.maxResponseThreshold;
    end
    if(protocolSign == 1)
      maxResponseTimeIdx = validResponseFrames(1) - 1 + find(currentTrace(validResponseFrames) >= maxResponse, 1, 'first');
    else
      maxResponseTimeIdx = validResponseFrames(1) - 1 + find(currentTrace(validResponseFrames) <= maxResponse, 1, 'first');
    end
    if(~isempty(maxResponseTimeIdx) && ~isempty(reactionTimeIdx) && ~isempty(maxResponseTimeIdx) && ~isempty(reactionTimeIdx))
      maxResponseTime = t(maxResponseTimeIdx)-t(reactionTimeIdx);
    else
      maxResponseTimeIdx = [];
      maxResponseTime = NaN;
    end
    
    %%% Now the decay time and value
    switch params.decayThresholdType
      case 'relative'
        decay = prctile(currentTrace(validResponseFrames), (protocolSign*params.decayThreshold+(protocolSign-1)/2)*100);
      case 'absolute'
        decay = params.decayThreshold;
    end
    if(~isempty(maxResponseTimeIdx))
      if(protocolSign == 1)
        decayTimeIdx = maxResponseTimeIdx - 1 + find(currentTrace(maxResponseTimeIdx:validResponseFrames(end)) <= decay, 1, 'first');
      else
        decayTimeIdx = maxResponseTimeIdx - 1 + find(currentTrace(maxResponseTimeIdx:validResponseFrames(end)) >= decay, 1, 'first');
      end
    else
      decayTimeIdx  = [];
    end
    if(~isempty(decayTimeIdx) && ~isempty(reactionTimeIdx) && ~isempty(decayTimeIdx) && ~isempty(reactionTimeIdx))
      decayTime = t(decayTimeIdx)-t(reactionTimeIdx);
    else
      decayTimeIdx = [];
      decayTime = NaN;
    end
    
    %%% Now the recovery time
    switch params.recoveryTimeThresholdType
      case 'relative'
        recoveryTimeThreshold = baseLine + protocolSign*params.recoveryTimeThreshold*std(currentTrace(firstBaseLineFrame:lastBaseLineFrame));
      case 'absolute'
        recoveryTimeThreshold = params.recoveryTimeThreshold;
    end
    if(~isempty(decayTimeIdx) && ~isempty(decayTimeIdx))
      if(protocolSign == 1)
        recoveryTimeIdx = decayTimeIdx - 1 + find(currentTrace(decayTimeIdx:validResponseFrames(end)) <= recoveryTimeThreshold, 1, 'first');
      else
        recoveryTimeIdx = decayTimeIdx - 1 + find(currentTrace(decayTimeIdx:validResponseFrames(end)) >= recoveryTimeThreshold, 1, 'first');
      end
      if(~isempty(recoveryTimeIdx))
        recoveryTime = t(recoveryTimeIdx)-params.startTime;
      else
        recoveryTimeIdx = [];
        recoveryTime = NaN;
      end
    else
      recoveryTimeIdx = [];
      recoveryTime = NaN;
    end
    if(~isempty(decayTimeIdx) && ~isempty(maxResponseTimeIdx) && ~isempty(decayTimeIdx) && ~isempty(maxResponseTimeIdx))
      responseDuration = t(decayTimeIdx)-t(maxResponseTimeIdx);
    else
      responseDuration = NaN;
    end
    
    %%% Now the fits
    switch params.riseFitType
      case 'none'
        NriseCoeffs = 0;
      case 'linear'
        f = fittype('poly1');
        NriseCoeffs = 2;
      case 'single exponential'
        f = fittype('exp1');
        NriseCoeffs = 2;
      case 'double exponential'
        f = fittype('exp2');
        NriseCoeffs = 4;
    end
    if(~strcmp(params.riseFitType, 'none') && ~isempty(reactionTimeIdx) && ~isempty(reactionTimeIdx) && ~isempty(maxResponseTimeIdx) && ~isempty(maxResponseTimeIdx) && length(reactionTimeIdx:maxResponseTimeIdx) > 5)
      [fitRise, goefRise] = fit(t(reactionTimeIdx:maxResponseTimeIdx), currentTrace(reactionTimeIdx:maxResponseTimeIdx), f);
    else
      fitRise = [];
      goefRise = [];
    end
    
    switch params.decayFitType
      case 'none'
        NdecayCoeffs = 0;
      case 'linear'
        f = fittype('poly1');
        NdecayCoeffs = 2;
      case 'single exponential'
        f = fittype('exp1');
        NdecayCoeffs = 2;
      case 'double exponential'
        f = fittype('exp2');
        NdecayCoeffs = 4;
    end
    if(~strcmp(params.riseFitType, 'none') && ~isempty(recoveryTimeIdx) && ~isempty(recoveryTimeIdx) && ~isempty(decayTimeIdx) && ~isempty(decayTimeIdx) && length(decayTimeIdx:recoveryTimeIdx) > 5)
      [fitDecay, goefDecay] = fit(t(decayTimeIdx:recoveryTimeIdx), currentTrace(decayTimeIdx:recoveryTimeIdx), f);
    else
      fitDecay = [];
      goefDecay = [];
    end
    
    protocolData{it}.baseLine = baseLine;
    protocolData{it}.baseLineFrame = lastBaseLineFrame;
    protocolData{it}.reactionTime = reactionTime;
    protocolData{it}.reactionTimeIdx = reactionTimeIdx;
    protocolData{it}.maxResponse = maxResponse;
    protocolData{it}.maxResponseTimeIdx = maxResponseTimeIdx;
    protocolData{it}.maxResponseTime = maxResponseTime;
    protocolData{it}.recoveryTimeIdx = recoveryTimeIdx;
    protocolData{it}.recoveryTime = recoveryTime;
    protocolData{it}.recovered = ~isempty(recoveryTimeIdx);
    protocolData{it}.decayTimeIdx = decayTimeIdx;
    protocolData{it}.decayTime = decayTime;
    protocolData{it}.decay = decay;
    protocolData{it}.responseDuration = responseDuration;
    protocolData{it}.protocolEndFrame = endFrame;
    protocolData{it}.protocolEndValue = currentTrace(endFrame);
    protocolData{it}.lastResponseFrame = validResponseFrames(end);
    protocolData{it}.lastResponseValue = currentTrace(validResponseFrames(end));
    if(~isempty(fitRise))
      protocolData{it}.fitRiseCoeffs = coeffvalues(fitRise);
      protocolData{it}.fitRiseCoeffNames = coeffnames(fitRise);
      protocolData{it}.fitRiseRsquare = goefRise.rsquare;
      protocolData{it}.fitRiseCurve = [t(reactionTimeIdx:maxResponseTimeIdx), fitRise(t(reactionTimeIdx:maxResponseTimeIdx))];
    else
      protocolData{it}.fitRiseCoeffs = [];
      protocolData{it}.fitRiseCoeffNames = [];
      protocolData{it}.fitRiseRsquare = [];
      protocolData{it}.fitRiseCurve = [];
      if(NriseCoeffs > 0)
        protocolData{it}.fitRiseCoeffs = zeros(NriseCoeffs, 1);
        protocolData{it}.fitRiseCoeffNames = cell(NriseCoeffs, 1);
        protocolData{it}.fitRiseRsquare = 0;
      end
    end
    if(~isempty(fitDecay))
      protocolData{it}.fitDecayCoeffs = coeffvalues(fitDecay);
      protocolData{it}.fitDecayCoeffNames = coeffnames(fitDecay);
      protocolData{it}.fitDecayRsquare = goefDecay.rsquare;
      protocolData{it}.fitDecayCurve = [t(decayTimeIdx:recoveryTimeIdx), fitDecay(t(decayTimeIdx:recoveryTimeIdx))];
    else
      protocolData{it}.fitDecayCoeffs = [];
      protocolData{it}.fitDecayCoeffNames = [];
      protocolData{it}.fitDecayRsquare = [];
      protocolData{it}.fitDecayCurve = [];
      if(NdecayCoeffs > 0)
        protocolData{it}.fitDecayCoeffs = zeros(NdecayCoeffs, 1);
        protocolData{it}.fitDecayCoeffNames = cell(NdecayCoeffs, 1);
        protocolData{it}.fitDecayRsquare = 0;
      end
    end
    ncbar.update(it/length(protocolData));
  end
end

end