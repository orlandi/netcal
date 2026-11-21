function [exportData, featuresNames] = getKClFeatures(experiment, subpop, varargin)
  % 'ROI ID' or 'ROI INDEX'
  if(nargin >= 3)
    ROItype = varargin{1};
  else
    ROIType = 'ROI ID';
  end

  experiment = checkGroups(experiment);
  exportData = [];
  if(~isfield(experiment, 'KClProtocolData'))
    logMsg(sprintf('KCl analysis results not found in experiment %s', experiment.name), 'w');
    return;
  end
  
  try
    [members, ~, ~] = getExperimentGroupMembers(experiment, subpop);
    [field, idx] = getExperimentGroupCoordinates(experiment, subpop);
    protocolData = experiment.KClProtocolData.(field){idx};
  catch ME
    logMsg(sprintf('Something went wrong getting loading KCl data from %s', subpop), 'e');
    logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e'); %#ok<SPRINTFN>
    return;
  end
  
  labels = {'baseLine', 'reactionTime', 'maxResponse', 'maxResponseTime', 'decay', 'decayTime', 'responseDuration', 'recoveryTime', 'recovered', 'endValue', 'lastResponseValue'};
  if(~isempty(protocolData{1}.fitRiseCoeffNames))
    for it = 1:length(protocolData{1}.fitRiseCoeffNames)
      labels{end+1} = sprintf('Rise coeff: %s', protocolData{1}.fitRiseCoeffNames{it});
    end
    labels{end+1} = sprintf('Rise rsquare');
  end
  if(~isempty(protocolData{1}.fitDecayCoeffNames))
    for it = 1:length(protocolData{1}.fitDecayCoeffNames)
      labels{end+1} = sprintf('Decay coeff: %s', protocolData{1}.fitDecayCoeffNames{it});
    end
    labels{end+1} = sprintf('Decay rsquare');
  end
  labels{end+1} = ROItype;

  nLabels = length(labels);
  
  exportData = nan(length(members), nLabels);
  curData = 1;
  exportData(:, curData) = cellfun(@(x)x.baseLine, protocolData);
  curData = curData + 1;
  exportData(:, curData) = cellfun(@(x)x.reactionTime, protocolData);
  curData = curData + 1;
  exportData(:, curData) = cellfun(@(x)x.maxResponse, protocolData);
  curData = curData + 1;
  exportData(:, curData) = cellfun(@(x)x.maxResponseTime, protocolData);
  
  curData = curData + 1;
  exportData(:, curData) = cellfun(@(x)x.decay, protocolData);
  curData = curData + 1;
  exportData(:, curData) = cellfun(@(x)x.decayTime, protocolData);
  
  curData = curData + 1; % responseDuration
  exportData(:, curData) = cellfun(@(x)x.responseDuration, protocolData);
  
  curData = curData + 1;
  exportData(:, curData) = cellfun(@(x)x.recoveryTime, protocolData);
  
  curData = curData + 1; % Recovered
  exportData(:, curData) = cellfun(@(x)x.recovered, protocolData);
  
  curData = curData + 1;
  exportData(:, curData) = cellfun(@(x)x.protocolEndValue, protocolData);
  curData = curData + 1;
  exportData(:, curData) = cellfun(@(x)x.lastResponseValue, protocolData);
  if(~isempty(protocolData{members(1)}.fitRiseCoeffNames))
    for itt = 1:length(protocolData{members(1)}.fitRiseCoeffNames)
      curData = curData + 1;
      exportData(:, curData) = cellfun(@(x)x.fitRiseCoeffs(itt), protocolData);
    end
    curData = curData + 1;
    exportData(:, curData) = cellfun(@(x)x.fitRiseRsquare, protocolData);
  end
  if(~isempty(protocolData{members(1)}.fitDecayCoeffNames))
    for itt = 1:length(protocolData{members(1)}.fitDecayCoeffNames)
      curData = curData + 1;
      exportData(:, curData) = cellfun(@(x)x.fitDecayCoeffs(itt), protocolData);
    end
    curData = curData + 1;
    exportData(:, curData) = cellfun(@(x)x.fitDecayRsquare, protocolData);
  end
  % Now the ROI ID
  curData = curData + 1;
  switch ROItype
    case 'ROI ID'
      exportData(:, curData) = cellfun(@(x)x.ID, experiment.ROI(members));
    case 'ROI INDEX'
      exportData(:, curData) = members;
  end
  featuresNames = labels;
end