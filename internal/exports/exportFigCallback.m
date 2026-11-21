function exportFigCallback(~, ~ , extensions, defaultName, varargin)
% EXPORTFIGCALLBACK Used to export figures
%
% Copyright (C) 2016-2026, Javier G. Orlandi <javier.orlandi@ucalgary.ca>


    % Varargin: resolution (dpi number)
    [fileName, pathName] = uiputfile(extensions, 'Save figure', defaultName);
    if(fileName ~= 0)
        if(length(varargin) >= 1)
            resolution = ['-r' num2str(varargin{1})];
        else
            resolution = '-r300';
        end
        %export_fig([pathName fileName], '-nocrop', resolution);
        export_fig([pathName fileName], resolution, ...
                   '-despc','-opengl','-q10');
    end
end