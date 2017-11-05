#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Utility module for reading spikes, fluorescence, and true network scores
from files. 

Created on Thu Aug 24 15:48:48 2017

@author: paul.herringer
"""
import numpy as np


def read_spike_trains(files, timebin=20, data_type='sim', binning='no limit'):
    """Reads spike train data from file. Currently supports two file formats:
        
        1. Two one-column files, one with firing times in ms, the 
            other with neuron indices. Indices are continuous from 
            zero to the max index. Default for simulated data.
        2, One two-column csv file with indices for the first column 
            and firing times in s for the second column. Indices may
            not be continuous. Default for real data.
            
    There are also two binning methods supported:
        
        1. Binary binning, data will be encoded as 1 for any number of 
            spikes and 0 for no spikes.
        2. No limit binning where the integer number of spikes will be
            recorded for each time bin.
    
    Args:
        files: List of file names, should be [timefile, indexfile] for 
            simulated data or [datafile] for real data.
        timebin: Width of temporal binning, in ms.
        data_type: 'sim' for the two file method, 'real' for one file.
        binning: Type of spike binning, either 'binary' or 'no limit'.
        
    Returns:
        spikes: Array of spike data, shape (neurons, timesteps)
    """
    if data_type == 'sim':
        
        assert len(files) == 2
        timefile = files[0]
        indexfile = files[1]
        
        times = np.genfromtxt(timefile).astype(np.int32)
        indices = np.genfromtxt(indexfile).astype(np.int32)
        assert len(times) == len(indices)      
        
        spikes = np.zeros(
            (np.max(indices)+1, np.max(times)//timebin+1), dtype=np.int32)
        
        if binning == 'binary':
            for i in range(len(times)):
                time = times[i]//timebin
                index = indices[i]
                spikes[index][time] = 1
            
        elif binning == 'no limit':
            for i in range(len(times)):
                time = times[i]//timebin
                index = indices[i]
                spikes[index][time] += 1
                
        else:
            raise ValueError('Invalid binning type')
            
    elif data_type == 'real':
        
        timebin /= 1000
        
        assert len(files) == 1
        data = np.genfromtxt(files[0], skip_header=1, delimiter=',')
        times = data[:,1]
        indices = data[:,0].astype(np.int32)
        assert len(times) == len(indices)
        
        unq = np.unique(indices)
        idx = np.arange(unq.size)
        spikes = np.zeros(
            (unq.size, int(np.max(times)//timebin)+1), dtype=np.int32)
        
        if binning == 'binary':
            for i in range(len(times)):
                time = int(times[i]//timebin)
                index = int(idx[np.argwhere(unq==indices[i])])
                spikes[index][time] = 1
            
        elif binning == 'no limit':
            for i in range(len(times)):
                time = int(times[i]//timebin)
                index = int(idx[np.argwhere(unq==indices[i])])
                spikes[index][time] += 1
                
        else:
            raise ValueError('Invalid binning type')
            
    else:
            raise ValueError('Invalid data type')
            
    return spikes


def iter_loadtxt(filename, delimiter=',', skiprows=0, dtype=float):
    """Loads fluorescence data. Code from 
    http://stackoverflow.com/questions/8956832/python-out-
    of-memory-on-large-csv-file-numpy
    
    Args:
        filename: should be a text file
        delimiter: character that separates values in the file
        skiprows: skips this many rows at start of file
        dtype: best to keep this as float
        
    Returns:
        data: Fluorescence data in shape (neurons, timesteps)
    """
    def iter_func():
        
        with open(filename, 'r') as infile:
            
            for _ in range(skiprows):
                next(infile)
                
            for line in infile:
                line = line.rstrip().split(delimiter)
                for item in line:
                    yield dtype(item)
                    
        iter_loadtxt.rowlength = len(line)

    data = np.fromiter(iter_func(), dtype=dtype)
    data = data.reshape((-1, iter_loadtxt.rowlength))
    
    return data.T


def read_network_scores(filename):
    """Reads the true network for simulated data from a file. Original
    code by Bikasha Ray, Javier Orlandi and Olav Stetter.
    
    Args:
        filename: A csv file
        
    Returns:
        Matrix: Array representing the network adjacency matrix,
            shape (neurons, neurons).
    """
    l = []
   
    with open(filename, 'r') as f:
        
        for line in f:
            line = line.strip()
            if len(line) > 0:
                l.append(map(int, line.split(',')))
                
        l1 = np.loadtxt(filename,delimiter=",")    
   
    Matrix = [[0 for x in range(int(l1.max()))] for x in range(int(l1.max()))]

    for i in range(0,len(l1)-1):
        
        if l1[i][2] > 0:
            
            l1[i][2] = 1
            Matrix[int(l1[i][0])-1][int(l1[i][1])-1] = 1
            
        if l1[i][2] == 0:
            
            l1[i][2] = 0
            Matrix[int(l1[i][0])-1][int(l1[i][1])-1] = 0
            
        if l1[i][2] < 0:
            
            l1[i][2] = -1
            Matrix[int(l1[i][0])-1][int(l1[i][1])-1] = -1

    return np.array(Matrix)


def read_network(filename, mode='inhibition', verbose=1):
    """Reads true network scores from file. There are three network
    processing modes supported:
        1. Binary: label any type of connection as 1.
        2. Excitation: label excitatory connections as 1, set 
            inhibitory connections to 0.
        3. Inhibition: keep the standard network labels - 1 for 
            an excitatory connection and -1 for an inhibitory 
            connection.
            
    Args:
        filename: A csv file
        mode: Network processing mode.
        verbose: Control what gets printed to the console.
        
    Returns:
        network: Array representing the network adjacency matrix,
            shape (neurons, neurons).
    """
    network = read_network_scores(filename)
    
    if verbose > 0:
        print('Reading true network with processing mode:', mode)    
    
    if mode == 'binary':
        network[network < 0] = 1    
    elif mode == 'excitation':
        network[network < 0] = 0    
    elif mode == 'inhibition':
        pass
    else:
        raise ValueError('Invalid networkork processing mode')
                  
    return network