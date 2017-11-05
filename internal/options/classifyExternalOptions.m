classdef classifyExternalOptions < baseOptions
% CLASSIFYEXTERNALOPTIONS Classify external options
%   Class containing the options for using an external classifier
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also classifyWithExternalLearningData, baseOptions, optionsWindow

  properties
    % External file to get the learning samples
    externalFile = [pwd 'test.dat'];
    %externalFile = pwd;
    
    % Names for each of the groups
    groupNames = {'neuron';'glia';'noise'};

    % Type of classifier (for now just AdaBoostM2 and RobustBoost for 2 groups)
    trainer = {'AdaBoostM2', 'RobustBoost'};

    % Number of trees to generate for the classifier
    numberTrees = 200;
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.externalFile = [experiment.folder filesep 'data' filesep experiment.name '_learningData.dat'];
        catch ME
            logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
        end
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        %exp = load(experiment, '-mat', 'folder', 'name', 'traceGroupsNames');
        %exp
      end
    end
  end
end
