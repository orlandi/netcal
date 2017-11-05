function fullNames = namesWithLabels(varargin)
    % Varargin 1: selection (if 0, everything)
    % 2: gui handle
    if(length(varargin) >= 2)
      gui = varargin{2};
    else
      gui = gcbf;
    end
    project = getappdata(gui, 'project');
    if(isempty(project))
        logMsg('Error loading data from the current project', 'e');
        fullNames = [];
        return;
    end
    if(length(varargin) >= 1 && ~isempty(varargin{1}))
        selection = varargin{1};
    else
        selection = 1:length(project.experiments);
    end
    
    fullNames = cell(length(project.experiments(selection)), 1);

    for n = 1:length(fullNames)
        name = project.experiments{selection(n)};
        if(isfield(project, 'labels') && length(project.labels) >= selection(n) && ~isempty(project.labels{selection(n)}))
            name = [name ' (' project.labels{selection(n)} ')'];
        end
        fullNames{n} = name;
    end
end
