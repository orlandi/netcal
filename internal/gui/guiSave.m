function guiSave(experiment, experimentChanged, varargin)
% GUISAVEANDCLOSE checks if the experiment needs to be saved and closes the window
%
% USAGE:
%    guiSave(experiment, experimentChanged, save)
%
% INPUT arguments:
%    experiment - The experiment structure
%
%    experimentChanged - True if changes were made to the experiment
%
%    save - If true, will save the experiment no matter what
%
% EXAMPLE:
%     guiSave(experiment, experimentChanged, save)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also loadExperiment

% By default, if the experiment isn't virtual, save it - but if save is defined, do that
if((nargin < 3 || isempty(varargin{1})) && (~isfield(experiment, 'virtual') || ~experiment.virtual))
  save = true;
else
  save = false;
end
if(nargin == 3)
  save = varargin{1};
  if(save)
    experimentChanged = true;
  end
end

% Only save if the experiment is not virtual and has changed
if(save && experimentChanged)
  % Never save with the virtual field
  if(isfield(experiment, 'virtual'))
    experiment = rmfield(experiment, 'virtual');
  end
  saveExperiment(experiment, 'verbose', false);
else
  if(~experimentChanged)
    %logMsg('No changes were made to the experiment');
  else
    logMsg(sprintf('%s: Discarding any changes', experiment.name));
  end
end