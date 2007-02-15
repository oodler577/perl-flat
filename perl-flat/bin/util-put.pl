#! perl

use strict;
use warnings;
use Config;
use File::Copy;

# copys bin/f@sh to system bin directory and ensures its is 755

if (-w $Config{installbin})
 { print "Installing f\@sh utility in $Config{installbin}\n";
   copy('bin/fash',"$Config{installbin}/fash") || die $!; 
   chmod 0755,"$Config{installbin}/fash";}
else
 { print "You do not have permission to write to $Config{installbin}\n";
   print "Warn: bin/f\@sh not installed to $Config{installbin}\n";}

1;
