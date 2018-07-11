#!/bin/sh
nohup sh -c "${IDEA_HOME}/bin/idea.sh \$*" > /dev/null 2>&1 &
