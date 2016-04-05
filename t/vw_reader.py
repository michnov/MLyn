#!/usr/bin/env python

import os, sys, getopt

lib_path = os.path.abspath('lib')
sys.path.append(lib_path)

from vw_data import VowpalWabbitData

in_data = VowpalWabbitData(ranking=True)
(X, Y) = in_data.read(sys.stdin)

print X
print Y
