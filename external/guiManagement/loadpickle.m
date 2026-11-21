% From https://xcorr.net/2013/06/12/load-pickle-files-in-matlab/
function [a] = loadpickle(filename)
    if ~exist(filename,'file')
        error('%s is not a file',filename);
    end
    outname = [tempname() '.mat'];
    %pyscript = ['import cPickle as pickle;import sys;import scipy.io;file=open("' filename '","r");dat=pickle.load(file);file.close();scipy.io.savemat("' outname '",dat)'];
    pyscript = ['import pickle;import sys;import scipy.io;file=open("' filename '","rb");dat=pickle.load(file);file.close();scipy.io.savemat("' outname '", {"data": dat})'];
    %system(['LD_LIBRARY_PATH=/opt/intel/composer_xe_2013/mkl/lib/intel64:/opt/intel/composer_xe_2013/lib/intel64;python -c ''' pyscript '''']);
    [status, result] = system(['PATH=/home/orlandi/anaconda3/bin:$PATH;python -c ''' pyscript '''']);
    if(status ~= 0)
      logMsg('Something went wrong loading the pickle file','e');
      logMsg(sprintf('status: %d\nresult: %s', status, result), 'e');
      a = [];
    else
      a = load(outname);
      a = a.data;
    end
end