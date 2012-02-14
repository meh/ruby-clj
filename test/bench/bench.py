#! /usr/bin/env python

import clj
import time

s = "[1 2 3 true false nil {:a 21.3 :b 43.2} \"Hello\"]"

t1 = time.time()
for i in range(10000):
  clj.loads(s)

print time.time()-t1
