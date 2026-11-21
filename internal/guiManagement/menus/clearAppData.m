function clearAppData(netcalMainWindow)
  data = getappdata(netcalMainWindow);
  names = fieldnames(data);
  for it = 1:numel(names)
    % Do not clear relevant handles
    if(strcmp(names{it}, 'logHandle') || strcmp(names{it}, 'infoHandle') || strcmp(names{it}, 'multipleInfoHandle') || strcmp(names{it}, 'netcalOptionsCurrent'))
      continue;
    else
      rmappdata(netcalMainWindow, names{it});
    end
  end
end