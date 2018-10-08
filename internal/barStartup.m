function params = barStartup(params, infoMsg, automatic, varargin)

if(nargin < 2)
  infoMsg = 'Processing';
end
if(nargin < 3)
  automatic = false;
end

if(params.verbose && ~isempty(infoMsg))
  logMsgHeader(infoMsg, 'start', varargin{:});
end

params.pbarCreated = false;

if(isempty(params.pbar))
  params.pbarCreated = true;
  ncbar.close();
  ncbar(infoMsg);
  pause(1);
  params.pbar = 1;
elseif(params.pbar > 0)
  ncbar.setCurrentBar(params.pbar);
  ncbar.setCurrentBarName(infoMsg);
end
if(params.pbar > 0 && automatic)
  try
    ncbar.setAutomaticBar();
  catch
  end
end
