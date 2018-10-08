classdef spikeFeaturesOptions < baseOptions
% SPIKEFEATURESOPTIONS # Spike features selection options
%   Class containing the possible spike features and their parameters
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also getSpikeFeatures, baseOptions, optionsWindow

  properties
    % Group to perform function on:
    % - none: will use all traces
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};

    % Minimum Number of spikes within a burst (positive integer)
    minSpikes = 2;

    % Maximum time allowed between consecutive spikes in a burst (in sec) (positive double)
    burstMaxTime = 1;

    % Only extract features from spikes in the given time range (in sec) (2D vector of doubles)
    timeRange = [0 inf];

    % Feature: number of spikes (1) (true/false)
    fNumSpikes@logical = true;

    % Feature: firing rate (1b) (true/false)
    fFiringRate@logical = false;
    
    % Feature: average interspike/interevent interval (ISI) (2) (true/false)
    fAverageISI@logical = true;

    % Feature: standard deviation fo the interspike interval (3) (true/false)
    fStdISI@logical = true;

    % Shannon entropy of the spike train (in bits)
    fEntropy = true;
    
    % Disequilibrium of the spike train (Jenson-Shannon divergence)
    fDisequilibrium = true;
    
    % Statistical complexity (entropy times disequilibrium)
    fComplexity = true;
    
    % Fano factor of the ISI (unwindowed), i.e., variance to mean ratio (true/false)
    fFanoFactorISI = true;
    
    % Coefficient of variation of the ISI, i.e., std deviation to mean ratio (true/false)
    fCoefficientVariationISI = true;
    
    % Feature: number of bursts (4) (true/false)
    fBurstNum@logical = true;

    % Feature: bursting rate (4b) (true/false)
    fBurstingRate@logical = false;
    
    % Feature: mean interspike interval within a burst (5) (true/false)
    fMeanBurstISI@logical = true;

    % Feature: mean interburst interval (IBI) (6) (true/false)
    fMeanIBI@logical = true;

    % Feature: number of spikes inside a burst (7) (true/false)
    fBurstNumSpikes@logical = true;

    % Feature: burst length (time between first and last spike) (8) (true/false)
    fBurstLength@logical = true;

    % Feature: burst length from traces (time it takes the fluorescence signal to drop below the value it had at the beginning of the burst (9) (true/false)
    fBurstLengthFluorescence@logical = false;

    % Feature: Number of spikes in bursts (absolute)
    fNumSpikesInBursts@logical = true;
    
    % Feature: Number of spikes in bursts (ratio)
    fNumSpikesInBurstsRatio@logical = true;
    
    % Feature for Schmitt detection: maximum fluorescence amplitude inside the event
    fSchmittAmplitude@logical = false;

    % Feature for Schmitt detection: area below the event (positve defined)
    fSchmittArea@logical = false;

    % Feature for Schmitt detection: duration until the event falls below the second threshold
    fSchmittDuration@logical = false;
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.group = getExperimentGroupsNamesFull(experiment);
        catch ME
          logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        exp = load(experiment, '-mat', 'folder', 'name', 'traceGroups', 'traceGroupsNames');
        groups = getExperimentGroupsNamesFull(exp);
        if(~isempty(groups))
          obj.group = groups;
        end
        if(length(obj.group) == 1)
          obj.group{end+1} = '';
        end
      end
    end
  end
end
