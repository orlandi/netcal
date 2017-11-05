function [hits, histEdges, histCenters] = integerLogBinning(data, varargin)

% Default parameters
params.normalize = 'full';
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
    %histEdges = 10.^linspace(log10(min(data)-0.5), log10(max(data)+0.5),Nbins+1);
    histEdges = 10.^linspace(log10(limits(1)-0.5), log10(limits(2)+0.5),Nbins+1);
end
histCenters = histEdges(1:end-1)+diff(histEdges)/2;
% Now, for bins that only cover 1 integer, position the center on the integer
ceE = ceil(histEdges);
flE = floor(histEdges);
toMove = find(flE(2:end) == ceE(1:end-1));
histCenters(toMove) = ceE(toMove);
%histCenters(toMove)
hits = histc(data, histEdges);
% Remove the last edge, since it will be empty
hits = hits(1:end-1);

% Divide by the number of ints inside the bin
switch params.normalize
    case 'full'
        norm = diff(floor(histEdges));
        hits = hits(:)./norm(:);
        hits(~norm) = NaN;
        hits = hits/nansum(hits);
        valid = find(~isnan(hits));
        hits = hits(valid);
        histCenters = histCenters(valid);
        nvalid = [valid(:); valid(end)+1];
        if(nvalid(end) > length(histEdges))
            nValid(end) = [];
        end
        histEdges = histEdges(nvalid);
    case 'hits'
        norm = diff(floor(histEdges));
        hits = hits(:)./norm(:);
        hits(~norm) = NaN;
        valid = find(~isnan(hits));
        hits = hits(valid);
        histCenters = histCenters(valid);
        nvalid = [valid(:); valid(end)+1];
        if(nvalid(end) > length(histEdges))
            nValid(end) = [];
        end
        histEdges = histEdges(nvalid);
    case 'max'
        norm = diff(floor(histEdges));
        hits = hits(:)./norm(:);
        hits(~norm) = NaN;
        valid = find(~isnan(hits));
        hits = hits(valid);
        hits = hits/hits(1);
        histCenters = histCenters(valid);
        nvalid = [valid(:); valid(end)+1];
        if(nvalid(end) > length(histEdges))
            nValid(end) = [];
        end
        histEdges = histEdges(nvalid);
    otherwise
end
    