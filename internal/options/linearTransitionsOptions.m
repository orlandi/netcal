classdef linearTransitionsOptions < baseOptions
% LINEARTRANSITIONSOPTIONS Options to generate the linear transitions plot
%   Class containing the configurable options for the linear transitions plot
%
%   Copyright (C) 2016, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also plotLinearTransitions, baseOptions, optionsWindow

  properties
    % Names of the populations
    populationsNames = {'neuron'; 'glia'; 'silent'};
    
    % Names for the before and after procedures
    beforeAfterNames = {'basal'; 'bicuculine'};

    % Main title for the figure
    title = 'WT';
    
    % Positions for the bars
    barPositions = [-1 1]*0.5;

    % Bar width
    barWidth = 0.1;

    % Gap between each population
    populationsGap = 20e-3;

    % Gap between bars and transitions lines
    barGap = 0.015;
    
    % Minimum size for each of the bars
    barMinSize = 0.04;
    
    % Gap between the bars and the populations names
    populationNamesGap = 0.02;
    
    % Gap between the bars and the transitions fractions
    transitionsNamesGap = 0.01;
    
    % Prefactor for the curvature of the transition lines
    sigmoidPrefactor = 0.75;

    % Draw black edges around the bars
    barsBlackEdges = false;
    
    % Draw black edges around the transition lines
    transitionsBlackEdges = false;
    
    % LINEAR/BAR/SQUARES ONLY: If we use same colors for before and after bars
    useSameColors = false;
    
    % To make the patches transparent (from 0 to 1)
    transparency = 0.75;
    
    % Type of numbers to show, percentage or absolute
    countType = {'relative', 'absolute'};
    
    % Colormap to use
    colormap = 'parula';
    
    % BAR ONLY: If the colord of the bars should change
    mergeColors = false;
    
    % BAR ONLY: gap between left and right bars
    leftRightGap = 0.25;
    
    % BAR ONLY: true to only show the left plot
    showOnlyHalf = false;
    
    % BAR ONLY: true to show errors (if multiple experiments)
    showErrorBars = false;
    
    % SQUARES ONLY: how many neurons represent a square (not working)
    neuronsPerSquare = 2;
    
    % SQUARES ONLY: maximum squares per column
    maxSquaresPerColumn = 21;
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment))
        try
          if(isSubField(experiment, 'traceGroupsNames.classifier'))
            obj.populationsNames = experiment.traceGroupsNames.classifier(:);
          end
        catch ME
            logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
        end
      end
    end
  end
end
