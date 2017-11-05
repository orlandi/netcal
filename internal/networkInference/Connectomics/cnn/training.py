#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Module for training a CNN model on neural data. 

Created on Mon Aug 28 11:21:43 2017

@author: paul.herringer
"""
from keras.models import load_model
from keras.callbacks import (
    EarlyStopping, 
    CSVLogger, 
    ModelCheckpoint, 
    TensorBoard,
    ReduceLROnPlateau
    )
from cnn.data_processing import generate_dataset


def train_cnn_model(model, datasets, networks, parents, verbose=1, **params):
    """Generates a training dataset and trains a CNN model to predict 
    neuron connectivity. Saves a log of training metrics, a tensorboard
    file, and the weights of the model that obtained the best validation 
    results. 
    
    Args:
        model: A compiled Keras Model object.
        datasets: List of full spike or fluorescence datasets. Each dataset
            should be of shape (neurons, timesteps).
        networks: List of adjacency matrices representing the true 
            connections between neurons in each dataset. Each entry should 
            be of shape (neurons, neurons).
        parents: List of dicts that contain indices for the strongest 
            drivers of each neuron in the corresponding dataset, as
            estimated by GTE. If any entries are NoneType, parents for 
            that dataset will be estimated within this function.
        verbose: Control what gets printed to the console.
        **logdir: Directory to save training logs and trained model to.
        **batch_sizes: List of batch sizes (allows for batch size annealment)
        **epochs: Maximum number of epochs to train for each batch size.
        **early_stopping_monitor: Metric to use for early stopping.
        **early_stopping_patience: Patience of early stopping monitor.
        **checkpoint_monitor: Metric to use for saving checkpoints.
        **lr_decay_monitor: Metric to use for learning rate annealment.
        **lr_decay_factor: Factor to decay learning rate when loss plateaus.
            New lr = lr*factor.
        **lr_decay_patience: Patience of learning rate decay monitor.
        
        Also accepts **params for data_processing.generate_dataset.
        
    Returns:
        model: The Keras Model that obtained the best validation results
            according to the checkpoint_monitor metric. Note that this may 
            not be the model from the last epoch of training. 
        mean: Element-wise mean of the training examples. This should 
            be subtracted from all validation and prediction data as part 
            of preprocessing.
    """
    # Parameters
    logdir = params.setdefault('logdir', '/cnn_training_logs/')
    batch_sizes = params.setdefault('batch_sizes', [256])
    epochs = params.setdefault('epochs', 200)
    early_stopping_monitor = params.setdefault(
        'early_stopping_monitor', 'val_loss')
    early_stopping_patience = params.setdefault('early_stopping_patience', 20)
    checkpoint_monitor = params.setdefault('checkpoint_monitor', 'val_loss')
    lr_decay_monitor = params.setdefault('lr_decay_monitor', 'val_loss')
    lr_decay_factor = params.setdefault('lr_decay_factor', 0.1)
    lr_decay_patience = params.setdefault('lr_decay_patience', 10)
    
    # Training data
    ex_train, ex_valid, lbl_train, lbl_valid, mean = generate_dataset(
        datasets, networks, parents, mode='train', verbose=verbose, **params)
    
    # Callbacks
    early_stopper = EarlyStopping(monitor=early_stopping_monitor, 
                                  patience=early_stopping_patience)
    csv_logger = CSVLogger(logdir + 'training_log.csv', append=True)
    checkpoint = ModelCheckpoint(logdir + 'best_model.h5',
                                 monitor=checkpoint_monitor,
                                 save_best_only=True,
                                 verbose=verbose)
    tensorboard = TensorBoard(log_dir=logdir, write_graph=False)
    lr_decay = ReduceLROnPlateau(monitor=lr_decay_monitor, 
                                 factor=lr_decay_factor, 
                                 patience=lr_decay_patience,
                                 verbose=1)
    
    # Training
    for b in batch_sizes:
        model.fit(
            ex_train, lbl_train, batch_size=b, epochs=epochs,
            validation_data=(ex_valid, lbl_valid), shuffle=True,
            callbacks=[
                early_stopper, 
                csv_logger, 
                checkpoint, 
                tensorboard,
                lr_decay
                ]
            )
    
    model = load_model(logdir + 'best_model.h5')
    
    return model, mean
