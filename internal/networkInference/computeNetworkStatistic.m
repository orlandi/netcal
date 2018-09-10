function data = computeNetworkStatistic(RS, stat, nSurrogates)
% COMPUTENETWORKSTATISTIC Computes a single network statistic
% Most of them come from the BCT toolbox
%
% USAGE:
%    data = computeNetworkStatistic(RS, varargin)
%
% INPUT arguments:
%    RS - adjacency matrix
%    stat - statistic to compute
%    nSurrogates - number of surrogates to use (for functions that need
%    them - 100 by default
%
% OUTPUT arguments:
%    data - list of scores for each node
%
% EXAMPLE:
%    data = computeNetworkStatistic(RS)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

if(nargin < 3)
  nSurrogates = 100;
end

switch stat
  case 'degree'
    [~, ~, data] = degrees_dir(RS);
  case 'output degree'
    [~, data, ~] = degrees_dir(RS);
  case 'input degree'
    [data, ~, ~] = degrees_dir(RS);
  case 'clustering coefficient'
    [data, ~, ~, ~, ~, ~, ~] = clustering_coef_bd_full(RS);
  case 'total num connections'
    data = sum(RS(:));
  case 'cc feedback'
    [~, data, ~, ~, ~, ~, ~] = clustering_coef_bd_full(RS);
  case 'cc feedforward'
    [~, ~, ~, ~, ~, data, ~] = clustering_coef_bd_full(RS);
  case 'cc middleman'
    [~, ~, data, ~, ~, ~, ~] = clustering_coef_bd_full(RS);
  case 'cc in'
    [~, ~, ~, data, ~, ~, ~] = clustering_coef_bd_full(RS);
  case 'cc out'
    [~, ~, ~, ~, data, ~, ~] = clustering_coef_bd_full(RS);
  case 'total feedback triangles'
    data = nansum(diag(RS^3));
  case 'total feedforward triangles'
    data = nansum(diag((RS+RS')^3)/2)-sum(diag(RS^3));
  case  'transitivity'
    data = transitivity_bd(RS);
  case 'assortativity out-in'
    data = assortativity_bin(RS, 1);
  case 'assortativity in-out'
    data = assortativity_bin(RS, 2);
  case 'assortativity out-out'
    data = assortativity_bin(RS, 3);
  case 'assortativity in-in'
    data = assortativity_bin(RS, 4);
  case 'global efficiency'
    data = efficiency_bin(RS, 0);
  case 'local efficiency'
    data = efficiency_bin(RS, 1);
  case 'rich club max coeff'
    [data, ~, ~] = rich_club_bd(RS);
  case 'rich club top20 coeff'
    [data, ~, ~] = rich_club_bd(RS);
    data = data(ceil(0.8*length(data)));
  case 'rich club coeff corrected'
    [cidx,comp_sizes] = get_components(RS);
    [~, idx]= max(comp_sizes);
    valid = find(cidx == idx);
    RS = RS(valid, valid);
    % Now the surrogates
    % Let's comapre with a RG 
    [richOrig, ~, ~] = rich_club_bd(RS);
    richSurr = zeros(nSurrogates, length(richOrig));
    for it3 = 1:nSurrogates
      [newRS, flag] = makerandCIJdegreesfixed(sum(RS),sum(RS, 2));
      [cidx,comp_sizes] = get_components(newRS);
      [~, idx]= max(comp_sizes);
      valid = find(cidx == idx);
      newRS = newRS(valid, valid);
      [richSurr(it3, :), ~, ~] = rich_club_bd(newRS);
    end
    data = max(richOrig./mean(richSurr));
  case 'coreness'
    data = double(core_periphery_dir(RS));
  case 'small world index'
    % First get the biggest connected component
    [cidx,comp_sizes] = get_components(RS);
    [~, idx]= max(comp_sizes);
    valid = find(cidx == idx);
    RS = RS(valid, valid);
    RS = double(~~(RS+RS')); % Let's simmetrize
    % Now the rest
    [cc, ~, ~, ~, ~, ~, ~] = clustering_coef_bd_full(RS);
    cc = nanmean(cc);
    D = distance_bin(RS);
    [cp,~,~,~,~] = charpath(D);
    % Now the surrogates
    % Let's comapre with a RG 
    ccSurr = zeros(nSurrogates, 1);
    cpSurr = zeros(nSurrogates, 1);
    for it3 = 1:nSurrogates
      [newRS, flag] = makerandCIJdegreesfixed(sum(RS),sum(RS, 2));
      [cidx,comp_sizes] = get_components(newRS);
      [~, idx]= max(comp_sizes);
      valid = find(cidx == idx);
      newRS = newRS(valid, valid);
      [tmp, ~, ~, ~, ~, ~, ~] = clustering_coef_bd_full(newRS);
      ccSurr(it3) = nanmean(tmp);
      D = distance_bin(newRS);
      [tmp,~,~,~,~] = charpath(D);
      cpSurr(it3) = tmp;
    end
    %[cc mean(ccSurr) cp mean(cpSurr) cc/mean(ccSurr) cp/mean(cpSurr) cc/mean(ccSurr)/(cp/mean(cpSurr))]
    data = cc/nanmean(ccSurr)/(cp/nanmean(cpSurr));
    if(isinf(data))
      data = NaN;
    end
  case 'char path length'
    [cidx,comp_sizes] = get_components(RS);
    [~, idx]= max(comp_sizes);
    valid = find(cidx == idx);
    RS = RS(valid, valid);
    D = distance_bin(RS+RS');
    [data,~,~,~,~] = charpath(D);
  case 'radius'
    [cidx,comp_sizes] = get_components(RS);
    [~, idx]= max(comp_sizes);
    valid = find(cidx == idx);
    RS = RS(valid, valid);
    D = distance_bin(RS+RS');
    [~,~,~,data,~] = charpath(D);
  case 'diameter'
    [cidx,comp_sizes] = get_components(RS);
    [~, idx]= max(comp_sizes);
    valid = find(cidx == idx);
    RS = RS(valid, valid);
    D = distance_bin(RS+RS');
    [~,~,~,~,data] = charpath(D);
  case 'eccentricity'
    D = distance_bin(RS+RS');
    [~,~,data,~,~] = charpath(D);
  case 'num connected comp'
    [~,comp_sizes] = get_components(RS);
    valid = comp_sizes > 1;
    data = length(comp_sizes(valid));
  case 'avg comp size'
    [~,comp_sizes] = get_components(RS);
    valid = comp_sizes > 1;
    data = mean(comp_sizes(valid));
  case 'largest connected comp'
    [~,comp_sizes] = get_components(RS);
    data = max(comp_sizes);
  case 'louvain num communities'
    [M,Q]=community_louvain(RS);
    [a,b] = hist(M, 1:max(M));
    valid = find(a > 1);
    data = length(valid);
  case 'louvain avg community size'
    [M,Q]=community_louvain(RS);
    [a,b] = hist(M, 1:max(M));
    valid = find(a > 1);
    data = mean(a(valid));
  case 'louvain community statistic'
    [M,Q]=community_louvain(RS);
    data = Q;
  case 'louvain largest community'
    [M,Q]=community_louvain(RS);
    [a,b] = hist(M, 1:max(M));
    data = max(a);
  case 'louvain intercommunity inout assortativity'
    [M,Q]=community_louvain(RS, 1);
    [a,b] = hist(M, 1:max(M));
    valid = find(a > 1);
    curIt = 1;
    Mr = sortrows([a' b'],'descend');
    newIdx = [];
    for itt = 1:size(Mr, 1)
      valid = find(M == Mr(itt,2));
      newIdx = [newIdx; valid(:)];
      if(length(valid) > 1)
        curIt = curIt+1;
        RS(valid, valid) = RS(valid, valid)*curIt;
      end
    end
    %[~, idx] = sort(a(M),'descend');
    %RS(RS == 0) = NaN;
    % Reorder the nodes
    RS = RS(newIdx, newIdx);
    % Remove empty neurons
    valid = find(nansum(RS) + nansum(RS') ~= 0);
    RS = RS(valid, valid);
    % Now compute it on the links of weight 1 (the intermodules ones)
    [id,od] = degrees_dir(~~RS); % Binarized degrees
    [i,j] = find(RS == 1);
    K = length(i);
    flag = 1;
    switch flag
        case 1
            degi = od(i);
            degj = id(j);
        case 2
            degi = id(i);
            degj = od(j);
        case 3
            degi = od(i);
            degj = od(j);
        case 4
            degi = id(i);
            degj = id(j);
    end
    % compute assortativity
    data = ( sum(degi.*degj)/K - (sum(0.5*(degi+degj))/K)^2 ) / ...
        ( sum(0.5*(degi.^2+degj.^2))/K - (sum(0.5*(degi+degj))/K)^2 );
  case 'louvain intercommunity degree'
    [M,Q]=community_louvain(RS, 1);
    [a,b] = hist(M, 1:max(M));
    valid = find(a > 1);
    curIt = 1;
    Mr = sortrows([a' b'],'descend');
    newIdx = [];
    for itt = 1:size(Mr, 1)
      valid = find(M == Mr(itt,2));
      newIdx = [newIdx; valid(:)];
      if(length(valid) > 1)
        curIt = curIt+1;
        RS(valid, valid) = RS(valid, valid)*curIt;
      end
    end
    %[~, idx] = sort(a(M),'descend');
    %RS(RS == 0) = NaN;
    % Reorder the nodes
    RS = RS(newIdx, newIdx);
    % Remove empty neurons
    valid = find(nansum(RS) + nansum(RS') ~= 0);
    RS = RS(valid, valid);
    % Now compute it on the links of weight 1 (the intermodules ones)
    data = sum(sum(RS == 1))/length(RS);

  case 'louvain provincial hubs'
    [M,Q]=community_louvain(RS, 1);
    [a,b] = hist(M, 1:max(M));
    valid = find(a > 1);
    curIt = 1;
    Mr = sortrows([a' b'],'descend');
    newIdx = [];
    for itt = 1:size(Mr, 1)
      valid = find(M == Mr(itt,2));
      newIdx = [newIdx; valid(:)];
      if(length(valid) > 1)
        curIt = curIt+1;
        RS(valid, valid) = RS(valid, valid)*curIt;
      end
    end
    %[~, idx] = sort(a(M),'descend');
    %RS(RS == 0) = NaN;
    % Reorder the nodes
    RS = RS(newIdx, newIdx);
    newM = M(newIdx);
    % Remove empty neurons
    valid = find(nansum(RS) + nansum(RS') ~= 0);
    RS = RS(valid, valid);
    newM = newM(valid);
    P = participation_coef(RS, newM,0); % 0 flag for undirected
    targetNodes = find(sum(RS+RS') > mean(sum(RS+RS'))+std(sum(RS+RS')));
    data = sum(P(targetNodes) <= 0.3);
  case 'louvain connector hubs'
    [M,Q]=community_louvain(RS, 1);
    [a,b] = hist(M, 1:max(M));
    valid = find(a > 1);
    curIt = 1;
    Mr = sortrows([a' b'],'descend');
    newIdx = [];
    for itt = 1:size(Mr, 1)
      valid = find(M == Mr(itt,2));
      newIdx = [newIdx; valid(:)];
      if(length(valid) > 1)
        curIt = curIt+1;
        RS(valid, valid) = RS(valid, valid)*curIt;
      end
    end
    %[~, idx] = sort(a(M),'descend');
    %RS(RS == 0) = NaN;
    % Reorder the nodes
    RS = RS(newIdx, newIdx);
    newM = M(newIdx);
    % Remove empty neurons
    valid = find(nansum(RS) + nansum(RS') ~= 0);
    RS = RS(valid, valid);
    newM = newM(valid);
    P = participation_coef(RS, newM,0); % 0 flag for undirected
    targetNodes = find(sum(RS+RS') > mean(sum(RS+RS'))+std(sum(RS+RS')));
    data = sum(P(targetNodes) > 0.3);
  case 'modularity num communities'
    [cidx,comp_sizes] = get_components(RS);
    [~, idx]= max(comp_sizes);
    valid = find(cidx == idx);
    RS = RS(valid, valid);
    [M,Q]=modularity_dir(RS);
    [a,b] = hist(M, 1:max(M));
    valid = find(a > 1);
    data = length(valid);
  case 'modularity avg community size'
    [cidx,comp_sizes] = get_components(RS);
    [~, idx]= max(comp_sizes);
    valid = find(cidx == idx);
    RS = RS(valid, valid);
    [M,Q]=modularity_dir(RS);
    [a,b] = hist(M, 1:max(M));
    valid = find(a > 1);
    data = mean(a(valid));
  case 'modularity largest community'
    [cidx,comp_sizes] = get_components(RS);
    [~, idx]= max(comp_sizes);
    valid = find(cidx == idx);
    RS = RS(valid, valid);
    [M,Q]=modularity_dir(RS);
    [a,b] = hist(M, 1:max(M));
    data = max(a);
  case 'modularity statistic'
    [cidx,comp_sizes] = get_components(RS);
    [~, idx]= max(comp_sizes);
    valid = find(cidx == idx);
    RS = RS(valid, valid);
    [M,Q]=modularity_dir(RS);
    data = Q;
  case 'correlation num clusters'
    warning('off','stats:pdist:ConstantPoints');
    symRS = 0.5*(RS+RS');
    distmat = pdist(symRS, 'correlation');
    Z = linkage(distmat);
    T = cluster(Z, 'Cutoff', 0.7, 'Criterion', 'distance');
    [a,b] = hist(T, 1:max(T));
    valid = find(a > 1);
    data = length(b(valid));
    warning('on','stats:pdist:ConstantPoints');
  case 'correlation avg cluster size'
    warning('off','stats:pdist:ConstantPoints');
    symRS = 0.5*(RS+RS');
    distmat = pdist(symRS, 'correlation');
    Z = linkage(distmat);
    T = cluster(Z, 'Cutoff', 0.7, 'Criterion', 'distance');
    [a,b] = hist(T, 1:max(T));
    valid = find(a > 1);
    data = mean(a(valid));
    warning('on','stats:pdist:ConstantPoints');
  case 'correlation largest cluster'
    warning('off','stats:pdist:ConstantPoints');
    symRS = 0.5*(RS+RS');
    distmat = pdist(symRS, 'correlation');
    Z = linkage(distmat);
    T = cluster(Z, 'Cutoff', 0.7, 'Criterion', 'distance');
    [a,b] = hist(T, 1:max(T));
    valid = find(a > 1);
    data = max(a(valid));
    warning('on','stats:pdist:ConstantPoints');
  case 'eigenvector centrality'
    data = eigenvector_centrality_und(double(~~(RS+RS')));
  case 'pagerank centrality'
    data = pagerank_centrality(RS, 0.85);
  case 'betwenness centrality'
    data = betweenness_bin(RS);
  case 'avg connection length'
    members = getExperimentGroupMembers(experiment, groupName);
    positions = [cellfun(@(x)x.center(1), experiment.ROI(members)) cellfun(@(x)x.center(2), experiment.ROI(members))];
    [i, j] = find(RS);
    data = sqrt(sum((positions(i, :)-positions(j, :)).^2,2));
  case 'num hubs'
    % From Schroettesr paper
    [cidx,comp_sizes] = get_components(RS);
    [~, idx]= max(comp_sizes);
    valid = find(cidx == idx);
    subRS = RS(valid, valid);
    % First the strength, here the degree
    str = degrees_dir(subRS);
    % Betweeness cen
    bet = betweenness_bin(subRS);
    % Local eff
    leff = efficiency_bin(subRS, 1);
    % Part coeff
    M = community_louvain(subRS);
    part  = participation_coef(subRS, M);
    hubScore = double(str(:) >= prctile(str, 80)) + double(bet(:) >= prctile(bet, 80)) + double(leff(:) >= prctile(leff, 80)) + double(part(:) >= prctile(part, 80));
    data = sum(hubScore >= 3);
  otherwise
    data = getCases('eval');
    %data = [];
end
if(~ischar(data) && ~iscell(data))
  data = double(data(:)); % Always as a column, just to be sure
end