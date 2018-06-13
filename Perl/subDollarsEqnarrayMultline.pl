#!/usr/bin/perl

use strict;
use warnings;           
use File::Copy;         # to copy the original file to backup (if overwrite option set)
use Getopt::Std;        # to get the switches/options/flags

# get the options
my %options=();
getopts("wos", \%options);

# standard output
my $out = *STDOUT;

# overwrite option
my $overwrite = 0;
$overwrite = $options{w};

# output file option
my $outputToFile = $options{o};

# can't call the script with MORE THAN 2 files
if(scalar(@ARGV)>2)
{
print $out <<ENDQUOTE

ERROR:
\t You're calling subDollars.pl with more than two file names
\t The script can take at MOST two file names, but you 
\t need to call it with the -o switch; for example

\t subDollars.pl -o originalfile.tex outputfile.tex

Exiting...
ENDQUOTE
;
    exit(2);
}

# check for output file
if($outputToFile and scalar(@ARGV)==1)
{
print $out <<ENDQUOTE
ERROR: When using the -o flag you need to call this script with 2 arguments

subDollars.pl -o "$ARGV[0]" [needs another name here]

Exiting...
ENDQUOTE
;
    exit(2);
}

# don't call the script with 2 files unless the -o flag is active
if(!$outputToFile and scalar(@ARGV)==2)
{
print $out <<ENDQUOTE

ERROR:
\t You're calling subDollars.pl with two file names, but not the -o flag.
\t Did you mean to use the -o flag ?

Exiting...
ENDQUOTE
;
    exit(2);
}

# array to store the modified lines
my @lines;

# hash naming environments that contain lines 
# that should not be substituted
my %nosubstitutions = ("tikzpicture"=>1, "verbatim"=>1, "nosubblock"=>1);

# switch to toggle nosubstitutions- initially off
my $nosubs = 0;

# switch to toggle inline formula split on more lines- initially off
my $splitinline = 0;

# switch to toggle displayed formula split on more lines- initially off
my $splitdisplayed = 0;

# switch to toggle eqnarray split on more lines- initially off
my $eqnarraylab = 0;

# switch to toggle eqnarray* split on more lines- initially off
my $eqnarraynolab = 0;


# if we want to overwrite the current file
# create a backup first
if ($overwrite)
{
    # original name of file
    my $filename = $ARGV[0];
    # copy it
    my $backupFile = $filename;
    my $backupExtension='.bak';

    $backupFile =~ s/\.tex/$backupExtension/;

    copy($filename,$backupFile) or die "Could not write to backup file $backupFile. Please check permissions. Exiting.\n";
}

# open the file
open(MAINFILE, $ARGV[0]) or die "Could not open input file";

# loop through the lines in the INPUT file
while(<MAINFILE>)
{
    # check for BEGIN of an environment that doesn't want substitutions
    $nosubs = 1 if( $_ =~ m/^\s*\\begin\{(.*?)}/ and $nosubstitutions{$1} );

    # check for %\begin{nosubblock}
    $nosubs = 1 if( $_ =~ m/^\s*%\s*\\begin\{(.*?)}/ and $nosubstitutions{$1} );

    # check for END of an environment that doesn't want substitutions
    $nosubs = 0 if( $_ =~ m/^\s*\\end\{(.*?)}/ and $nosubstitutions{$1});

    # check for %\end{nosubblock}
    $nosubs = 0 if( $_ =~ m/^\s*%\s*\\end\{(.*?)}/ and $nosubstitutions{$1} );

 
    # if split from previous line, check if closing environment command is present;
    # if yes, close environment and reset corresponding flag
    if ($splitdisplayed) 
    {
    	if(/\$\$/)
	{
		s/\$\$/\\\]/ unless ($nosubs);
		$splitdisplayed = 0;
	}
    } elsif ($splitinline)
    {
    	if(/\$/)
	{
		s/\$/\\\)/ unless ($nosubs);
		$splitinline = 0;
	}   
    } elsif ($eqnarraylab)
    {
    	if(/\\end\{eqnarray\}/)
	{
		s/\\end\{eqnarray\}/\\end\{aligned\}\\end\{equation\}/ unless ($nosubs);
		$eqnarraylab = 0;
	}   
    } elsif ($eqnarraynolab)
    {
    	if(/\\end\{eqnarray\*\}/)
	{
		s/\\end\{eqnarray\*\}/\\end\{aligned\}\\end\{equation\*\}/ unless ($nosubs);
		$eqnarraynolab = 0;
	}   
    }
 
    # substitute \begin{eqnarray}.*\end{eqnarray* with \begin{equation}\begin{aligned}.*\end{aligned}\end{equation}
    s/\\begin\{eqnarray\}(.*?)\\end\{eqnarray\}/\\begin\{equation\}\\begin\{aligned\}$1\\end\{aligned\}\\end\{equation\}/g unless($nosubs);

    # substitute \begin{eqnarray*}.*\end{eqnarray*} with \begin{equation*}\begin{aligned}.*\end{aligned}\end{equation*}
    s/\\begin\{eqnarray\*\}(.*?)\\end\{eqnarray\*\}/\\begin\{equation*\}\\begin\{aligned\}$1\\end\{aligned\}\\end\{equation*\}/g unless($nosubs);

    # substitute $.*$ with \(.*\) 
    # note: this does NOT match $$.*$$
    s/(?<!\$)\$([^\$].*?)\$/\\\($1\\\)/g unless($nosubs);

    # substitute $$.*$$ with \[.*\]
    s/\$\$(.*?)\$\$/\\\[$1\\\]/g unless($nosubs);
 
    # check if environment opens and splits on next line(s)
    # if yes, open environment and set corresponding flag
    if (/\$\$/)
    {
    	s/\$\$/\\\[/ unless ($nosubs);
	$splitdisplayed = not $nosubs;
    } elsif (/\$/)
    {
	s/\$/\\\(/ unless ($nosubs);
	$splitinline = not $nosubs;
    } elsif (/\\begin\{eqnarray\}/)
    {
	s/\\begin\{eqnarray\}/\\begin\{equation\}\\begin\{aligned\}/ unless ($nosubs);
	$eqnarraylab = not $nosubs;
    } elsif (/\\begin\{eqnarray\*\}/)
    {
	s/\\begin\{eqnarray\*\}/\\begin\{equation\*\}\\begin\{aligned\}/ unless ($nosubs);
	$eqnarraynolab = not $nosubs;
    }
     
    push(@lines,$_);

}

# output the formatted lines to the terminal
print @lines if(!$options{s});

# if -w is active then output to $ARGV[0]
if($overwrite)
{
    open(OUTPUTFILE,">",$ARGV[0]);
    print OUTPUTFILE @lines;
    close(OUTPUTFILE);
}

# if -o is active then output to $ARGV[1]
if($outputToFile)
{
    open(OUTPUTFILE,">",$ARGV[1]);
    print OUTPUTFILE @lines;
    close(OUTPUTFILE);
}

exit;