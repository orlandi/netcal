classdef peelingOptions < baseOptions
% PEELINGOPTIONS Peeling options
%   Class containing the parameters to perform spike inference with the peeling algorithm
%
%   Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also Peeling, baseOptions, optionsWindow

  properties
    % ROI index used to check peeling results with a single trace (only used in training mode)
    trainingROI = 1;
    
    % Time constant (in seconds) associated to the decay of the fluorescence signal
    tau = 3;

    % Characteristic fluorescence increase due to a spike
    amplitude = 0.9;
    
    % Second ampltiude (DO NOT CHANGE)
    secondAmplitude = 0;
    
    % Second tau (DO NOT CHANGE)
    secondTau = 1;
    
    % True to also store the model trace
    storeModelTrace = false;
  end
end
