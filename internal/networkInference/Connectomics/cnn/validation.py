#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Module for computing validation metrics including the ROC and PR curves.

Created on Thu Aug 24 11:25:53 2017

@author: paul.herringer
"""
import numpy as np

from sklearn.metrics import roc_curve, auc, precision_recall_curve


def get_onehot_vectors(labels):
    """Converts integer class labels into onehot vectors to compare
    with CNN output.
    
    Args:
        labels: List of integer labels, may include negatives.
        
    Returns:
        onehot: Array of onehot vectors, shape (# labels, # classes).
    """
    classes = np.unique(labels)
    onehot = np.zeros((len(labels), len(classes)))
    for i in range(len(classes)):
        onehot[:,i][labels == classes[i]] = 1
        
    return onehot


def multiclass_auc(y_true, y_pred, class_names=[]):
    """Computes the FPR, TPR and ROC-AUC for multiclass predictions.
    
    Args:
        y_true: True class labels, shape (examples, classes).
        y_pred: Predicted class scores, shape (examples, classes).
        class_names: List of class name strings, with NoneType to
            indicate the no-connection class - eg ['inh', None, 'xct'].
            
    Returns:
        fpr: Dict of false positive rates for each class, plus the 
            micro-average.
        tpr: Dict of true positive rates for each class, plus the 
            micro-average.
        roc_auc: Dict of ROC-AUC scores for each class, plus the 
            micro-average.
    """
    assert(len(class_names) == y_true.shape[1])
    classes = y_true.shape[1]
    
    roc_auc = dict()
    fpr = dict()
    tpr = dict()
    
    for i, class_name in enumerate(class_names):
        
        if class_name != None:
            fpr[class_name], tpr[class_name], _ = roc_curve(
                y_true[:,i], y_pred[:,i])
            roc_auc[class_name] = auc(
                fpr[class_name], tpr[class_name])
    
    # Don't include no-connection class in micro-average        
    mask = np.ones(classes, dtype=bool)
    mask[mask.size//2 - 1 + mask.size%2] = 0
    
    fpr['micro-avg'], tpr['micro-avg'], _ = roc_curve(
        y_true[:,mask].ravel(), y_pred[:,mask].ravel())
    roc_auc['micro-avg'] = auc(fpr['micro-avg'], tpr['micro-avg'])
    
    return fpr, tpr, roc_auc


def multiclass_pr(y_true, y_pred, class_names=[]):
    """Computes the precision and recall for multiclass predictions.
    
    Args:
        y_true: True class labels, shape (examples, classes).
        y_pred: Predicted class scores, shape (examples, classes).
        class_names: List of class name strings, with NoneType to
            indicate the no-connection class - eg ['inh', None, 'xct'].
            
    Returns:
        precision: Dict of precision for each class, plus the 
            micro-average.
        recall: Dict of recall for each class, plus the micro-average.
    """
    assert(len(class_names) == y_true.shape[1])
    classes = y_true.shape[1]
    
    precision = dict()
    recall = dict()
    
    for i, class_name in enumerate(class_names):
        
        if class_name != None:
            precision[class_name], recall[class_name], _ = precision_recall_curve(
                y_true[:,i], y_pred[:,i])
            
    # Don't include no-connection class in micro-average                                                                              
    mask = np.ones(classes, dtype=bool)
    mask[mask.size//2 - 1 + mask.size%2] = 0
                                                                              
    precision['micro-avg'], recall['micro-avg'], _ = precision_recall_curve(
        y_true[:,mask].ravel(), y_pred[:,mask].ravel())
    
    return precision, recall


def default(obj):
    """Function to make JSON handle numpy arrays. This is useful for 
    saving dicts of metric scores in a format that is human readable but
    retains the dict structure."""
    if isinstance(obj, np.ndarray):
        return obj.tolist()
    raise TypeError('Object not serializable')