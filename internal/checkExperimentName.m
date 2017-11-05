function validName = checkExperimentName(experimentName, project, gui, force)
% CHECKEXPERIMENTNAME checks if a given experiment name is valid within a
% project
%
% USAGE:
%    validName = checkExperimentName(experimentName, project)
%
% INPUT arguments:
%    experimentName - the possible experimentName
%
%    project - project structure
%
% OUTPUT arguments:
%    validName - returns a valid name - empty if none was found
%
% EXAMPLE:
%     validName = checkExperimentName('test', project)
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also loadExperiment
if(isempty(gui))
    gui = gcbf;
end
if(isempty(force))
    force = false;
end
done = false;
validName = experimentName;
while(~done)
    done = true;
    for it = 1:size(project.experiments,2)
        if(strcmpi(project.experiments{it}, validName))
            % Allow overwriting an experiment
            if(force)
                validName = it;
                return;
            end
            answer = inputdlg('New experiment name',...
                              'Duplicate experiment name', [1 60], {validName});
            if(~isempty(answer))
                validName = answer{:};
                logMsg(sprintf('Experiment name changed to: %s', validName));
                done = false;
            else
                validName = []; % If no answer was given or cancelled, just return
                logMsg('Invalid experiment name', 'e');
            end
        end
    end
end