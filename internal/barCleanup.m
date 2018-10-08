function barCleanup(params, infoMsg, varargin)

if(nargin < 2 || isempty(infoMsg))
  infoMsg = 'Done!';
end

if(params.pbarCreated)
  ncbar.close();
elseif(params.pbar > 0)
  if(ncbar.isAutomaticBar())
    ncbar.unsetAutomaticBar();
  else
    ncbar.update(1, 'force');
  end
end

if(params.verbose)
  logMsgHeader(infoMsg, 'finish', varargin{:});
end
