#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sample script demonstrating how to setup and train a CNN model on spike data. 
The code at the start is for reproducibility when testing different model
hyperparameters - it can be removed once these are decided, and MUST be 
removed if generating several models for an ensemble.

Reproducibility code from https://keras.io/getting-started/faq/#how-can-i
    -obtain-reproducible-results-using-keras-during-development

Created on Tue Aug 29 12:39:07 2017

@author: paul.herringer
"""
import numpy as np
import tensorflow as tf
import random as rn

# The below is necessary in Python 3.2.3 onwards to
# have reproducible behavior for certain hash-based operations.
# See these references for further details:
# https://docs.python.org/3.4/using/cmdline.html#envvar-PYTHONHASHSEED
# https://github.com/fchollet/keras/issues/2280#issuecomment-306959926

import os
os.environ['PYTHONHASHSEED'] = '0'

# The below is necessary for starting Numpy generated random numbers
# in a well-defined initial state.

np.random.seed(42)

# The below is necessary for starting core Python generated random numbers
# in a well-defined state.

rn.seed(12345)

# Force TensorFlow to use single thread.
# Multiple threads are a potential source of
# non-reproducible results.
# For further details, see: https://stackoverflow.com/questions/42022950/which
# -seeds-have-to-be-set-where-to-realize-100-reproducibility-of-training-res

session_conf = tf.ConfigProto(intra_op_parallelism_threads=1, 
                              inter_op_parallelism_threads=1)

from keras import backend as K

# The below tf.set_random_seed() will make random number generation
# in the TensorFlow backend have a well-defined initial state.
# For further details, see: https://www.tensorflow.org/api_docs/python/tf
# /set_random_seed

tf.set_random_seed(1234)

sess = tf.Session(graph=tf.get_default_graph(), config=session_conf)
K.set_session(sess)

# Rest of code follows ...

import pickle
import json

from cnn.cnn_models import CNN_Parents
from cnn.training import train_cnn_model
from cnn.utils import read_spike_trains, read_network

model_params = {
    'conv_filter_size':(2, 10),
    'maxpool_size':(1, 10),
    'conv_units':(18, 18, 40, 15),
    'dense_units':100,
    'dropout':0.2,
    'reg_param':1e-6,
    'init_type':'he_normal',
    'loss':'categorical_crossentropy',
    'optimizer':'adam',
    'metrics':['categorical_accuracy']
    }

training_params = {
    'logdir':'/home/paul.herringer/Documents/connectomics/cnn-parents/bn_prelu-2ms-2x10/',
    'batch_sizes':[256],
    'epochs':200,
    'early_stopping_monitor':'val_loss',
    'early_stopping_patience':40,
    'checkpoint_monitor':'val_loss',
    'lr_decay_monitor':'val_loss',
    'lr_decay_factor':0.1,
    'lr_decay_patience':20,
    'thawed_layers':3
    }

data_params = {
    'classes':[-1,0,1],
    'data_type':'spikes',
    'thres':150.0,
    'target':int(9.0e5),
    'valid_split':0.1,
    'slice_len':330
    }

# Training data files
data_path = '/home/paul.herringer/Documents/normal-spike-trains/'

times_normal1 = data_path + 'normal-1-inh-times.txt'
idx_normal1 = data_path + 'normal-1-inh-idx.txt'
network_normal1 = data_path + 'network_normal-1.txt'
pts_normal1 = data_path + 'parents_normal1_20ms.pkl'

times_normal2 = data_path + 'normal-2-inh-times.txt'
idx_normal2 = data_path + 'normal-2-inh-idx.txt'
network_normal2 = data_path + 'network_normal-2.txt'
pts_normal2 = data_path + 'parents_normal2_20ms.pkl'

# Read in spike data, parents and true networks
spikes_normal1 = read_spike_trains([times_normal1, idx_normal1], timebin=2)
scores_normal1 = read_network(network_normal1, mode='inhibition')
with open(pts_normal1, 'rb') as inf:
    parents_normal1 = pickle.load(inf)

spikes_normal2 = read_spike_trains([times_normal2, idx_normal2], timebin=2)
scores_normal2 = read_network(network_normal2, mode='inhibition')
with open(pts_normal2, 'rb') as inf:
    parents_normal2 = pickle.load(inf)

# Train model
model = CNN_Parents(classes=3, **model_params)
model, mean = train_cnn_model(model,
                        [spikes_normal1, spikes_normal2],
                        [scores_normal1, scores_normal2],
                        [parents_normal1, parents_normal2],
                        **{**training_params, **data_params})

# Save data mean
with open(training_params['logdir'] + 'data_mean.pkl', 'wb') as outf:
    pickle.dump(mean, outf)

# Save params for reference    
for name, dict_ in zip(['model_params', 'training_params', 'data_params'],
                       [model_params, training_params, data_params]):
    with open(training_params['logdir'] + name + '.json', 'w') as outf:
        json.dump(dict_, outf)
