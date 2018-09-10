classdef predefinedPatternsOptions < baseOptions
% PREDEFINEDPATTERNOPTIONS Predefined patterns options
%   Options to define a set of predefined patterns for event-based trace
%   classification. You can choose between exponential gaussian and lognormal
%   profiles with different parameters
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also generatePredefinedPatterns

  properties
    % If true, will also plot the generated patterns
    showPatterns = true;
    
    % True to detect patterns based on exponential functions ~exp(-t/tau)
    exponentialPattern@logical = true;
    
    % List of tau values (time constant, in seconds) for the exponential-based pattern
    % matching. Use three numbers with the same syntax as the linspace
    % function, i.e., first value is the first tau to use; second value is
    % the last tau; third value is the number of equidistant values to choose between the
    % first and the last, e.g., [1,3,5] will result in using tau values 1,
    % 1.5, 2, 2.5, 3.
    exponentialTauList = [1, 5, 10];
    
    % Correlation threshold for the pattern matching (between 0 and 1). A
    % threshold of 1 will only find perfect matches, and 0 will match
    % anything. Keep it above 0.8 for accurate results.
    exponentialCorrelationThreshold = 0.9;
    
    % Cutof for the exponential function (in multiples of tau). A cutoff =
    % 2 will try to match exponential functions with a length of 2*tau
    exponentialCutoff = 2;
    
    % True to detect patterns based on gaussian functions ~exp(-(t-t0)^2/sigma^2)
    gaussianPattern@logical = true;
    
    % List of sigma values (standard deviation, in seconds) for the gaussian-based pattern
    % matching. Use three numbers with the same syntax as the linspace
    % function, i.e., first value is the first sigma to use; second value is
    % the last sigma; third value is the number of equidistant values to choose between the
    % first and the last, e.g., [1,3,5] will result in using sigma values 1,
    % 1.5, 2, 2.5, 3.
    gaussianSigmaList = [5, 50, 10];
    
    % Correlation threshold for the pattern matching (between 0 and 1). A
    % threshold of 1 will only find perfect matches, and 0 will match
    % anything. Keep it above 0.8 for accurate results.
    gaussianCorrelationThreshold = 0.8;
    
    % Cutof for the gaussian function (in multiples of sigma). A cutoff =
    % 2 will try to match gaussian functions with a length of +/-2*sigma
    gaussianCutoff = 2;
    
    % True to detect patterns based on lognormal functions ~exp(mu+sigma*t)
    lognormalPattern@logical = true;
    
    % List of sigma values (in Hz) for the log-normal-based pattern
    % matching. Use three numbers with the same syntax as the linspace
    % function, i.e., first value is the first sigma to use; second value is
    % the last sigma; third value is the number of equidistant values to choose between the
    % first and the last, e.g., [1,3,5] will result in using sigma values 1,
    % 1.5, 2, 2.5, 3.
    lognormalSigmaList = [0.1, 2, 5];
    
    % List of mode values (in seconds, the mode is the position of the maximum) for the log-normal-based pattern
    % matching. Use three numbers with the same syntax as the linspace
    % function, i.e., first value is the first mode to use; second value is
    % the last mode; third value is the number of equidistant values to choose between the
    % first and the last, e.g., [1,3,5] will result in using mode values 1,
    % 1.5, 2, 2.5, 3.
    lognormalModeList = [0.5, 5, 5];
    
    % Correlation threshold for the pattern matching (between 0 and 1). A
    % threshold of 1 will only find perfect matches, and 0 will match
    % anything. Keep it above 0.8 for accurate results.
    lognormalCorrelationThreshold = 0.8;
    
    % Cutof for the log-normal function (in relative value). A cutoff =
    % 0.05 will try to match log-normal functions until their value decays
    % below 5% of its maximum
    lognormalCutoff = 0.05;
  end
end
