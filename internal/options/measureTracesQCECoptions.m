classdef measureTracesQCECoptions < baseOptions
% MEASURETRACESQCECOPTIONS Options for QCEC. See DOI: 10.1103/PhysRevE.95.062106
%   Class containing the options for QCEC
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also measureTracesQCEC

  properties
    % Embedding dimension of the probability distribution. The associated PDF dimensionality is the number of ordered paratitions within the embedding dimension, and goes as its factorial. So do not use values larger than 7
    embeddingDimension = 3;

    % List (as in the logspace instruction) of q values to sample. First and second entry are the minimum and maximum exponents respectively (base 10). Third entry is the number of values to sample within the interval
    qList = [-4 2 300];
    
    % If true, will plot the stacked q-complexity-entropy curves
    plotQCEC@logical = true;
    
    % Data to use
    tracesType = {'smoothed', 'raw', 'spikes'};
  end
end
