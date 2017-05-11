export SITE=/site

export PERL_VERSION=5.10.1

export PERL_PATH=$SITE/perl/perl-$PERL_VERSION-1/bin
export PERL=$PERL_PATH/perl

export PERL5LIB_BASE=$PERL:$ORACLE_HOME/$PERL_VERSION/lib:$SITE/perl/perl-$PERL_VERSION-1/lib

export PERL5LIB=$PERL5LIB_BASE:$SITE/perl/perl-$PERL_VERSION-1/lib/site_perl/$PERL_VERSION:$SITE/perl/perl-$PERL_VERSION-1/lib/site_perl/$PERL_VERSION-1/x86_64-linux

conditionally_prefix_path $PERL_PATH
