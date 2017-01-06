function oraprod () {
    USER="$1"
    PASS="$2"
    if [ -z $USER ]; then
      echo -n "Username: "
      stty -echo
      read USER
      stty echo
      echo
    fi;
    if [ -z $PASS ]; then
      echo -n "Password: "
      stty -echo
      read PASS
      stty echo
      echo
    fi;
    rlwrap $ORACLE_HOME/bin/sqlplus ${USER}/${PASS}@OPNEXT
}

function oraqa () {
    USER="$1"
    PASS="$2"
    if [ -z $USER ]; then
      echo -n "Username: "
      stty -echo
      read USER
      stty echo
      echo
    fi;
    if [ -z $PASS ]; then
      echo -n "Password: "
      stty -echo
      read PASS
      stty echo
      echo
    fi;
    rlwrap $ORACLE_HOME/bin/sqlplus ${USER}/${PASS}@OQ3NEXT
}

function oradev () {
    DEV="$1"
    USER="$2"
    PASS="$3"
    if [ -z $DEV ]; then
      echo -n "ODNEXT instance (some numeric number ie '34'): "
      stty -echo
      read DEV
      stty echo
      echo
    fi;
    if [ -z $USER ]; then
      echo -n "Username: "
      stty -echo
      read USER
      stty echo
      echo
    fi;
    if [ -z $PASS ]; then
      echo -n "Password: "
      stty -echo
      read PASS
      stty echo
      echo
    fi;
    rlwrap $ORACLE_HOME/bin/sqlplus "$2/$3@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=odnextx.qa.marchex.com)(PORT=7352))(CONNECT_DATA=(SERVICE_NAME=ODNEXT$1)))"
}
