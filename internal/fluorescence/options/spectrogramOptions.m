classdef spectrogramOptions < baseOptions
% SPECTROGRAMOPTIONS Options to plot the spectrogram
%   Class containing the options for the spectrogram
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also classifyWithExternalLearningData, baseOptions, optionsWindow

  properties
    % If true, will also show the confidence interval (only when multiple experiments are combined)
    showConfidenceInterval = true;
    
    % Subpopulation to use to compute the spectrogram (leave empty for doing it on every ROI)
    subpopulation = {'everything', ''};
  end
  methods
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.subpopulation = getExperimentGroupsNames(experiment);
        catch ME
            logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        exp = load(experiment, '-mat', 'folder', 'name', 'traceGroups', 'traceGroupsNames');
        pops = getExperimentGroupsNames(exp);
        if(~isempty(pops))
          obj.subpopulation = pops;
        end
      end
    end
  end
end
