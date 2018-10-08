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
  catch ME
    logMsg(sprintf('Something was wrong getting loading KCl data from %s', subpop), 'e');
    logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
    return;
  end
  
  labels = {'baseLine', 'reactionTime', 'maxResponse', 'maxResponseTime', 'decay', 'decayTime', 'responseDuration', 'recoveryTime', 'recovered', 'endValue', 'lastResponseValue'};
  if(~isempty(experiment.KClProtocolData{members(1)}.fitRiseCoeffNames))
    for it = 1:length(experiment.KClProtocolData{members(1)}.fitRiseCoeffNames)
      labels{end+1} = sprintf('Rise coeff: %s', experiment.KClProtocolData{members(1)}.fitRiseCoeffNames{it});
    end
    labels{end+1} = sprintf('Rise rsquare');
  end
  if(~isempty(experiment.KClProtocolData{members(1)}.fitDecayCoeffNames))
    for it = 1:length(experiment.KClProtocolData{members(1)}.fitDecayCoeffNames)
      labels{end+1} = sprintf('Decay coeff: %s', experiment.KClProtocolData{members(1)}.fitDecayCoeffNames{it});
    end
    labels{end+1} = sprintf('Decay rsquare');
  end
  labels{end+1} = ROItype;

  nLabels = length(labels);
  
  exportData = nan(length(members), nLabels);
  curData = 1;
  exportData(:, curData) = cellfun(@(x)x.baseLine, experiment.KClProtocolData(members));
  curData = curData + 1;
  exportData(:, curData) = cellfun(@(x)x.reactionTime, experiment.KClProtocolData(members));
  curData = curData + 1;
  exportData(:, curData) = cellfun(@(x)x.maxResponse, experiment.KClProtocolData(members));
  curData = curData + 1;
  exportData(:, curData) = cellfun(@(x)x.maxResponseTime, experiment.KClProtocolData(members));
  
  curData = curData + 1;
  exportData(:, curData) = cellfun(@(x)x.decay, experiment.KClProtocolData(members));
  curData = curData + 1;
  exportData(:, curData) = cellfun(@(x)x.decayTime, experiment.KClProtocolData(members));
  
  curData = curData + 1; % responseDuration
  exportData(:, curData) = cellfun(@(x)x.responseDuration, experiment.KClProtocolData(members));
  
  curData = curData + 1;
  exportData(:, curData) = cellfun(@(x)x.recoveryTime, experiment.KClProtocolData(members));
  
  curData = curData + 1; % Recovered
  exportData(:, curData) = cellfun(@(x)x.recovered, experiment.KClProtocolData(members));
  
  curData = curData + 1;
  exportData(:, curData) = cellfun(@(x)x.protocolEndValue, experiment.KClProtocolData(members));
  curData = curData + 1;
  exportData(:, curData) = cellfun(@(x)x.lastResponseValue, experiment.KClProtocolData(members));
  if(~isempty(experiment.KClProtocolData{members(1)}.fitRiseCoeffNames))
    for itt = 1:length(experiment.KClProtocolData{members(1)}.fitRiseCoeffNames)
      curData = curData + 1;
      exportData(:, curData) = cellfun(@(x)x.fitRiseCoeffs(itt), experiment.KClProtocolData(members));
    end
    curData = curData + 1;
    exportData(:, curData) = cellfun(@(x)x.fitRiseRsquare, experiment.KClProtocolData(members));
  end
  if(~isempty(experiment.KClProtocolData{members(1)}.fitDecayCoeffNames))
    for itt = 1:length(experiment.KClProtocolData{members(1)}.fitDecayCoeffNames)
      curData = curData + 1;
      exportData(:, curData) = cellfun(@(x)x.fitDecayCoeffs(itt), experiment.KClProtocolData(members));
    end
    curData = curData + 1;
    exportData(:, curData) = cellfun(@(x)x.fitDecayRsquare, experiment.KClProtocolData(members));
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