#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Aug 24 16:03:39 2017

@author: paul.herringer
"""
import warnings

import numpy as np
import progressbar as pb


def calc_PDF(D, G, k=2, IFT=True, verbose=1):    
    """Generates a probability density function matrix for caluclating GTE.
    
    Args:
        D: Neuron firing data in shape (timesteps, neurons). Data points
            should be integer values; either spikes or discretized 
            fluorescence data.
        G: Vector to condition data on the average activity level of the 
            network. Should be 1 when avg > conditioning level and 
            0 when avg < conditioning level.
        k: Maximum time lag for the PDF to consider.
        IFT: Whether to include in instant feedback term, that is, to 
            condition on the present state of the sending variable
            as well as its past.
        verbose: Control what gets printed to the console.
        
    Returns:
        P: Array, PDF for computing GTE(i -> j). Order of dimsensions is
            (jnow, jpast, inow(if IFT), ipast, G, neuron i, neuron j).
            Total number of dimensions will depend on k and IFT.
    """
    # Important params
    bins = np.unique(D).size
    timesteps, neurons = D.shape
    ndims = 2*k + 1
    if IFT:
        ndims += 1
    
    # Dimensions of the final joint PDF matrix
    dims = [bins for d in range(ndims)] + [np.unique(G).size, neurons, neurons]
    dims = np.array(dims)
    
    # Vector of increasing values from 0 to the product of all dimensions 
    # except those that represent the ij neuron
    Pnumel = np.arange(np.prod(dims[:-2]), dtype=np.int64)
    minlength = Pnumel.size
    
    # This will become the final PDF
    P = np.zeros(np.prod(dims))
    
    # To access entire PDF with a single index (multipliers) or just
    # up to but not including the neuron indices (mult)
    multipliers = np.concatenate(([1], np.cumprod(dims[:-1]))).astype(np.int)
    mult = multipliers[:-2]
    
    # Lists to hold pre-computed time samples for all neurons
    # 1st list is for recieving neuron, 2nd for sending neuron
    MD_list_1 = []
    MD_list_2 = []
    
    # Can only use time samples for which we have enough steps into the past
    validSamples = np.arange(k, timesteps)
    
    # Array to hold present and past time samples
    multDi = np.zeros([validSamples.size, k+1])
    
    for i in range(neurons):
        
        Di = D[:,i]
        
        # Valid samples for Di, Di(t-1), Di(t-2), etc
        for j in range(k+1):
            multDi[:,j] = Di[k-j:Di.size-j]
        
        # Di, Di(t-1), etc for recieving neuron, indexed by mult
        mDi_1 = np.dot(multDi, mult[:k+1])
        
        # IFT, Di(t-1), etc for sending neuron, indexed by mult
        mDi_2 = np.dot(multDi[:,1-IFT:], mult[k+1:-1])
        
        MD_list_1.append(mDi_1)
        MD_list_2.append(mDi_2)
        
    # Vector of G values for all valid samples, indexed by multipliers
    GVector = G[validSamples]
    multGVector = mult[-1]*GVector
    
    if verbose > 0:
        print('Generating PDF for {} neurons'.format(neurons))
        total_conns = int((neurons**2 - neurons)/2)
        count = 0
        bar = pb.ProgressBar(max_value=total_conns,
                             widgets=[pb.Percentage(),
                                      ' - ', pb.Bar(), 
                                      ' - ', pb.ETA()])
    
    for i in range(neurons): 
        for j in range(i+1, neurons):
            
            # Sum over multiplied jnow, jpast, ipast, G
            indexIJ = MD_list_1[j] + MD_list_2[i] + multGVector
            
            # Displacement factor to access the ij neuron in the matrix
            displace = i*multipliers[-2]+j*multipliers[-1]
            
            # Count the number of times that any given index comes up 
            bincounts = np.bincount(
                indexIJ.astype(np.int), minlength=minlength)
            
            # Apply the displacement and increment PDF values
            index = Pnumel + displace
            P[index.astype(np.int)] += bincounts
            
            # Repeat the above for the j --> i connection
            indexJI = MD_list_1[i] + MD_list_2[j] + multGVector
            displace = j*multipliers[-2] + i*multipliers[-1]
            bincounts = np.bincount(
                    indexJI.astype(np.int), minlength=minlength)
            index = Pnumel + displace
            P[index.astype(np.int)] += bincounts
            
            if verbose > 0:
                bar.update(count)
                count += 1
    
    if verbose > 0:        
        bar.finish()
    
    # Reshape P to match the dimensions calculated earlier
    return P.reshape(dims, order='F')


def calc_GTE_from_PDF(P, IFT=True, verbose=1):
    """Calculates matrix of GTE scores from an unnormalized PDF.
    
    Args:
        P: Array, unnormalized PDF. Shape as described in calc_PDF.
        IFT: Wheter the instant feedback term was included when 
            generating the PDF. The function will crash if this is
            incorrect.
        verbose: Control what gets printed to the console.
            
    Returns:
        GTE: Array of GTE scores, shape (neurons, neurons)
    """
    if verbose > 0:
        print('Calculating GTE from PDF')
    
    # To avoid anything weird happening with division
    P = P.astype(np.float64)
    
    # Recover the dimensions of P, and the value of k
    ndimsP = P.ndim
    dim = (ndimsP-3) - IFT
    k = dim//2
    
    # Partial sums
    # P(j(k), i(k), g)
    jk_ik_g = np.sum(P, axis=0, keepdims=True)
    
    # P(j, j(k), g)
    index_j_jk_g = range(ndimsP)[k+1:-3]
    j_jk_g = np.sum(P, axis=tuple(index_j_jk_g), keepdims=True)
    
    # P(j(k), g), which is just j_jk_g summed over jnow
    jk_g = np.sum(j_jk_g, axis=0, keepdims=True)
    
    # Always complains about zero division
    warnings.simplefilter('ignore')
    GTE = P*np.log2(P*jk_g/(j_jk_g*jk_ik_g))
    GTE[np.isnan(GTE)] = 0
        
    # Sum over all dimensions except G, neuron i and neuron j
    GTE = np.sum(GTE, axis=tuple(range(ndimsP-3)))
        
    # Normalization factor is the sum of entries with average activity 
    # below conditioning level. We get this by choosing an arbitrary neuron
    # (in this case i=1, j=2), G=0, and summing P over all other axes
    normFactor = 1/np.sum(P, axis=(tuple(range(ndimsP-3))))[0,1,2]
    
    return GTE[0,:,:]*normFactor


def get_conditioning(D, CL=0.25, estimate_CL=False, verbose=1):
    """Generates the conditioning vector for GTE. 1 when average level
    is above CL, 0 when below. Can take the conditioning level directly 
    or estimate it.
    
    Args:
        D: Neuron firing data in shape (timesteps, neurons). Data points
            should be integer values; either spikes or discretized 
            fluorescence data.
        CL: Conditioning level. 
        estimate_CL: Whether to estimate the conditioning level based on
            the histogram average activity.
        verbose: Control what gets printed to the console.
        
    Returns:
        G: Conditioning vector, 1 when avg >= CL, 0 when avg < CL.
    """
    avg_D = np.mean(D, axis=1, dtype=np.float64)
    
    if estimate_CL:
        if verbose > 0:
            print('Estimating conditioning level')
        hist, bin_edges = np.histogram(avg_D, bins=100)
        CL = bin_edges[np.argmax(hist)] + 0.05
        if verbose > 0:
            print('Conditioning level set at {:.4f}'.format(CL))
            
    return np.greater_equal(avg_D, CL)


def calc_GTE(D, CL=0.25, k=2, IFT=True, estimate_CL=False, verbose=1):
    """Convenience function to go directly from data to a matrix
    of GTE scores.
    
    Args:
        D: Neuron firing data in shape (timesteps, neurons). Data points
            should be integer values; either spikes or discretized 
            fluorescence data.
        CL: Conditioning level.
        k: Maximum time lag to consider.
        IFT: Whether to include in instant feedback term, that is, to 
            condition on the present state of the sending variable
            as well as its past.
        estimate_CL: Whether to estimate the conditioning level based on
            the histogram of average activity.
        verbose: Control what gets printed to the console.
        
    Returns:
        scores: Adjacency matrix of GTE scores, shape (neurons, neurons).
    """
    G = get_conditioning(D, CL=CL, estimate_CL=estimate_CL, verbose=verbose)
    P = calc_PDF(D, G, k=k, IFT=IFT, verbose=verbose)
    scores = calc_GTE_from_PDF(P, IFT=IFT, verbose=verbose)
    
    return scores