#!/usr/bin/env python

import os, sys

lib_path = os.path.abspath(os.environ['TMT_ROOT'] + '/personal/mnovak/ml_framework/lib')
sys.path.append(lib_path)

import model

#from sklearn import tree
#import StringIO, pydot

name = sys.argv.pop(0)
if len(sys.argv) < 2:
    print >> sys.stderr, "Usage: " + name + " <model_path> <params_path>"
    exit()

model = model.Model()
model.load(sys.argv[0])
model.print_params(sys.argv[1])
