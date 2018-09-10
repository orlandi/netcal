function experiment = computeFCA(experiment, varargin)
% COMPUTEFCA base functional clustering analysis
%
% USAGE:
%   experiment = computeFCA(experiment, options)
%
% INPUT arguments:
%   experiment - structure containing an experiment
%
% INPUT optional arguments ('key' followed by its value):
%   gui - handle of the external GUI
%
% OUTPUT arguments:
%   experiment - structure containing an experiment
%
% EXAMPLE:
%   experiment = computeFCA(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also preprocessExperimentOptions

% Define additional optional argument pairs
params.verbose = true;

% Parse them
params = parse_pv_pairs(params, varargin);

if(params.verbose)
  logMsgHeader('Computing FCA', 'start');
end

%% FCA on fluorescence traces


traces = experiment.traces;


%% Parameters

% Number of surrogate signals to generate
surrogateN = 0;

% Number of chunks for the surrogates (chuck length ~ T/surrogateChunks)
surrogateChunks = 5;

% Confidence level threshold (significance)
thresholdCL = 0.99;

% Way to calculate similarity between signals
similarityMeasure = 'correlation';

% Way to merge signals together
jointFunction = 'average';


%% Definitions
%Ntraces = 100; % To speed up
% Number of traces
Ntraces = size(traces, 2);

% Create the cluster list
clusterList = 1:Ntraces;

% Create the cluster members information
clusterMembers = cell(Ntraces, 1);
for i = 1:length(clusterMembers)
    clusterMembers{i} = i;
end

% List of merge operations performed [step, [clusters joined]]
mergeHistory = [];
Z = [];

% Compute correlations between surrogates

clusterNeedsUpdating = true(Ntraces);
significanceDistance = zeros(Ntraces);
clusterTraces = traces;
currentMergeIteration = 1;
done = false;

%% Full loop
tic
while(~done)
    %%% -------------------------------------------------------------------
    %%% Main loop to compute significances
    %%% -------------------------------------------------------------------
    
    for i = 1:Ntraces
        if(~any(clusterNeedsUpdating(i,:)))
            continue;
        end
        if(any(isnan(clusterTraces(:, i))))
            continue;
        end
        surrogateData_i = generateSurrogates(clusterTraces(:, i), surrogateN, surrogateChunks);

        for j = (i+1):Ntraces
            if(~clusterNeedsUpdating(i,j))
                continue;
            end
            if(any(isnan(clusterTraces(:, j))))
                continue;
            end
            surrogateData_j = generateSurrogates(clusterTraces(:, j), surrogateN, surrogateChunks);

            % Calculate correlation coefficient between the original time series
            R = corrcoef(clusterTraces(:,i), clusterTraces(:,j));
            dataCoef = R(1,2);

            % Now for the surrogates
            surrogateCoefs = computeSurrogatesCoefs(surrogateData_i, surrogateData_j);
            if(isempty(surrogateCoefs))
              significanceDistance(i,j) = dataCoef;
            else
              % Now check significance level
              significanceLevel = prctile(surrogateCoefs, thresholdCL*100);
              significanceBase =  prctile(surrogateCoefs, 50);
              significanceDistance(i,j) = (dataCoef - significanceBase)/(significanceLevel-significanceBase);
            end
            % This cluster was done
            clusterNeedsUpdating(i,j) = false;
        end
        %[i j significanceDistance(i,j)]
        %[i j]
    end
    
    %%% -------------------------------------------------------------------
    %%% Now we need to obtain maximum significance and merge
    %%% -------------------------------------------------------------------
    % If there is no more significance, we are done
    [maxSignificance, maxSignificanceIdx] = max(significanceDistance(:));
    if(maxSignificance < 0)
        done = true;
        fprintf('Done!\n');
        break;
    end
    % Get the clusters with the maximum significance
    [cluster_i, cluster_j] = ind2sub(size(significanceDistance), maxSignificanceIdx);
    fprintf('Found maximum significance of %.3f between clusters %d and %d . Merging\n', maxSignificance, clusterList(cluster_i), clusterList(cluster_j));
    % And merge them
    newCluster = mean([traces(:,cluster_i), traces(:,cluster_j)],2);
    % Use the slot of cluster i and remove data from j
    clusterTraces(:, cluster_i) = newCluster;
    clusterTraces(:, cluster_j) = NaN;
    % Cluster i will need updating
    clusterNeedsUpdating(cluster_i, :) = true;
    clusterNeedsUpdating(:, cluster_i) = true;
    % Reset the significances (just in case)
    significanceDistance(cluster_i, :) = -inf;
    significanceDistance(:, cluster_i) = -inf;
    significanceDistance(cluster_j, :) = -inf;
    significanceDistance(:, cluster_j) = -inf;
    % Also update the cluster index
    newClusterIdx = max(clusterList) + 1;
    
    clusterMembers{newClusterIdx} = sort([clusterMembers{clusterList(cluster_i)}, clusterMembers{clusterList(cluster_j)}]);
    clusterMembers{clusterList(cluster_i)} = [];
    clusterMembers{clusterList(cluster_j)} = [];
    
    mergeHistory = [mergeHistory; currentMergeIteration clusterList(cluster_i) clusterList(cluster_j) newClusterIdx];
    Z = [Z; clusterList(cluster_i) clusterList(cluster_j) maxSignificance];
    currentMergeIteration = currentMergeIteration + 1;
    clusterList(cluster_i) = newClusterIdx;
    clusterList(cluster_j) = NaN;
    if(currentMergeIteration == Ntraces)
        done = true;
        fprintf('Done!\n');
    end
end
toc
% Only problem with the current code is that partial clusters are lost
% Also probably the algorithm is not invariant to the orginal trace orders
experiment.FCA.mergeHistory = mergeHistory;
experiment.FCA.Z = Z;

% First ordering approach
sortedZ = experiment.FCA.Z;
sortedZ(:, [1,2]) = sort(experiment.FCA.Z(:, [1,2]),2);
sortedZ = sortedZ(:, [1,2])';
sortedZ = sortedZ(:);
sortedZinvalid = find(sortedZ > size(data.experiment.traces,2));
sortedZ(sortedZinvalid) = [];
experiment.FCA.similarityOrder = sortedZ;

if(params.verbose)
  logMsgHeader('Done!', 'finish');
end
