function fullFile = exportDataCallback(~, ~, extensions, defaultName, data, varargin)
% Varargin: column names - sheet name - row names FFU - file
    fullFile = [];
    if(length(varargin) >= 4)
      [pa, pb, pc] = fileparts(varargin{4});
      fileName = [pb pc];
      pathName = [pa filesep];
    else
      [fileName, pathName] = uiputfile(extensions, 'Save data', defaultName);
      if(fileName == 0)
        return;
      end
    end
    fullFile = [pathName fileName];
    if(fileName ~= 0)
      if(length(varargin) >= 1)
          names = varargin{1};
      end
      [fpa, fpb, ext] = fileparts(fileName);
      if(strcmp(ext, '.csv'))
        fID = fopen([pathName fileName], 'w');
        if(~isempty(names))
          lineStr = [sprintf('%s,',names{1:end-1}), sprintf('%s',names{end}), sprintf('\n')];
          fprintf(fID, lineStr);
        end
        % Data (everything turned into doubles)
        for i = 1:size(data,1)
          if(iscell(data))
            %data
            lineStr = [sprintf('%.3f,',data(i,1:end-1)), sprintf('%.3f\n',data(i,end))];
          else
            lineStr = [sprintf('%.3f,',data(i,1:end-1)), sprintf('%.3f\n',data(i,end))];
          end
            fprintf(fID, lineStr);
        end
        fclose(fID);
      elseif(strcmp(ext, '.txt'))
        fID = fopen([pathName fileName], 'w');
        % Data (everything turned into doubles)
        for i = 1:size(data,1)
          if(iscell(data))
            %data
            lineStr = [sprintf('%.3f ',data(i,1:end-1)), sprintf('%.3f\n',data(i,end))];
          else
            lineStr = [sprintf('%.3f ',data(i,1:end-1)), sprintf('%.3f\n',data(i,end))];
          end
            fprintf(fID, lineStr);
        end
        fclose(fID);
      elseif(strcmp(ext, '.xls') || strcmp(ext, '.xlsx'))
        logMsg('xls no longer supported. Using csv instead', 'w');
        ext = 'csv';
        fID = fopen([fpa filesep fpb ext], 'w');
        if(~isempty(names))
          lineStr = [sprintf('%s,',names{1:end-1}), sprintf('%s',names{end}), sprintf('\n')];
          fprintf(fID, lineStr);
        end
        % Data (everything turned into doubles)
        for i = 1:size(data,1)
          if(iscell(data))
            %data
            lineStr = [sprintf('%.3f,',data(i,1:end-1)), sprintf('%.3f\n',data(i,end))];
          else
            lineStr = [sprintf('%.3f,',data(i,1:end-1)), sprintf('%.3f\n',data(i,end))];
          end
            fprintf(fID, lineStr);
        end
        fclose(fID);
      else
        logMsg('Invalid file extension', 'e');
        return;
      end
    end
end