export M2_HOME="/opt/maven"
export M2="$M2_HOME/bin"

if [ -z "$PATH" ]; then
  export PATH=$M2
else
  export PATH="$PATH:$M2"
fi
