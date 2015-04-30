#!/usr/bin/env python

import os, sys, getopt

lib_path = os.path.abspath('lib')
sys.path.append(lib_path)

import model
from vw_data import VowpalWabbitData

#from sklearn import tree
#import StringIO, pydot

def usage(app_name):
    print >> sys.stderr, "Usage: " + app_name + " [--ranking] <model_path>"

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
if len(args) < 1:
    usage(name)
    sys.exit(2)
model_path = args[0]

model = model.Model()
model.load(model_path) 

#dot_data = StringIO.StringIO()
#tree.export_graphviz(model.model, out_file=dot_data)
#graph = pydot.graph_from_dot_data(dot_data.getvalue()) 
#graph.write_pdf("graph.pdf") 

print >> sys.stderr, "Reading the data..."
in_data = VowpalWabbitData(ranking=ranking)
(X_all, Y, tags_all) = in_data.read(sys.stdin)

print >> sys.stderr, "Making predictions..."
for X in X_all:
    tags = tags_all.pop(0)
    losses = model.predict_loss(X)
    for i in range(0, len(X)):
        print str(i+1) + ":" + str(losses[i]) + " " + tags[i]
    print
