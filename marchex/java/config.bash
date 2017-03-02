export JAVA6_HOME=/site/jdk/jdk1.6.0_37/
export JAVA7_HOME=/site/jdk/jdk1.7.0_17/
export JAVA8_HOME=/site/jdk/jdk1.8.0_60/
export JAVA_HOME=${JAVA8_HOME}
export IDEA_JDK=${JAVA8_HOME}

setjdk jdk1.8.0_60 &> /dev/null

conditionally_prefix_path "${JAVA_HOME}bin"
