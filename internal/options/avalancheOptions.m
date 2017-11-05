classdef avalancheOptions < baseOptions & avalanchePlotsOptions
% AVALANCHEOPTIONS options for avalanche analysis
%   Class containing the parameters for avalanche analysis
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also avalanchePlotsOptions, baseOptions, optionsWindow

  properties
    % To override the default binSize (in sec) (by default, it's the inverse of the fps)
    binSize = [];
    
    % If we also compute the branching ratio
    computeBranchingRatio = true;

    % If we also plot the distributions
    plotDistributions = true;
  end
  methods
    function t = avalancheOptions(varargin)
      t@baseOptions(varargin{:});
      t@avalanchePlotsOptions(varargin{:});
    end
  end
end
