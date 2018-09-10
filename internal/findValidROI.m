function [idx, ID, success] = findValidROI(varargin)
% FINDVALIDROI finds the set of ROIs with the same ID across multiple experiments
%
% USAGE:
%   [idx, ID, success] = findValidROI(varargin)
%
% INPUT arguments:
%   exp1,exp2,... - list of experiment structures
%
% OUTPUT arguments:
%   idx - cell containing the valid ROI indices for each experiment
%
%   ID - cell containing the valid ROI IDs for each experiment
%
%   success - true if everything went ok. False otherwise
%
% EXAMPLE:
%    [idx, ID, success] = findValidROI(exp1, exp2, exp3)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

  success = true;
  Nexp = length(varargin);
  ID = cell(Nexp, 1);
  idx = cell(Nexp, 1);
  warning = false;
  for j = 1:Nexp
    ID{j} = getROIid(varargin{j}.ROI);
    if(length(ID{j}) ~= length(unique(ID{j})))
      logMsg(sprintf('Error. Experiments %s has multiple (%d) ROI with the same ID, you will have to fix that (go to viewROI -> preferences -> reassign', varargin{j}.name,  length(ID{j})-length(unique(ID{j}))), 'e');
      success = false;
      return;
    end
    if(j == 2)
      jointIdxList = intersect(ID{1}, ID{2});
      if(length(jointIdxList) ~= length(ID{1}) || length(jointIdxList) ~= length(ID{2}))
        warning = true;
      end
    elseif(j > 2)
      jointIdxList = intersect(jointIdxList, ID{j});
      if(length(jointIdxList) ~= length(ID{j}))
        warning = true;
      end
    end
  end
  if(warning)
    logMsg(sprintf('Warning. Experiments have different number of ROI, only using the ones with the same ID for comparison (using %d ROI from %d possibles)', length(jointIdxList), max(cellfun(@length,ID))), 'w');
  end
  
  for j = 1:Nexp
    %length(ID{j})
    members = ismember(ID{j}, jointIdxList);
    idx{j} = find(members);
    %[length(ID{j}) length(unique(ID{j})) length(jointIdxList) sum(members) length(idx{j})]
    %if(length(unique(idx{j})) ~= length(jointIdxList))
    %  ar=find(~ismember(idx{j}, jointIdxList));
    %  ar
    %  idx{j}(ar)
    %  find(jointIdxList == ar)
    %end
    ID{j} = ID{j}(idx{j});
  end
end