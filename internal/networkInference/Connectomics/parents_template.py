#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sample script demonstarting how to estimate parents using GTE.

Created on Mon Aug 28 14:55:45 2017

@author: paul.herringer
"""
import pickle

from cnn.data_processing import estimate_parents
from cnn.utils import read_spike_trains


gte_params = {
    'CL':0.25,
    'k':2,
    'IFT':True,
    'estimate_CL':True,
    'num_parents':3
    }

# Training data files
data_path = '/home/paul.herringer/Documents/normal-spike-trains/'

times_normal1 = data_path + 'normal-1-inh_off-times.txt'
idx_normal1 = data_path + 'normal-1-inh_off-idx.txt'
network_normal1 = data_path + 'network_normal-1.txt'

times_normal2 = data_path + 'normal-2-inh_off-times.txt'
idx_normal2 = data_path + 'normal-2-inh_off-idx.txt'
network_normal2 = data_path + 'network_normal-2.txt'

times_normal3 = data_path + 'normal-3-inh_off-times.txt'
idx_normal3 = data_path + 'normal-3-inh_off-idx.txt'
network_normal3 = data_path + 'network_normal-3.txt'

# Read in spike data and true networks, estimate parents and save
spikes_normal1 = read_spike_trains([times_normal1, idx_normal1], timebin=30)
parents_normal1, scores_normal1 = estimate_parents(
    spikes_normal1, **gte_params)

with open(data_path + 'parents_normal1_30ms_inh-off.pkl', 'wb') as outf:
    pickle.dump(parents_normal1, outf)
    
with open(data_path + 'gte_scores_normal1_30ms_inh-off.pkl', 'wb') as outf:
    pickle.dump(scores_normal1, outf)


spikes_normal2 = read_spike_trains([times_normal2, idx_normal2], timebin=30)
parents_normal2, scores_normal2 = estimate_parents(
    spikes_normal2, **gte_params)

with open(data_path + 'parents_normal2_30ms_inh-off.pkl', 'wb') as outf:
    pickle.dump(parents_normal2, outf)
    
with open(data_path + 'gte_scores_normal2_30ms_inh-off.pkl', 'wb') as outf:
    pickle.dump(scores_normal2, outf)
    
    
spikes_normal3 = read_spike_trains([times_normal3, idx_normal3], timebin=30)
parents_normal3, scores_normal3 = estimate_parents(
    spikes_normal3, **gte_params)

with open(data_path + 'parents_normal3_30ms_inh-off.pkl', 'wb') as outf:
    pickle.dump(parents_normal3, outf)
    
with open(data_path + 'gte_scores_normal3_30ms_inh-off.pkl', 'wb') as outf:
    pickle.dump(scores_normal3, outf)