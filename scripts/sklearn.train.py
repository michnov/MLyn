#!/usr/bin/env python

import os, sys, getopt
import HTMLParser

lib_path = os.path.abspath('lib')
sys.path.append(lib_path)

import model
from vw_data import VowpalWabbitData

def usage(app_name):
    print >> sys.stderr, "Usage: " + app_name + " [--ranking] <baseline|svm|knn|naive_bayes|log_regression> <ml_params> <model_path>"

# command line args parsing
name = sys.argv.pop(0)
try:
    optlist, args = getopt.getopt(sys.argv, '', ['ranking'])
except getopt.GetoptError as err:
    print str(err) # will print something like "option -a not recognized"
    usage(name)
    sys.exit(2)
ranking = False
for o,a in optlist:
    if o == '--ranking':
        ranking = True
    else:
        assert False, "unhandled option"
if len(args) < 3:
    usage(name)
    sys.exit(2)
ml_type = args[0]
ml_param_str = args[1]
model_path = args[2]

print >> sys.stderr, "Reading the data..."
X = []
Y = []
in_data = VowpalWabbitData(ranking=ranking)
(X, Y) = in_data.read(sys.stdin)

print >> sys.stderr, "Building the model..."
h = HTMLParser.HTMLParser()
params = h.unescape(ml_param_str)
model = model.Model(ml_type,params)
model.fit(X,Y)
model.save(model_path)
