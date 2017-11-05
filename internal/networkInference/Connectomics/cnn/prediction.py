# -*- coding: utf-8 -*-
"""
Module for using a trained CNN model to predict network connectivity.
Includes funtions for computing connection scores, generating a null 
distribution with surrogate shuffles, and reconstructing the estimated
adjacency matrix of a network.

Created on Wed Aug 23 14:24:32 2017

@author: paul.herringer
"""
import numpy as np
import progressbar as pb


def predict_scores(model, ds_data, parents, mean, verbose=1, **params):
    """Uses a trained CNN model to predict class scores on
    downsampled data as an average of the scores from several 
    data slices. Shuffles the time series of potential driver
    variables if needed to compute a set of surrogate scores.
    
    Args:
        model: A trained keras Model object.
        ds_data: Downsampled spike data, shape (neurons, timesteps).
        parents: Dict of estimated parents for each neuron, 
            keys and values should both be neuron indices.
        mean: Mean of the training data, used for zero centering. Array of 
            shape (5, slice_len, 1).
        verbose: Control what gets printed to the console.
        **num_classes: Number of prediction classes that the CNN outputs.
        **slice_len: Length of data slice, in time frames.
        **batch_size: Minibatch size for CNN prediction.
        **shuffle_type: Shuffle method (use only if generating surrogates).
            Either 'jitter', 'block' or NoneType to skip shuffling.
        **num_blocks: Number of blocks to use if performing a 
            block shuffle.
    
    Returns:
        scores: Adjacency matrix of average scores for each class,
            shape (neurons, neurons, num_classes). Order of scores 
            along the class axis will be the same as the CNN output.
    """
    # Parameters
    num_classes = params.setdefault('num_classes', 3)
    slice_len = params.setdefault('slice_len', 330)
    batch_size = params.setdefault('batch_size', 256)
    shuffle_type = params.setdefault('shuffle_type', None)
    num_blocks = params.setdefault('num_blocks', 100)
    
    G = np.mean(ds_data, axis=0)
    
    passes = ds_data.shape[1]//slice_len
    scores = np.zeros((
        ds_data.shape[0], ds_data.shape[0], num_classes, passes))   
    start_idx = np.arange(
        0, ds_data.shape[1]-slice_len, slice_len, dtype=np.int32)
    assert start_idx.size == passes
    
    connections = int((ds_data.shape[0]**2 - ds_data.shape[0])/2)  
    
    if verbose > 0:
        print('Predicting scores')

    for n in range(passes):

        batch = np.zeros((
                ds_data.shape[0], ds_data.shape[0], 5, slice_len, 1))
        
        start = start_idx[n]
        end = start + slice_len
        
        if verbose > 0:
            print('\nGenerating samples for batch {} of {}'
                  .format(n+1, passes))
            count = 0
            bar = pb.ProgressBar(max_value=connections,
                                 widgets=[pb.Percentage(),
                                          ' - ', pb.Bar(),
                                          ' - ', pb.ETA()])

        for i in range(batch.shape[0]):
            for j in range(i+1, batch.shape[0]):
                
                exI = ds_data[i][start:end]
                exJ = ds_data[j][start:end]
                exPI = np.mean(ds_data[parents[i], start:end], axis=0)
                exPJ = np.mean(ds_data[parents[j], start:end], axis=0)
                
                # Shuffle potential drivers
                if shuffle_type == None:
                    exI_ = exI
                    exJ_ = exJ
                elif shuffle_type == 'jitter':
                    exI_ = jitter_shuffle(exI)
                    exJ_ = jitter_shuffle(exJ)
                elif shuffle_type == 'block':
                    exI_ = block_shuffle(exI, num_blocks=num_blocks)
                    exJ_ = block_shuffle(exJ, num_blocks=num_blocks)
                
                exG = G[start:end]

                batch[i,j,:,:,0] = np.vstack((exPI, exI_, exG, exJ, exPJ)) 
                batch[j,i,:,:,0] = np.vstack((exPJ, exJ_, exG, exI, exPI)) 
                
                if verbose > 0:
                    bar.update(count)
                    count += 1

        if verbose > 0:
            bar.finish()
            print('\nPredicting connectivity for batch {} of {}'
                  .format(n+1, passes))  
            
        pred = model.predict(batch.reshape((-1, 5, slice_len, 1)) - mean, 
                             batch_size=batch_size, verbose=verbose > 0)
        
        scores[:,:,:,n] = pred.reshape((ds_data.shape[0], 
                                        ds_data.shape[0], 
                                        num_classes))
        
        # Ignore autocorrelation
        for i in range(scores.shape[0]):
            scores[i,i,:,n] = 0

    return np.mean(scores, axis=-1)
    

def jitter_shuffle(vector):
    """Performs a jitter shuffle on the input data."""
    direction = np.random.choice([1,2,3], size=len(vector))
    shuffled = np.copy(vector)
    for i in range(1, len(vector)-1):
        if direction[i] == 1:
            shuffled[i-1] += vector[i]
            shuffled[i] -= vector[i]
        elif direction[i] == 3:
            shuffled[i+1] += vector[i]
            shuffled[i] -= vector[i]
            
    return shuffled 

def block_shuffle(vector, num_blocks=100):
    """Performs a blocks shuffle by splitting the input into 
    randomly sized blocks, and then drawing randomly from these
    blocks until a shuffled vector of sufficient length is 
    generated.
    """
    count = 0
    indices = np.random.randint(0, len(vector), size=num_blocks)
    minlength = int(0.01*len(vector))
    maxloops = 1000
    
    while (np.abs(np.diff(indices)) < minlength).any() and count < maxloops:
        indices = np.random.randint(0, len(vector), size=num_blocks)
        count += 1
        
    if count == maxloops:
        raise RuntimeError(
            'Failed to generate enough blocks of minimum length')
        
    blocks = np.split(np.arange(len(vector)), np.sort(indices))
    count_ = 0
    maxloops_ = len(vector)//minlength
    indices_ = iter(np.random.randint(0, len(blocks), size=maxloops_))
    
    shuffled = []
    while len(shuffled) < len(vector) and count_ < maxloops_:
        shuffled.append(blocks[next(indices_)])
        count += 1
        
    if count_ == maxloops_:
        raise RuntimeError('Failed to generate a long enough sequence')
        
    return np.concatenate(shuffled)[:len(vector)]


def get_null_dist(model, ds_data, parents, mean, verbose=1, **params):
    """Generates a null distribution for CNN predictions using surrogate
    shuffles.
    
    Args:
        model: A trained keras Model object.
        ds_data: Downsampled spike data, shape (neurons, timesteps).
        parents: Dict of estimated parents for each neuron, 
            keys and values should both be neuron indices.
        mean: Mean of the training data, used for zero centering. Array of 
            shape (5, slice_len, 1).
        verbose: Control what gets printed to the console.
        **num_shuffles: Number of shuffles to perform.
        **shuffle_type: Shuffle method to use, either 'jitter' or 'block'.
        **num_classes: Number of prediction classes that the CNN outputs.
        
        Also accepts **params for prediction.predict_scores.
        
    Returns:
        null_dist: Null distribution of CNN predictions on shuffled
        data. Shape (neurons, neurons, num_classes, num_shuffles).
    """
    # Parameters
    num_shuffles = params.setdefault('num_shuffles', 500)
    shuffle_type = params.setdefault('shuffle_type', 'jitter')
    num_classes = params.setdefault('num_classes', 3)
    
    print(params)

    null_dist = np.zeros((
        ds_data.shape[0], ds_data.shape[0], num_classes, num_shuffles))
    
    if verbose > 0:
            print('Generating null distribution with {} {} shuffles'
                  .format(num_shuffles, shuffle_type))
            count = 0
            bar = pb.ProgressBar(max_value=num_shuffles,
                                 widgets=[pb.Percentage(),
                                          ' - ', pb.Bar(),
                                          ' - ', pb.ETA()])
    
    for i in range(num_shuffles):
        
        null_dist[:,:,:,i] = predict_scores(
            model, ds_data, parents, mean, verbose=0, **params)
        
        bar.update(count)
        count +=1
        
    bar.finish()
        
    return null_dist


def predict_network(
    model, ds_data, parents, mean, scores=[], verbose=1, **params):
    """Predicts the adjacency matrix of a network using a trained CNN 
    model by comparing the predicted class scores with a null 
    distribution of scores from shuffled data, at significance level
    alpha.
    
    Args:
        model: A trained keras Model object.
        ds_data: Downsampled spike data, shape (neurons, timesteps).
        parents: Dict of estimated parents for each neuron, 
            keys and values should both be neuron indices.
        mean: Mean of the training data, used for zero centering. Array of 
            shape (5, slice_len, 1).
        scores: Precomputed scores from CNN prediction on unshuffled data.
            Will be computed if not available.
        verbose: Control what gets printed to the console.
        **alpha: Significance level. A connection is inferred if the
            fraction of surrogate scores less than the actual score
            is greater than or equal to alpha.
        **class_labels: List of integers that represent the output
            classes of the CNN. Will be used to fill the adjacency 
            matrix. Should be in the same order as CNN output.
        
        Also accepts **params for prediction.predict_scores and 
        prediction.get_null_dist.
        
    Returns:
        adj_mat: Predicted adjacency matrix, shape (neurons, neurons).
        pvals: Array of calculated p-values, 
            shape (neurons, neurons, classes).
    """
    # Parameters
    alpha = params.setdefault('alpha', 0.95)
    class_labels = params.setdefault('class_labels', [-1,0,1])
    
    if scores == []:
        scores = predict_scores(
            model, ds_data, parents, mean, verbose=verbose, **params)
    scores = np.expand_dims(scores, axis=-1)
    null_dist = get_null_dist(
        model, ds_data, parents, mean, verbose=verbose, **params)
    pvals = np.mean(scores >= null_dist, axis=-1)
    
    adj_mat = np.zeros((ds_data.shape[0], ds_data.shape[0]))
    for i, class_ in enumerate(class_labels):
        mask = np.logical_and(
            pvals[:,:,i] > alpha, np.argmax(pvals, axis=-1) == i)
        adj_mat[mask] = class_
        
    return adj_mat, pvals, null_dist
