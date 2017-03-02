export M3_HOME="/opt/maven"
export M3="$M3_HOME/bin"

if [ -z "$PATH" ]; then
  export PATH=$M3
else
  export PATH="$PATH:$M3"
fi
