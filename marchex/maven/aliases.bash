alias mci='mvn clean install'
alias mcit='mvn clean install -DskipTests=true'
alias mcv='mvn clean verify'
alias mtp='mvn -DskipTests=true package'
alias muci='mvn -U clean install'
alias mucv='mvn -U clean verify'
alias mvo='mvn verify --offline'

# Liquibase commands
alias update='mvn --offline liquibase:update -e'
alias clearCheckSums='mvn --offline liquibase:clearCheckSums -e'
alias updateTestingRollback='mvn --offline liquibase:updateTestingRollback -e'

function rollback() {
  if [ $# -ne 1 ]
  then
    echo "Error: No number specified."
    return 1
  fi
  isNumber='^[0-9]+$'
  if [[ $1 =~ $isNumber ]] ; then
    mvn --offline liquibase:rollback -Dliquibase.rollbackCount=$1 -e
  else
    echo "'$1' is not a valid number"
  fi
}
