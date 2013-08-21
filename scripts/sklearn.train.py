#!/usr/bin/env python

import os, sys
import HTMLParser

lib_path = os.path.abspath('lib')
sys.path.append(lib_path)

import model

name = sys.argv.pop(0)
if len(sys.argv) < 3:
    print >> sys.stderr, "Usage: " + name + " <baseline|svm|knn|naive_bayes|log_regression> <ml_params> <model_path>"

h = HTMLParser.HTMLParser()
params = h.unescape(sys.argv[1])

model = model.Model(sys.argv[0],params)

X = []
Y = []

for line in sys.stdin:
    (y, x_str) = line.rstrip("\n").split("\t")
    x_list = x_str.split(" ")
    x_hash = { k:v for (k,v) in (tuple(s.split("=")) for s in x_list) }
    Y.append(y)
    X.append(x_hash)

model.fit(X,Y)
model.save(sys.argv[2])
