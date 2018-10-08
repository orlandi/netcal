#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sample script demonstrating how to validate a trained model on data that it 
hasn't seen before.

Created on Tue Aug 29 11:37:22 2017

@author: paul.herringer
"""

import pickle
import json

from keras.models import load_model

from cnn.utils import read_spike_trains, read_network
from cnn.data_processing import downsample_spikes
from cnn.prediction import predict_scores, predict_network
from cnn.validation import (
    get_onehot_vectors, 
    multiclass_auc, 
    multiclass_pr, 
    default
    )

params = {
    'valid_id':'normal3-rec',
    'timebin':5,
    'class_names':['inh', None, 'xct']
    }

validation_params = {
    'num_classes':3,
    'slice_len':330,
    'batch_size':256,
    'shuffle_type':None
    }

prediction_params = {
    'alpha':0.9,
    'num_classes':3,
    'class_labels':[-1,0,1],
    'slice_len':330,
    'batch_size':256,
    'shuffle_type':'jitter',
    'num_shuffles':100
    }

# Validation data files
data_path = '/home/paul.herringer/Documents/normal-spike-trains/'

times_normal3 = data_path + 'normal-3-inh-times.txt'
idx_normal3 = data_path + 'normal-3-inh-idx.txt'
network_normal3 = data_path + 'network_normal-3.txt'
pts_normal3 = data_path + 'parents2_normal3.pkl'

# Model files
logdir = '/home/paul.herringer/Documents/connectomics/cnn-parents/bn_prelu-5ms-2x10/'

# Read in spike data, true network and parents, downsample spikes
spikes_normal3 = read_spike_trains([times_normal3, idx_normal3], timebin=params['timebin'])
ds_spikes = downsample_spikes(spikes_normal3)
true_scores = read_network(network_normal3, mode='inhibition')
with open(pts_normal3, 'rb') as inf:
    parents_normal3 = pickle.load(inf)
    
# Load trained model and training data mean
model = load_model(logdir + 'best_model.h5')
with open(logdir + 'data_mean.pkl', 'rb') as inf:
    mean = pickle.load(inf)

# Predict scores for validation network and save
scores = predict_scores(
    model, ds_spikes, parents_normal3, mean, **validation_params)
with open(logdir + 'cnn_scores_' + params['valid_id'] + '_' + str(params['timebin']) + '.pkl', 'wb') as outf:
    pickle.dump(scores, outf)

# Reshape scores for metric calculation
scores_flat = scores.reshape(scores.shape[0]**2, -1)
true_scores = get_onehot_vectors(true_scores.flatten())

# Calculate FPR, TPR, AUC, precision and recall for each connection class
fpr, tpr, roc_auc = multiclass_auc(
        true_scores, scores_flat, class_names=params['class_names'])
precision, recall = multiclass_pr(
        true_scores, scores_flat, class_names=params['class_names'])

# Save metrics to file
suffix = '_' + str(params['valid_id'])
for name, metric in zip(['fpr', 'tpr', 'auc', 'precision', 'recall'],
                        [fpr, tpr, roc_auc, precision, recall]):
    with open(logdir + name + suffix + '.json', 'w') as outf:
        json.dump(metric, outf, sort_keys=True, default=default)

assert 1 == 0

# Predict network connectivity using a shuffle test, save
pred_scores, pvals, null_dist = predict_network(
    model, ds_spikes, parents_normal3, mean, scores=scores, **prediction_params)
with open(logdir + 'cnn_pred_' + params['valid_id'] + '_' + str(params['timebin']) + '.pkl', 'wb') as outf:
    pickle.dump(pred_scores, outf)
with open(logdir + 'cnn_pvals_' + params['valid_id'] + '_' + str(params['timebin']) + '.pkl', 'wb') as outf:
    pickle.dump(pvals, outf)
with open(logdir + 'cnn_null_dist_' + params['valid_id'] + '_' + str(params['timebin']) + '.pkl', 'wb') as outf:
    pickle.dump(null_dist, outf)

# Save params for reference
for name, dict_ in zip(['params', 'validation_params', 'prediction_params'],
                       [params, validation_params, prediction_params]):
    with open(logdir + name + '.json', 'w') as outf:
        json.dump(dict_, outf)
