#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Module for creating and compiling a Keras CNN model. 

Created on Mon Aug 28 11:27:06 2017

@author: paul.herringer
"""
from keras.models import Model
from keras.layers import Input, Dense, Conv2D, MaxPooling2D, Flatten
from keras.layers import BatchNormalization, Dropout
from keras.layers.advanced_activations import PReLU
from keras.regularizers import l2


def CNN_Parents(classes=3, verbose=1, **params):
    """CNN Model that predicts the connection between two neurons using data
    from the time series of the neurons in question, the average activity 
    of the entire network, and the average activity of the strongest parents.
    Based on the structure used in Romaszko 2015.
    
    Args:
        classes: Number of connection classes to consider.
        verbose: Control what gets printed to the console.
        **conv_filter_size: Tuple indicating the height and width of the 
            main convolutional filter. Make sure you pick a size that 
            still allows the input and output shapes to work out.
        **maxpool_size: Tuple indicating the height and width of the 
            max pooling filter.
        **conv_units: Tuple of length 4 indicating the number of 
            convolutional filters to use for each conv layer.
        **dense_units: Number of units to use for the hidden dense layer.
        **dropout: Fraction of activations that will drop out at each layer. 
        **reg_param: Strength of the l2 weight regularization.
        **init_type: Kernel initialization method for training.
        **loss: Type of loss used for training. 
        **optimizer: Optimizer used for training. 
        **metrics: List of metrics to keep track of during training.
            
    Returns:
        model: A Keras Model object.
    """

    conv_filter_size = params.setdefault('conv_filter_size', (2,5))
    maxpool_size = params.setdefault('maxpool_size', (1,10))
    conv_units = params.setdefault('conv_units', (18, 18, 40, 15))
    dense_units = params.setdefault('dense_units', 100)
    dropout = params.setdefault('dropout', 0.2)
    reg_param = params.setdefault('reg_param', 1e-6)
    init_type = params.setdefault('init_type', 'he_normal')
    loss = params.setdefault('loss', 'categorical_crossentropy')
    optimizer = params.setdefault('optimizer', 'adam')
    metrics = params.setdefault('metrics', ['categorical_accuracy'])

    reg = l2(reg_param)
    
    inputs = Input(shape=(5,330,1), name='input')
    
    conv1 = Conv2D(conv_units[0], conv_filter_size, 
                   kernel_initializer=init_type, 
                   kernel_regularizer=reg)(inputs)
    conv1 = BatchNormalization()(conv1)
    conv1 = PReLU()(conv1)
    conv1 = Dropout(dropout)(conv1)
    
    conv2 = Conv2D(conv_units[1], conv_filter_size, strides=(2,1), 
                   kernel_initializer=init_type, 
                   kernel_regularizer=reg, name='conv2')(conv1)
    conv2 = BatchNormalization()(conv2)
    conv2 = PReLU()(conv2)
    conv2 = Dropout(dropout)(conv2)
    
    conv3 = Conv2D(conv_units[2], conv_filter_size, 
                   kernel_initializer=init_type, 
                   kernel_regularizer=reg, name='conv3')(conv2)
    conv3 = BatchNormalization()(conv3)
    conv3 = PReLU()(conv3)
    conv3 = Dropout(dropout)(conv3)
    
    maxpool = MaxPooling2D(pool_size=maxpool_size, name='maxpool')(conv3)
    
    conv4 = Conv2D(conv_units[3], 1, kernel_initializer=init_type, 
                   kernel_regularizer=reg, name='conv4')(maxpool)
    conv4 = BatchNormalization()(conv4)
    conv4 = PReLU()(conv4)
    conv4 = Dropout(dropout)(conv4)
    conv4 = Flatten()(conv4)
    
    dense1 = Dense(dense_units, kernel_initializer=init_type,
                   kernel_regularizer=reg, name='dense1')(conv4)
    dense1 = BatchNormalization()(dense1)
    dense1 = PReLU()(dense1)
    dense1 = Dropout(dropout)(dense1)
    
    pred = Dense(classes, activation='softmax', kernel_initializer=init_type,
                 kernel_regularizer=reg, name='pred')(dense1)
    
    model = Model(inputs=inputs, outputs=pred)
    model.compile(optimizer=optimizer, loss=loss, metrics=metrics)

    return model


def main():
    
    model = CNN_Parents()
    model.summary()
    print(model.layers)    
    
if __name__ == '__main__':
    
    main()
