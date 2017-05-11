export SITE=/site
export NEXT=$SITE/next
export NIM=$SITE/nim
export DCM=/home/adevore/repos/mcm/dcm

export MYSQL_VERSION=5.5.22
export ORACLE_VERSION=11_2
export JAVA_VERSION=1.8.0_60
export APACHE_VERSION=2.2.14-1
export PERL_VERSION=5.10.1

export PERL_PATH=$SITE/perl/perl-$PERL_VERSION-1/bin
export PERL=$PERL_PATH/perl

export PERL5LIB_BASE=$PERL:$SITE/perllibs-xml/$PERL_VERSION/lib:$APACHE/lib/perl:$ORACLE_HOME/$PERL_VERSION/lib:$SITE/perllibs-dev/lib:$SITE/perl/perl-$PERL_VERSION-1/lib
export PERL5LIB_NEXT=$NEXT/shared/perl:$SITE/perllibs-next/lib
export PERL5LIB_NIM=$NIM/shared/perl:$SITE/perllibs-nim/lib
export PERL5LIB_DCM=$DCM/shared/perl:$SITE/perllibs-dcm/lib

export PERL5LIB="$PERL5LIB_NEXT:$PERL5LIB_NIM:$PERL5LIB_DCM:$PERL5LIB_BASE"
export PERL5LIB=$PERL5LIB:/site/perl/perl-5.10.1-1/lib/site_perl/5.10.1:/site/perl/perl-5.10.1-1/lib/site_perl/5.10.1/x86_64-linux

export PATH=$SITE/perllibs-dcm/bin:$SITE/perllibs-nim/bin:$SITE/perllibs-next/bin:$DCM/database/primary/util/lib:$PERL_PATH:$PATH
