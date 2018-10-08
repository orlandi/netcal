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
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also KClProtocolOptions

% EXPERIMENT PIPELINE
% name: KCl Analysis
% parentGroups: protocols: KCl analysis
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

% if(isfield(experiment, 'KClProtocolData') && length(experiment.KClProtocolData) ~= length(experiment.ROI))
%   logMsg('Inconsistent length of KClProtocolData. Resetting', 'w');
%   experiment.KClProtocolData = cell(length(experiment.ROI), 1);
% elseif(~isfield(experiment, 'KClProtocolData'))
%   experiment.KClProtocolData = cell(length(experiment.ROI), 1);
% end


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
  if(~isfield(experiment, 'KClProtocolData'))
    experiment.KClProtocolData = struct;
  end
  if(~isstruct(experiment.KClProtocolData))
    experiment.KClProtocolData = struct;
  end
  if(~isfield(experiment.KClProtocolData, groupName))
    experiment.KClProtocolData.(groupName) = {};
  end
  experiment.KClProtocolData.(groupName){groupIdx} = protocolData;
  %members = experiment.traceGroups.(nameComponents{1}){validCategory};
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

function protocolData = computeProtocolStatistics(currentTraces, t, params)
  protocolData = struct;
  %cell(size(currentTraces, 2), 1);
  arrayFields = {'baseLine',  'baseLineFrame',  'reactionTime',  'reactionTimeIdx',  'maxResponse',  'maxResponseTimeIdx',  'maxResponseTime',  'recoveryTimeIdx',  'recoveryTime',  'recovered',  'decayTimeIdx',  'decayTime',  'decay',  'responseDuration',  'protocolEndFrame',  'protocolEndValue',  'lastResponseFrame',  'lastResponseValue', 'responseFitSegments',  'responseFitSegmentsMaxFluorescenceIncrease',  'responseFitSegmentsMaxSlope'};
  cellFields = {'responseFitFrames', 'responseFitModel', 'responseFitSegmentsDuration', 'responseFitSegmentsFluorescenceIncrease', 'responseFitSegmentsSlope'};
  for it = 1:length(arrayFields)
    protocolData.(arrayFields{it}) = nan(size(currentTraces, 2), 1);
  end
  for it = 1:length(cellFields)
    protocolData.(cellFields{it}) = cell(size(currentTraces, 2), 1);
  end
  
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
  
  for it = 1:size(currentTraces, 2)
      try
        currentTrace = currentTraces(:, it);
        %%% Start with the baseline
        %baseLine = mean(currentTrace(firstBaseLineFrame:lastBaseLineFrame));
        baseLine = prctile(currentTrace(firstBaseLineFrame:lastBaseLineFrame), params.baseLineThreshold*100);

        %%% Now the reaction time
        switch params.reactionTimeThresholdType
          case 'relative'
            reactionTimeThreshold = baseLine + protocolSign*params.reactionTimeThreshold*std(currentTrace(firstBaseLineFrame:lastBaseLineFrame));
          case 'absolute'
            reactionTimeThreshold = params.reactionTimeThreshold;
        end
        switch params.onsetDetectionMethod
            case 'baseLine'
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
            case 'valleyDetection'
                done = false;
                curIt = 1;
                curMult = params.valleyDetectionTilt;
                while(~done)
                    y = max(currentTrace)-currentTrace+(1:length(currentTrace))'/curMult;
                    [~, locs] = findpeaks(y, 'MinPeakProminence', params.valleyProminence);
                    reactionTimeIdx = [];
                    reactionTime = NaN;
                    for it2 = 1:length(locs)
                        if(any(validResponseFrames == locs(it2)))
                            reactionTimeIdx = locs(it2);
                            reactionTime = t(reactionTimeIdx)-params.startTime;
                            done = true;
                            break;
                        end
                    end
                    curIt = curIt+1;
                    curMult = curMult*2;
                    if(curIt > 5)
                        done = true;
                    end
                end
        end

        %%% Now the response time and value
        if(~isempty(reactionTimeIdx))
            validResponseFramesMax = reactionTimeIdx:validResponseFrames(end);
            switch params.maxResponseThresholdType
              case 'relative'
                maxResponse = prctile(currentTrace(validResponseFramesMax), (protocolSign*params.maxResponseThreshold+(protocolSign-1)/2)*100);
              case 'absolute'
                maxResponse = params.maxResponseThreshold;
            end
            if(protocolSign == 1)
              maxResponseTimeIdx = validResponseFramesMax(1) - 1 + find(currentTrace(validResponseFramesMax) >= maxResponse, 1, 'first');
            else
              maxResponseTimeIdx = validResponseFramesMax(1) - 1 + find(currentTrace(validResponseFramesMax) <= maxResponse, 1, 'first');
            end
        end
        if(~isempty(maxResponseTimeIdx) && ~isempty(reactionTimeIdx) && ~isempty(maxResponseTimeIdx) && ~isempty(reactionTimeIdx))
          maxResponseTime = t(maxResponseTimeIdx)-t(reactionTimeIdx);
        else
          maxResponseTimeIdx = [];
          maxResponseTime = NaN;
        end
        % The primary response fit
        ipt = [];
        if(params.responseFit && ~isempty(maxResponseTimeIdx) && ~isempty(reactionTimeIdx))
          valid = reactionTimeIdx:maxResponseTimeIdx;
          %[ipt, res] = findchangepts(currentTrace(valid), 'maxNumChanges', maxC, 'Statistic' ,'linear', 'minDistance', round(params.responseFitMinimumTime*experiment.fps));
          [ipt, res] = findchangepts(currentTrace(valid), 'minThreshold', params.responseFitResidual, 'Statistic' ,'linear', 'minDistance', round(params.responseFitMinimumTime*experiment.fps));
          if(length(ipt) > params.responseFitMaximumSlopes)
            [ipt, res] = findchangepts(currentTrace(valid), 'maxNumChanges', params.responseFitMaximumSlopes, 'Statistic' ,'linear', 'minDistance', round(params.responseFitMinimumTime*experiment.fps));
          end
%           done = false;
%           maxC = 0;
%           while(~done)
%             maxC = maxC+1;
%             [ipt, res] = findchangepts(currentTrace(valid), 'maxNumChanges', maxC, 'Statistic' ,'linear', 'minDistance', round(params.responseFitMinimumTime*experiment.fps));
%             %if(res < minTp || it > 4)
%             %if((length(resList) > 1 && resList(end)/resList(end-1) > maxRatio )|| maxC > 10)
%             %if((length(resList) > 1 && resList(end)/resList(end-1) > maxRatio && abs(resList(end) - resList(end-1)) > 0.1 )|| maxC > 10)
%             if(res < params.responseFitResidual || maxC >= params.responseFitMaximumSlopes)
%               done = true;
%             end
%           end
          ipt = valid(1)-1+[1; ipt; length(valid)];
        end
        if(~isempty(maxResponseTimeIdx))
            windowSize = params.decayWindowSize;
            windowSizeFrames = round(experiment.fps*windowSize);
            done = false;
            startFrame = maxResponseTimeIdx;
            curIt = 1;
            slopeChange = 0;
            cList = [];
            endReached = false;
            while(~done)
               currFrames = startFrame:(startFrame+windowSizeFrames);
               if(currFrames(end) >= length(t))
                   done = true;
                   endReached = true;
                   break;
               end
                f = fittype('poly1');
               [fitDecay, goefDecay] = fit(t(currFrames), currentTrace(currFrames), f);
               if(curIt == 1)
                   origFit = fitDecay;
               end
                c = coeffvalues(fitDecay);
                if(curIt > 1)
                    slopeChange = c(1)/oldC(1);
                end
                cList = [cList; c(1)];
                startFrame = currFrames(end)+1;
                curIt = curIt +1;
                if(curIt > 5 && ((abs(slopeChange) > 5 && c(1) < 0 && oldC(1) < 0) || (abs(slopeChange) > 5 && c(1) > 0 && oldC(1) < 0)))
                  done = true;
                end
                  oldC = c;
            end
            [~,bestSlope] = sort(cList);

            startFrame = maxResponseTimeIdx+windowSizeFrames*(bestSlope-1);
            currFrames = startFrame:(startFrame+windowSizeFrames);
            if(length(currFrames) > 2)
              f = fittype('poly1');
              [fitDecay, goefDecay] = fit(t(currFrames), currentTrace(currFrames), f);

              meanF = mean(currentTrace(maxResponseTimeIdx:min(currFrames)));
              x = (meanF-fitDecay.p2)/fitDecay.p1;
              %x = (fitDecay.p2-origFit.p2)/(origFit.p1-fitDecay.p1)
              [~, validFrame] = min(abs(x-t));
              decayTimeIdx = validFrame;
              decayTime = t(decayTimeIdx)-t(reactionTimeIdx);
              decay = currentTrace(decayTimeIdx);
            else
              decayTimeIdx = NaN;
              decayTime = NaN;
              decay = NaN;
            end
        end

        %%% Now the recovery time
        switch params.recoveryTimeThresholdType
          case 'relative'
            recoveryTimeThreshold = baseLine + protocolSign*params.recoveryTimeThreshold*std(currentTrace(firstBaseLineFrame:lastBaseLineFrame));
          case 'absolute'
            recoveryTimeThreshold = params.recoveryTimeThreshold;
        end
        if(~isempty(decayTimeIdx) && ~isnan(decayTimeIdx))
          if(protocolSign == 1)
            recoveryTimeIdx = decayTimeIdx - 1 + find(currentTrace(decayTimeIdx:validResponseFrames(end)) <= recoveryTimeThreshold, 1, 'first');
          else
            recoveryTimeIdx = decayTimeIdx - 1 + find(currentTrace(decayTimeIdx:validResponseFrames(end)) >= recoveryTimeThreshold, 1, 'first');
          end
          if(~isempty(recoveryTimeIdx) && ~isnan(recoveryTimeIdx))
            recoveryTime = t(recoveryTimeIdx)-params.startTime;
          else
            recoveryTimeIdx = [];
            recoveryTime = NaN;
          end
        else
          recoveryTimeIdx = [];
          recoveryTime = NaN;
        end
        if(~isempty(decayTimeIdx) && ~isempty(maxResponseTimeIdx) && ~isnan(decayTimeIdx) && ~isnan(maxResponseTimeIdx))
          responseDuration = t(decayTimeIdx)-t(maxResponseTimeIdx);
        else
          responseDuration = NaN;
        end

        %%% Now the fits
%         switch params.riseFitType
%           case 'none'
%             NriseCoeffs = 0;
%           case 'linear'
%             f = fittype('poly1');
%             NriseCoeffs = 2;
%           case 'single exponential'
%             f = fittype('exp1');
%             NriseCoeffs = 2;
%           case 'double exponential'
%             f = fittype('exp2');
%             NriseCoeffs = 4;
%         end
%         if(~strcmp(params.riseFitType, 'none') && ~isempty(reactionTimeIdx) && ~isempty(reactionTimeIdx) && ~isempty(maxResponseTimeIdx) && ~isempty(maxResponseTimeIdx) && length(reactionTimeIdx:maxResponseTimeIdx) > 5)
%           [fitRise, goefRise] = fit(t(reactionTimeIdx:maxResponseTimeIdx), currentTrace(reactionTimeIdx:maxResponseTimeIdx), f);
%         else
%           fitRise = [];
%           goefRise = [];
%         end
% 
%         switch params.decayFitType
%           case 'none'
%             NdecayCoeffs = 0;
%           case 'linear'
%             f = fittype('poly1');
%             NdecayCoeffs = 2;
%           case 'single exponential'
%             f = fittype('exp1');
%             NdecayCoeffs = 2;
%           case 'double exponential'
%             f = fittype('exp2');
%             NdecayCoeffs = 4;
%         end
%         if(~strcmp(params.riseFitType, 'none') && ~isempty(recoveryTimeIdx) && ~isempty(recoveryTimeIdx) && ~isempty(decayTimeIdx) && ~isempty(decayTimeIdx) && length(decayTimeIdx:recoveryTimeIdx) > 5)
%           [fitDecay, goefDecay] = fit(t(decayTimeIdx:recoveryTimeIdx), currentTrace(decayTimeIdx:recoveryTimeIdx), f);
%         else
%           fitDecay = [];
%           goefDecay = [];
%         end

        protocolData.baseLine(it) = baseLine;
        protocolData.baseLineFrame(it) = lastBaseLineFrame;
        protocolData.reactionTime(it) = reactionTime;
        if(~isempty(reactionTimeIdx))
          protocolData.reactionTimeIdx(it) = reactionTimeIdx;
        else
          protocolData.reactionTimeIdx(it) = NaN;
        end
        protocolData.maxResponse(it) = maxResponse;
        if(~isempty(maxResponseTimeIdx))
          protocolData.maxResponseTimeIdx(it) = maxResponseTimeIdx;
        else
          protocolData.maxResponseTimeIdx(it) = NaN;
        end
        protocolData.maxResponseTime(it) = maxResponseTime;
        if(~isempty(recoveryTimeIdx))
          protocolData.recoveryTimeIdx(it) = recoveryTimeIdx;
        else
          protocolData.recoveryTimeIdx(it) = NaN;
        end
        protocolData.recoveryTime(it) = recoveryTime;
        protocolData.recovered(it) = ~isempty(recoveryTimeIdx);
        if(~isempty(decayTimeIdx))
          protocolData.decayTimeIdx(it) = decayTimeIdx;
        else
          protocolData.decayTimeIdx(it) = NaN;
        end
        protocolData.decayTime(it) = decayTime;
        protocolData.decay(it) = decay;
        protocolData.responseDuration(it) = responseDuration;
        protocolData.protocolEndFrame(it) = endFrame;
        protocolData.protocolEndValue(it) = currentTrace(endFrame);
        protocolData.lastResponseFrame(it) = validResponseFrames(end);
        protocolData.lastResponseValue(it) = currentTrace(validResponseFrames(end));
        
        if(~isempty(ipt))
          protocolData.responseFitFrames{it} = ipt;
          protocolData.responseFitSegments(it) = length(ipt)-1;
          protocolData.responseFitSegmentsDuration{it} = zeros(length(ipt)-1, 1);
          protocolData.responseFitSegmentsFluorescenceIncrease{it} = zeros(length(ipt)-1, 1);
          protocolData.responseFitSegmentsSlope{it} = zeros(length(ipt)-1, 1);
          protocolData.responseFitModel{it} = cell(length(ipt)-1, 1);
          f = fittype('poly1');
          for itt = 2:length(ipt)
            currFrames = ipt(itt-1):ipt(itt);
            [fitCoefs, ~] = fit(t(currFrames), currentTrace(currFrames), f);
            protocolData.responseFitSegmentsDuration{it}(itt-1) = length(currFrames)/experiment.fps;
            protocolData.responseFitSegmentsFluorescenceIncrease{it}(itt-1) = protocolData.responseFitSegmentsDuration{it}(itt-1)*fitCoefs.p1;
            protocolData.responseFitSegmentsSlope{it}(itt-1) = fitCoefs.p1;
            protocolData.responseFitModel{it}{itt-1} = [fitCoefs.p1, fitCoefs.p2];
          end
          protocolData.responseFitSegmentsMaxFluorescenceIncrease(it) = max(protocolData.responseFitSegmentsFluorescenceIncrease{it});
          protocolData.responseFitSegmentsMaxSlope(it) = max(protocolData.responseFitSegmentsSlope{it});
        else
          protocolData.responseFitFrames{it} = [];
          protocolData.responseFitSegments(it) = 0;
          protocolData.responseFitSegmentsDuration{it} = [];
          protocolData.responseFitSegmentsFluorescenceIncrease{it} = [];
          protocolData.responseFitSegmentsSlope{it} = [];
          protocolData.responseFitSegmentsMaxFluorescenceIncrease(it) = NaN;
          protocolData.responseFitSegmentsMaxSlope(it) = NaN;
          protocolData.responseFitModel{it} = {};
        end

      catch ME
        logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
        protocolData.baseLine(it) = NaN;
        protocolData.baseLineFrame(it) = NaN;
        protocolData.reactionTime(it) = NaN;
        protocolData.reactionTimeIdx(it) = NaN;
        protocolData.maxResponse(it) = NaN;
        protocolData.maxResponseTimeIdx(it) = NaN;
        protocolData.maxResponseTime(it) = NaN;
        protocolData.recoveryTimeIdx(it) = NaN;
        protocolData.recoveryTime(it) = NaN;
        protocolData.recovered(it) = false;
        protocolData.decayTimeIdx(it) = NaN;
        protocolData.decayTime(it) = NaN;
        protocolData.decay(it) = NaN;
        protocolData.responseDuration(it) = NaN;
        protocolData.protocolEndFrame(it) = NaN;
        protocolData.protocolEndValue(it) = NaN;
        protocolData.lastResponseFrame(it) = NaN;
        protocolData.lastResponseValue(it) = NaN;
        
        protocolData.responseFitFrames{it} = [];
        protocolData.responseFitSegments(it) = 0;
        protocolData.responseFitSegmentsDuration{it} = [];
        protocolData.responseFitSegmentsFluorescenceIncrease{it} = [];
        protocolData.responseFitSegmentsSlope{it}= [];
        protocolData.responseFitSegmentsMaxFluorescenceIncrease(it) = NaN;
        protocolData.responseFitSegmentsMaxSlope(it) = NaN;
        protocolData.responseFitModel{it} = [];
        
%         protocolData{it}.fitRiseCoeffs = [];
%         protocolData{it}.fitRiseCoeffNames = [];
%         protocolData{it}.fitRiseRsquare = [];
%         protocolData{it}.fitRiseCurve = [];
% 
%         protocolData{it}.fitDecayCoeffs = [];
%         protocolData{it}.fitDecayCoeffNames = [];
%         protocolData{it}.fitDecayRsquare = [];
%         protocolData{it}.fitDecayCurve = [];
          
        
      end
    ncbar.update(it/size(currentTraces, 2));
  end
end

end