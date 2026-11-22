function hash = fileMD5(file)
% FILEMD5 returns the MD5 hash of a file as a lowercase hex string
%
% The whole file is read in one call and hashed once, which is much faster
% than streaming it byte by byte through Java. Used by the NETCAL updater and
% by production/upload.m to detect files whose content changed but whose size
% did not.
%
% USAGE:
%   hash = fileMD5(file)
%
% INPUT arguments:
%   file - path to the file
%
% OUTPUT arguments:
%   hash - 32 character lowercase hex string. Empty ('') if the file does not
%          exist or cannot be read
%
% EXAMPLE:
%   hash = fileMD5('netcal.m')
%
% Copyright (C) 2016-2026, Javier G. Orlandi <javier.orlandi@ucalgary.ca>
%
% See also netcal, checkUserModifiedFile

hash = '';
try
  % Java resolves relative paths against its own working folder, not MATLAB's
  if(~java.io.File(file).isAbsolute())
    file = fullfile(pwd, file);
  end
  data = java.nio.file.Files.readAllBytes(java.io.File(file).toPath());
  md = java.security.MessageDigest.getInstance('MD5');
  % Empty files come back as [] which Java sees as null
  if(~isempty(data))
    md.update(data);
  end
  hash = lower(reshape(dec2hex(typecast(md.digest(), 'uint8'))', 1, []));
catch
  hash = '';
end
end
