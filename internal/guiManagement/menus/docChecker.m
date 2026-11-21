function menuList = docChecker(appFolder, menuList)
  % Reset the list
  for it = 1:length(menuList.docs.list)
    delete(menuList.docs.list(it));
  end
  menuList.docs.list = [];

  %docsList = dir([appFolder filesep 'docs' filesep '*.md']);
  docsList = rdir([appFolder filesep 'docs' filesep 'tutorials' filesep, '**', filesep, '*']);
  if(~isempty(docsList))
    menuList.docs.root.Enable = 'on';
    for i = 1:length(docsList)
      [fpa, fpb, fpc] = fileparts(docsList(i).name);
      relFolder = strrep(fpa, [appFolder filesep 'docs' filesep 'tutorials' filesep], '');
      relFolder = strsplit(relFolder, filesep);
      
      if(~strcmpi(fpc, '.md'))
        continue;
      elseif(strcmpi(fpb(1), 'index.md'))
        continue;
      elseif(strcmpi(fpb(1), '.'))
        continue;
      end
      % Get the parent
      curName = [];
      lastParent = [];
      for it = 1:length(relFolder)
        valid = find(arrayfun(@(x)strcmp(x.Tag, curName), menuList.docs.list));
        curName = [curName, relFolder{it}];
        if(isempty(valid))
          menuList.docs.list = [menuList.docs.list; ...
                              uimenu(menuList.docs.root, 'Label', relFolder{it}, 'Enable', 'on', 'Tag', curName)];
        else
          menuList.docs.list = [menuList.docs.list; ...
                              uimenu(menuList.docs.list(valid), 'Label', relFolder{it}, 'Enable', 'on', 'Tag', curName)];
        end
        lastParent = menuList.docs.list(end);
      end
      docName = fpb;
      if(isempty(lastParent))
        menuList.docs.list = [menuList.docs.list; ...
                              uimenu(menuList.docs.root, 'Label', docName, 'Enable', 'on', ...
                                     'Checked', 'off', 'Callback', {@menuTutorialOpen, docsList(i).name})];
      else
        menuList.docs.list = [menuList.docs.list; ...
                              uimenu(lastParent, 'Label', docName, 'Enable', 'on', ...
                                     'Checked', 'off', 'Callback', {@menuTutorialOpen, docsList(i).name})];
      end
    end
  end
end