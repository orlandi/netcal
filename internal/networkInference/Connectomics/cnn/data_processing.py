#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Module for pre-processing data to be fed to CNN models.

Created on Thu Aug 24 12:59:29 2017

@author: paul.herringer
"""
import numpy as np
import progressbar as pb

from cnn.gte import calc_GTE


def estimate_parents(D, verbose=1, **params):
    """Estimates the strongest drivers of each neuron using GTE.
    
    Args:
        D: Spike or fluorescence data in shape (neurons, timesteps).
        verbose: Control what gets printed to the console.
        **CL: Conditioning level.
        **k: Maximum time lag to consider.
        **IFT: Whether to include in instant feedback term, that is, to 
            condition on the present state of the sending variable
            as well as its past.
        **estimate_CL: Whether to estimate the conditioning level based on
            the histogram of average activity.
        **num_parents: Number of parents to record for each variable. 
            Parents are chosen by largest GTE score.
        
    Returns:
        parents: Dict of parents for each neuron. Keys are the index
        of the recieving neuron, values are the indices of the strongest
        drivers.
        scores: Adjacency matrix of GTE scores, shape (neurons, neurons).
    """
    # Parameters
    CL = params.setdefault('CL', 0.25)
    k = params.setdefault('k', 2)
    IFT = params.setdefault('IFT', True)
    estimate_CL = params.setdefault('estimate_CL', False)
    num_parents = params.setdefault('num_parents', 3)
    
    if verbose > 0:
        print('Estimating parents using GTE')
    
    # Cast D to only two bins for activity level
    D = np.greater(D, 0)
    parents = dict()
    scores = calc_GTE(
        D.T, CL=CL, k=k, IFT=IFT, estimate_CL=estimate_CL, verbose=verbose)
    
    for i in range(scores.shape[0]):
        p = (-scores[:,i]).argsort()[:num_parents]
        parents[i] = p
        
    return parents, scores


def downsample_spikes(S, thres=150, verbose=1):
    """Downsamples spike data to include only the top 1% of frames
    based on total activity. Based on https://github.com/spoonsso/TFconnect.
    
    Args:
        S: Spike data in shape (neurons, timesteps).
        thres: Threshold for activity at a single time frame. The 
            default works for 1000 neurons.
        
    Returns:
        Downsampled spike data, now of 
            shape (neurons, downsampled timesteps).
    """
    sum_S = np.sum(S, axis=0)
    if verbose > 0:
        print(
            'Downsampling spike data to {} frames using threshold {}'
            .format(np.sum(np.greater(sum_S, thres)), thres))
    
    return S[:, np.greater(sum_S, thres)]


def downsample_fluorescence(F, thres=20, verbose=1):
    """Downsamples fluorescence data to include approximately the 
    top 1% of frames based on total increase in activity. Currently the
    threshold is set for 1000 neurons. Original code from 
    https://github.com/spoonsso/TFconnect.
    
    Args:
        F: Fluorescence data in shape (neurons, timesteps).
        thres: Threshold for activity at a single time frame. The 
            default works for 1000 neurons.
            
    Returns:
        Downsampled fluorescence data, now of 
            shape (neurons, downsampled timesteps).
    """
    diff_F = np.diff(F, axis=1)
    sum_F = np.sum(diff_F, axis=0)
    F = F[:,:-1]
    if verbose > 0:
        print(
            'Downsampling fluorescence data to {} frames using threshold {}'
            .format(np.sum(np.greater(sum_F, thres))))
    
    return F[:, np.greater(sum_F, thres)]


def get_examples(ds_data, network, parents, verbose=1, **params):
    """Generates a balanced set of training examples from a single dataset.
    
    Args:
        ds_data: Downsampled spike or fluorescence data in shape
            (neurons, timesteps).
        network: Adjacency matrix representing the true connections of the
            neurons in the dataset. Shape (neurons, neurons).
        parents: Dict of indices indicating the strongest drivers of 
            each neuron as estimated by GTE.
        verbose: Control what gets printed to the console.
        **classes: List of connection class labels, as integers. Default is
            [-1, 0, 1] for inhibitory, none, and excitatory connection
            respectively.
        **target: Total number of examples to generate from this dataset.
        **slice_len: Length of time series slice used to generate examples.
        
    Returns:
        examples: Array of training examples, shape (target, 5, slice_len, 1).
        labels: Array of training labels, shape (target, # of classes).
    """
    # Parameters
    classes = params.setdefault('classes', [-1,0,1])
    target = params.setdefault('target', int(1.2e6))
    slice_len = params.setdefault('slice_len', 330)
    
    assert not target % len(classes)
   
    G = np.mean(ds_data, axis=0)   
    examples = np.zeros((target, 5, slice_len, 1))
    labels = np.zeros((target, len(classes)))
    count = 0
    
    if verbose > 0:
        print('Generating {} training examples'.format(target))
        bar = pb.ProgressBar(max_value=target,
                             widgets=[pb.Percentage(), ' - ',
                                      pb.Bar(), ' - ',
                                      pb.ETA()])
    
    for c in classes:
        
        pairs = np.argwhere(network == c)
        reps = int(target/len(classes)/pairs.shape[0]) + 1
        pair_idx = np.repeat(np.arange(pairs.shape[0]), reps)
        pair_idx = np.random.permutation(pair_idx)[:target//len(classes)]
        start_idx = np.random.randint(
            0, ds_data.shape[1]-slice_len, size=target//len(classes))
        
        for i in range(pair_idx.size):
            
            n1 = pairs[pair_idx[i]][0]
            n2 = pairs[pair_idx[i]][1]
            assert(network[n1,n2] == c)
            
            start = start_idx[i]
            end = start + slice_len
            
            p1 = np.mean(ds_data[parents[n1], start:end], axis=0)
            p2 = np.mean(ds_data[parents[n2], start:end], axis=0)
            
            examples[count,:,:,0] = np.vstack((
                                        p1, 
                                        ds_data[n1][start:end], 
                                        G[start:end], 
                                        ds_data[n2][start:end], 
                                        p2
                                        ))
            
            labels[count,:] = np.equal(classes, c, dtype=np.int32)
            
            if verbose > 0:
                bar.update(count)
            count +=1
        
    if verbose > 0:
        bar.finish()
        print(
            'Generated examples of shape:', examples.shape,
            '\nGenerated labels of shape:', labels.shape,
            '\nThere are {} classes: {}'.format(len(classes), classes)
            )
    
    assert not np.isnan(examples).any()
    return examples, labels


def generate_dataset(
    datasets, networks, parents, mode='train', mean=None, 
    verbose=1, **params):
    """
    Generates a balanced set of training examples from one or more datasets.
    
    Args:
        datasets: List of full spike or fluorescence datasets. Each dataset
            should be of shape (neurons, timesteps).
        networks: List of adjacency matrices representing the true 
            connections between neurons in each dataset. Each entry should 
            be of shape (neurons, neurons).
        parents: List of dicts that contain indices for the strongest 
            drivers of each neuron in the corresponding dataset, as
            estimated by GTE. If any entries are NoneType, parents for 
            that dataset will be estimated within this function.
        mode: Either 'train' or 'test'. In train mode the data will be zero 
            centered by subtracting the mean over each feature. In test 
            mode the mean of the training set must be given and will be 
            subtracted from the test data. 
        mean: Mean of training data over each feature. Must be the same shape
            as a single example.
        verbose: Control what gets printed to the console.
        **classes: List of connection class labels, as integers. Default is
            [-1, 0, 1] for inhibitory, none, and excitatory connection
            respectively.
        **data_type: Either spikes or fluorescence.
        **thres: Threshold for downsampling data.
        **target: Total number of examples to generate from this dataset.
        **valid_split: Fraction of data to hold apart for validation.
        **slice_len: Length of time series slice used to generate examples.
        
        Also accepts **params for data_processing.estimate_parents and 
        data_processing.get_examples. Params for estimate_parents are 
        only relevant if parents are to be estimated within this function.
        
    Returns:
        In train mode:
            ex_train: Array of training examples.
            ex_valid: Array of validation examples.
            lbl_train: Array of training labels.
            lbl_valid: Array of validation labels.
            mean: Array, mean of training examples over axis 0.
        In test mode:
            examples: Array of training examples.
            labels: Array of training labels.
        
    """
    # Parameters
    classes = params.setdefault('classes', [-1,0,1])
    data_type = params.setdefault('data_type', 'spikes')
    thres = params.setdefault('thres', 150.0)
    target = params.setdefault('target', int(1.2e6))
    valid_split = params.setdefault('valid_split', 0.1)
    slice_len = params.setdefault('slice_len', 330)
    
    assert len(datasets) == len(networks) == len(parents)
    examples = np.zeros((target, 5, slice_len, 1))
    labels = np.zeros((target, len(classes)))
    ex_per_netw = target//len(datasets)
    params['target'] = ex_per_netw
    
    for i in range(len(datasets)):
        
        if verbose > 0:
            print('Network {} of {}'.format(i+1, len(datasets)))
            
        data = datasets[i]
        network = networks[i]
        parents_ = parents[i]
        
        if data_type == 'spikes':
            ds_data = downsample_spikes(data, thres=thres, verbose=verbose)
        elif data_type == 'fluorescence':
            ds_data = downsample_fluorescence(
                data, thres=thres, verbose=verbose)
        else:
            raise ValueError('Invalid data type')
            
        start = i*ex_per_netw
        end = (i+1)*ex_per_netw
        examples[start:end], labels[start:end] = get_examples(
            ds_data, network, parents_, verbose=verbose, **params)
    
    shuffle_idx = np.random.permutation(np.arange(examples.shape[0]))
    examples = examples[shuffle_idx]
    labels = labels[shuffle_idx]
    
    if mode == 'train':
        
        idx = int(examples.shape[0]*valid_split)
        ex_valid, ex_train = np.split(examples, [idx], axis=0)
        lbl_valid, lbl_train = np.split(labels, [idx], axis=0)
        
        mean = np.mean(ex_train, axis=0)
        ex_train -= mean
        ex_valid -= mean
        
        return ex_train, ex_valid, lbl_train, lbl_valid, mean
    
    elif mode == 'test':
        
        assert mean != None
        examples -= mean
        
        return examples, labels
    
    else:
        raise ValueError('Invalid mode')

    
        
