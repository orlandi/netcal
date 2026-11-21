classdef circularTransitionsOptions < baseOptions
% CIRCULARTRANSITIONSOPTIONS Options to generate the circular transitions plot
%   Class containing the configurable options for the circular transitions plot
%
%   Copyright (C) 2016, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also plotCircularTransitions, baseOptions, optionsWindow

  properties
    % Names of the populations
    populationsNames = {'neuron'; 'glia'; 'silent'};
    
    % Names for the before and after procedures
    beforeAfterNames = {'basal'; 'bicuculine'};

    % Main title for the figure
    title = 'WT';
    
    % Inner radius for the populations
    innerRadius = 0.95;

    % Outer radius for the populations
    outerRadius = 1.05;

    % Gap between each population
    populationsGap = 10e-3;

    % Minimum size for each of the bars
    barMinSize = 0.04;
    
    % Radius where the transition lines start
    transitionRadius = 0.95-0.025;
    
    % Type of curvature for the transitions:
    % - tangent: transitions are tangent to the mother circle
    % - custom: custom curvature
    curvatureType = {'tangent', 'custom'};
    
    % Exponent for the transition lines curvature (only if custom)
    curvatureExponent = 0.4;

    % Multiplier for the transition lines curvature (custom). For (tangent)
    % it multiplies the position of the circle origin by this value)
    curvatureMultiplier = 1;
    
    % Radius where to place the populations names
    populationNamesPosition = 1.1;
    
    % Radius where to place the transition fractions numbers
    transitionFractionsTextPosition = 0.95-0.025-0.025;
    
    % Draw black edges around the bars
    barsBlackEdges = false;
    
    % Draw black edges around the transition lines
    transitionsBlackEdges = false;
    
    % To make the patches transparent (from 0 to 1)
    transparency = 0.75;
    
    % Type of numbers to show, percentage or absolute
    countType = {'relative', 'absolute'};
    
    % Colormap to use
    colormap = 'parula';
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
