#!/usr/bin/env python

import os, sys

lib_path = os.path.abspath('lib')
sys.path.append(lib_path)

import model

#from sklearn import tree
#import StringIO, pydot

name = sys.argv.pop(0)
if len(sys.argv) < 1:
    print >> sys.stderr, "Usage: " + name + " <model_path>"

model = model.Model()
model.load(sys.argv[0]) 

#dot_data = StringIO.StringIO()
#tree.export_graphviz(model.model, out_file=dot_data)
#graph = pydot.graph_from_dot_data(dot_data.getvalue()) 
#graph.write_pdf("graph.pdf") 


X = []
y_pred = []
y = []

#i = 0
for line in sys.stdin:
    #if i % 1000 == 0:
    #    print >> sys.stderr, "Line no. " + str(i)
    #i += 1
    (y, x_str) = line.rstrip("\n").split("\t")
    x_list = x_str.split(" ")
    x_hash = { k:v for (k,v) in (tuple(s.split("=")) for s in x_list) }
    y_pred = model.predict(x_hash)
    print y + "\t" + str(y_pred[0])
