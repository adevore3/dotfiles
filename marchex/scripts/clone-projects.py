# -*- coding: utf-8 -*-
from sys import argv
import subprocess
import os

script, filename = argv
print "Running %r with file %r\n" % (script, filename)

with open(filename, 'r') as f:
    lines = [line.strip() for line in f]
    for project in lines:
        repo = project.split("/")[1].split(".")[0]
        print "Working on repo %r" % repo
        if os.path.exists(repo):
            print "%r already exists" % repo
        else:
            try:
                subprocess.check_output(['git', 'clone', project])
                print "SUCCESS: when cloning %r" % repo
            except subprocess.CalledProcessError as e:
                print "FAILED: when cloning %r" % repo
                print e.output
        print '\n'

