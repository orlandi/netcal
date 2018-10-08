function [hits, histEdges, histCenters] = integerLogBinning(data, varargin)

% Default parameters
params.normalize = true;
params.removeEmptyBins = true;
params.bins = 100;
params.limits = [];
params = parse_pv_pairs(params,varargin); 

Nbins = params.bins;
limits = params.limits;

% First check. All Data has to be integers
invalidData = mod(data,1)~=0;
if(any(invalidData))
    disp('Warning. Data has no integer values. Rounding with round');
    data = round(data);
end
% Second check. All Data has to be positive
invalidData = (data <= 0);
if(any(invalidData))
    disp('Warning. Data contains non positive values. Removing them from the set.');
    data = data(~invalidData);
end
% Define the histogram edges
if(isempty(limits))
    histEdges = 10.^linspace(log10(0.5),log10(max(data)+0.5),Nbins+1);
else
    histEdges = 10.^linspace(log10(min(data)-0.5), log10(max(data)+0.5),Nbins+1);
end
histCenters = histEdges(1:end-1)+diff(histEdges);


hits = histc(data, histEdges);
% Remove the last edge, since it will be empty
hits = hits(1:end-1);

% Divide by the number of ints inside the bin
if(params.normalize)
    norm = diff(floor(histEdges));
    hits = hits./norm(:);
    hits(~norm) = NaN;
    % Now normalize so that the area is one
    valid = find(~isnan(hits));
    dx = floor(histEdges(valid+1))-floor(histEdges(valid));
    a = sum(dx.*hits(valid)');
    hits = hits/a;
    % Now, only return non nan values
    valid = find(~isnan(hits));
    histCenters(valid) = round(histCenters(valid));
    histCenters = histCenters(valid);
    hits = hits(valid);
    histEdges = floor(unique([histEdges(valid),histEdges(valid+1)]));
end
    