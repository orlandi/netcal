function saveProject(project, varargin)
% SAVEPROJECT saves the current project
%
% USAGE:
%    saveProject(project);
%
% INPUT arguments:
%
%    project - structure obtained from loadProject() or newProject()
%
% EXAMPLE:
%    saveProject(project)
%
% See also: newProject, loadProject
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>

params.verbose = true;
params.gui = [];
params = parse_pv_pairs(params, varargin);
if(isempty(params.gui))
  gui = gcbf;
else
  gui = params.gui;
end
if(params.verbose)
  logMsgHeader(['Saving project ' project.name], 'start', gui);
end
projectFile = [project.folder project.name '.proj'];

if(isempty(gui))
    assignin('base', 'projectFile', projectFile);
    evalin('base', 'save(projectFile)');
else
  % We should only save the project structure! Nothing else - this top part is probably not needed anymore
%     data = getappdata(gui);
%     names = fieldnames(data);
%     newData = [];
%     % Remove handles and other stuff when saving
%     for i = 1:numel(names)
%         if(isa(data.(names{i}), 'function_handle') || strcmp(names(i), 'logHandle') || ...
%                strcmp(names(i), 'infoHandle') || strcmp(names(i), 'multipleInfoHandle') || ...
%                strcmp(names(i), 'netcalOptionsCurrent') || ...
%                strcmp(names(i), 'jPropsPane') || ...
%                strcmp(names(i), 'propsList') || ...
%                strcmp(names(i), 'mirror') || ...
%                ~isempty(strfind(names{i}, 'Subplot')))
%             data = rmfield(data,names{i});
%         end
%     end
%     names = fieldnames(data);
%     for i = 1:numel(names)
%         % Also remove GUI handles when saving
%         if(ismethod(data.(names{i}), 'setGui'))
%             data.(names{i}) = data.(names{i}).setGui([]);
%         end
%         % Check if there are any figures
%         if(isa(data.(names{i}), 'matlab.ui.Figure'))
%             logMsg(['Warning, trying to save figure: ' data.(names{i})], gui, 'w');
%             data = rmfield(data, names{i});
%         end
%     end
    % Also check inside the current project - not anymore. We are passing the structure!
%     if(isfield(data, 'project'))
%         names = fieldnames(data.project);
%         for i = 1:numel(names)
%             % Also remove GUI handles when saving
%             if(ismethod(data.project.(names{i}), 'setGui'))
%                 data.project.(names{i}) = data.project.(names{i}).setGui([]);
%             end
%             % Check if there are any figures
%             if(isa(data.project.(names{i}), 'matlab.ui.Figure'))
%                 logMsg(['Warning, trying to save figure: ' data.project.(names{i})], gui, 'w');
%                 data.project = rmfield(data.project, names{i});
%             end
%         end
%         newData = data.project;
%     end
    
      names = fieldnames(project);
      for i = 1:numel(names)
        % Also remove GUI handles when saving
        if(ismethod(project.(names{i}), 'setGui'))
            project.(names{i}) = project.(names{i}).setGui([]);
        end
        % Check if there are any figures
        if(isa(project.(names{i}), 'matlab.ui.Figure'))
            logMsg(['Warning, trying to save figure: ' project.(names{i})], gui, 'w');
            project = rmfield(project, names{i});
        end
      end
      newData = project;
    
%     % If currentExperiment exists, no need to save the experiment here
%     if(isfield(data.project, 'currentExperiment') && isfield(data, 'experiment'))
%         data = rmfield(data, 'experiment');
%     else
%         if(isfield(data, 'experiment'))
%             names = fieldnames(data.experiment);
%             for i = 1:numel(names)
%                 % Also remove GUI handles when saving
%                 if(ismethod(data.experiment.(names{i}), 'setGui'))
%                     data.experiment.(names{i}) = data.experiment.(names{i}).setGui([]);
%                 end
%                 % Check if there are any figures
%                 if(isa(data.experiment.(names{i}), 'matlab.ui.Figure'))
%                     logMsg(['Warning, trying to save figure: ' data.experiment.(names{i})], gui, 'w');
%                     data.experiment = rmfield(data.experiment, names{i});
%                 end
%             end
%         end
%     end
    if(isempty(newData))
      logMsg('Something went wrong saving the project', 'e');
      return;
    end
    save(projectFile, '-struct', 'newData', '-v7.3');
end

if(params.verbose)
  logMsgHeader('Done!', 'finish', gui);
end

end