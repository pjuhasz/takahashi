#!/usr/bin/perl

=pod

 Perl application to turn a simple text definition file into a latex beamer presentation.
 As this is intended for the so-called Takahashi style of presentation which consists of
 a few or even only one word (or perhaps an image or an equation) per slide,
 the text definition file is also very simple in structure.
 An example:

##################
 
Presentation

Takahashi method
perl script

Test
.image
osskilogo.pdf
.

Gnuplot test
.gnuplot
set logs
plot x
.

# Comment
Equation test
For example $5+5=10$

\[\sin(2x)=2\sin x \cos x\]

\TeX test
.tex
\begin{tabular}{ l | c || r | }
  \hline			
  1 & 2 & 3 \\
  4 & 5 & 6 \\
  7 & 8 & 9 \\
  \hline  
\end{tabular}
.

Test end

#####################

Comment lines begin with '#', they will be ignored.
Normal text in a line will be typeset in a line of their own in the presentation as well.
Font sizes are chosen so that the text fills up the viewing area.
Check the output and reword if you don't like the default layout.
Alternatively, manual font sizes are possible with the character '@'. 
If a normal line is terminated by the '@' char and an integer, 
then that integer will be substituted for the font size (in points) for that line. 
If the line is terminated with '@-' then the line will be typeset with the font size of the preceding line.
An empty line signifies a new slide.
The dot character (.) denotes special mode, which can be one of the following:
image, gnuplot and tex.

This is easily the worst piece of code I've ever written - and that is saying something, mind you.

=cut

use strict;
use warnings;
use utf8;
use Data::Dumper;
use File::Basename;

$|++;
my @slides;
my @current_slide;
my @slide_options;

my %layout;
$layout{scale_a} = 16;
$layout{scale_b} = 40;
$layout{scale_text} = 0.9;
$layout{plus_margin} = 0;
$layout{idiocy_factor} = 1.7;
$layout{default_fontsize} = 30;

my $delete_junk = 1;
my $delete_even_more_junk = 0;
my $redo_graphs = 1;
my $gnuplot_path = "/home/kikuchiyo/gnuplot43";
if (not -e $gnuplot_path) {
	$gnuplot_path = "gnuplot";
}

my %modes = (image => 'image', 'gnuplot*' => 'script', gnuplot => 'script', tex => 'line');
my @extlist = qw/ .txt .lst .dat .src /;
my $globalheader = <<'HEADER';
\documentclass[utf8x]{beamer}
\makeatletter
\insc@unt=60000
\makeatother
\usepackage{lmodern}
\usepackage[utf8x]{inputenc}
\usepackage[T1]{fontenc}
\def\magyarOptions{defaults=hu-min}
\usepackage[magyar]{babel}
%\usefonttheme[onlymath]{serif}
\usepackage{tikz}
%\usetikzlibrary{arrows,snakes,shapes}
%\usepackage[usenames,dvipsnames,x11names]{xcolor}

\setbeamertemplate{navigation symbols}{}
\setbeamercolor{whitetext}{fg=white}

\begin{document}

\setbeamerfont{text}{family=\sffamily}

HEADER


binmode STDOUT, ":encoding(UTF-8)";
binmode STDIN, ":encoding(UTF-8)";

die "Usage: [perl] takahashi.pl [options] file\n" unless @ARGV;
my $infn_orig = $ARGV[0];

open(my $infh, '<:encoding(UTF-8)', $infn_orig) || die "Error opening input\n";

while (<$infh>) {
	chomp;
	if (/^\./) { # start special mode
		my ($type_s) = /^\.(.*)/; 
		my $type;
		my $script;
		if ($type_s =~ /^gnuplot\*/) {
			$type = 'gnuplot*';
		} elsif ($type_s =~ /^gn?u?p?l?o?t?/) {
			$type = 'gnuplot';
		} elsif ($type_s =~ /^im?a?g?e?/) {
			$type = 'image';
		} elsif ($type_s =~ /^te?x?/) {
			$type = 'tex';
		} elsif ($type_s =~ /^se?t?/) {
			$type = 'none';
			my (undef, $opt, @optval) = split /\s+/, $type_s;
			if ($opt =~ /background/) {
				$slide_options[@slides]{background} = join " ", @optval;
			}
			
		} else {
			$type = 'none';
		}
		
		if ($type eq 'none') {
			# do nothing, exit special mode (no terminating .)
		}	
		elsif ($type eq 'image') {
			my $ifn = <$infh>;
			chomp $ifn;
			my $scale = <$infh>;
			chomp $scale;
			if ($scale =~ /^\.$/) {
				push @current_slide, {type => $type, $modes{$type} => $ifn};				
			} else {
				push @current_slide, {type => $type, $modes{$type} => $ifn, scale => $scale};
				$scale = <$infh>;
			}
		} else {
			while (<$infh>) {
				if (/^\./) {
					last;
				} else {
					$script .= $_;
				}
			}
			push @current_slide, {type => $type, $modes{$type} => $script} unless $type eq 'none';
		}

		
	} elsif (/^#/) { # comment line
		# ignore it 
	} elsif (!$_) { # empty line: new slide
		push @slides, [ @current_slide ] if @current_slide;
		$slides[-1][-1]{type} = 'tex' if $slides[-1][-1]{type} eq 'normal';
		#print Dumper \@current_slide;
		@current_slide = ();
	} elsif (/\\\[|\\\]|\$/) { # line containing TeX markup 
		my $type = 'normal';
		my $dollarcnt =()= /\$/sg;
		$type = 'normal' unless $dollarcnt % 2;
		$type = 'tex' if /\\begin|\\end/;
		my $brace_open =()= /\\\[\{/sg; my $brace_close =()= /\\\]/sg;
		$type = 'tex' if $brace_open != $brace_close;
		$brace_open =()= /\{/sg; $brace_close =()= /\}/sg;
		$type = 'tex' if $brace_open != $brace_close;
		if (/\s\@(?:\d+|-)\s*$/) {
			#print;
			my ($forcedsize) = /\s\@(\d+|-)\s*$/;
			s/\s\@(?:\d+|-)\s*$//;
			push @current_slide, {type => 'normal', line => $_, forcedsize => $forcedsize};
		} else {
			push @current_slide, {type => $type, line => $_};
		}		
		#push @current_slide, {type => $type, line => $_};
	} else { # normal line: append it to current slide
		if (/\s\@(?:\d+|-)\s*$/) {
			#print;
			my ($forcedsize) = /\s\@(\d+|-)\s*$/;
			s/\s\@(?:\d+|-)\s*$//;
			push @current_slide, {type => 'normal', line => $_, forcedsize => $forcedsize};
		} else {
			push @current_slide, {type => 'normal', line => $_};
		}
	}
}
close $infh;

#print Dumper \@slides, \@slide_options;
# get output filename from ARGV, change to tex, open file

my ($infn, $path, $ext) = fileparse($infn_orig, @extlist);
my $tempfnbase = $infn."!temp";
my $tempfn = $tempfnbase.".tex";
my ($ifh, $ofh);

my $sr = latex(\@slides, 1);

open($ofh, '>:encoding(UTF-8)', $tempfn) || die "Error opening temporary file\n";
print $ofh $$sr;
close $ofh;

system('pdflatex', "-interaction=batchmode", $tempfn);

open($ifh, '<:encoding(UTF-8)', $tempfnbase.".log") || die "Error reading log\n";
my $logfile = do { local $/; <$ifh> };
close $ifh;

#print Dumper \@slides;
#print '!';
parse_log(\@slides, \$logfile);
#print Dumper \@slides;

$sr = latex(\@slides, 2);
my $ofn = $infn.".tex";
open($ofh, '>:encoding(UTF-8)', $ofn) || die "Error opening temporary file\n";
print $ofh $$sr;
close $ofh;
system('pdflatex', "-interaction=batchmode", $ofn);
system('pdflatex', "-interaction=batchmode", $ofn);

if ($delete_junk) {
	unlink <*.toc>; unlink <*.aux>; unlink <*.nav>; unlink <*.snm>; unlink <*.out>;
}

if ($delete_even_more_junk) {
	unlink <*.plt>; unlink <*.log>; unlink <*!temp.*>; unlink <*!*.pdf>;
}

####################################################x

sub parse_log {
	my $slides = shift;
	my $logfile = shift;
	
	my $counter = 0;
	#print $$logfile;
	my ($textwidth) = $$logfile =~ /^\> (\d+\.\d+)pt\.\nl\.\d+ \\showthe\s*\\textwidth/ms;
	my ($textheight) = $$logfile =~ /^\> (\d+\.\d+)pt\.\nl\.\d+ \\showthe\s*\\textheight/ms;
	#print "$textwidth, $textheight\n";
	foreach my $slide (@$slides) {
		my $maxwidth = 0;
		my $totalheight = 0;
		my ($xscale, $yscale, $scale);
		foreach my $line ( @$slide ){
				my $code = $line->{numeral};
				#print $line->{numeral};
				($line->{width}) = ($$logfile =~ /^\> (\d+\.\d+)pt.{30,40}?\\showthe\s*\\wz$code/ms);
				($line->{height}) = ($$logfile =~ /^\> (\d+\.\d+)pt.{30,40}?\\showthe\s*\\hz$code/ms);
				#print "$code, $line->{width}, $line->{height}, $-[0] \n";	
				$maxwidth = $line->{width} if $line->{width} > $maxwidth;
				$totalheight += stupid_scaling_func($line->{height});
		}
		if ($maxwidth == 0 or $totalheight == 0) {
			$scale = 1;
			my $errortext = substr($slide->[0]{ $modes{ $slide->[0]{type} } }, 0, 30);
			$errortext =~ s/\n/ /msg;
			print STDERR "!!! PDFLaTeX shat itself at code $slide->[0]{numeral}: \"$errortext...\"\n";
		} else {
			$xscale = ($textwidth - 2 * $layout{plus_margin}) / $maxwidth;
			$yscale = ($textheight - 2 * $layout{plus_margin}) / ($totalheight * $layout{idiocy_factor});
			$scale = ($xscale<$yscale) ? $xscale : $yscale;
		}
		unshift @$slide, {fontsize => int($layout{default_fontsize}*$scale)};
	}
}

sub latex {
	my $slides = shift;
	my $pass = shift || 2;
	my $latex = $globalheader;
	if ($pass == 1) {
		$latex .= '\showthe\textwidth'."\n";
		$latex .= '\showthe\textheight'."\n";
		#$latex .= '\newlength{\tw}'."\n";
		#$latex .= '\newlength{\thei}'."\n";
		#$latex .= '\newsavebox{\mybox}'."\n";
		#$latex .= '\newcommand{\mybox}{}'."\n";
	}
	my $counter = 0;
	my $saved_fontsize;
	
	foreach my $i (0..$#$slides) {
		my $slide = $slides->[$i];
		
		if (exists $slide_options[$i]{background}) {
			$latex .= '\setbeamercolor{normal text}{bg=' . $slide_options[$i]{background} . "}\n";
		}
		
		$latex .= '\begin{frame}'."\n";
		$latex .= '\begin{center}'."\n";
		
		my $fontsize;
		if (exists $slide->[0]{fontsize}) {
			$fontsize = $slide->[0]{fontsize};
			shift @$slide;
		} else {
			$fontsize = $layout{default_fontsize};
		}
		$latex .= '\fontsize{'.$fontsize.'}{'.stupid_scaling_func($fontsize).'}\selectfont ' ;#."\n";
		
		#$latex .= '\sbox{\mybox}{%'."\n" if $pass == 1;
		#$latex .= '\newcommand{\mybox'.numeral($counter).'}{%'."\n" if $pass == 1;
		#print Dumper $slide;
		foreach my $line ( @$slide ){
			#print $line->{forcedsize} if exists $line->{forcedsize};
			if ($line->{type} eq "normal") {
				if ($pass == 2) {
					if (exists $line->{forcedsize}) {
						if ($line->{forcedsize} eq '-') {
							$latex .= '\fontsize{'.$saved_fontsize.'}{'.
								stupid_scaling_func($saved_fontsize).'}\selectfont ' ;#."\n";
							$latex .= $line->{line}."\\\\\n";
							$latex .= '\fontsize{'.$fontsize.'}{'.
								stupid_scaling_func($fontsize).'}\selectfont'."\n" unless $line == $slide->[-1];							
						} else {
							$latex .= '\fontsize{'.$line->{forcedsize}.'}{'.
								stupid_scaling_func($line->{forcedsize}).'}\selectfont ' ;#."\n";
							$latex .= $line->{line}."\\\\\n";
							$latex .= '\fontsize{'.$fontsize.'}{'.
								stupid_scaling_func($fontsize).'}\selectfont'."\n" unless $line == $slide->[-1];
							$saved_fontsize = $line->{forcedsize};
						}
					} else {
						$latex .= $line->{line}."\\\\\n";
						$saved_fontsize = $fontsize;
					}

				} else {
					$line->{numeral} = numeral($counter);
					$latex .= '\newlength{\wz'.numeral($counter)."}\n";
					$latex .= '\newlength{\hz'.numeral($counter)."}\n";
					$latex .= '\settowidth{\wz'.numeral($counter).'}{'.accent2tex($line->{line})."\\\\}\n";
					$latex .= '\showthe\wz'.numeral($counter)."\n";
					$latex .= '\settoheight{\hz'.numeral($counter).'}{'.accent2tex($line->{line})."\\\\}\n";
					$latex .= '\showthe\hz'.numeral($counter)."\n";
					$counter++;
					$latex .= accent2tex($line->{line})."\\\\\n";
				}
			} elsif ($line->{type} eq "tex") {
				if ($pass == 2) {
					if (exists $line->{forcedsize}) {
						if ($line->{forcedsize} eq '-') {
							$latex .= '\fontsize{'.$saved_fontsize.'}{'.
								stupid_scaling_func($saved_fontsize).'}\selectfont ' ;#."\n";
							$latex .= $line->{line}."\n";
							$latex .= '\fontsize{'.$fontsize.'}{'.
								stupid_scaling_func($fontsize).'}\selectfont'."\n" unless $line == $slide->[-1];							
						} else {
							$latex .= '\fontsize{'.$line->{forcedsize}.'}{'.
								stupid_scaling_func($line->{forcedsize}).'}\selectfont ' ;#."\n";
							$latex .= $line->{line}."\n";
							$latex .= '\fontsize{'.$fontsize.'}{'.
								stupid_scaling_func($fontsize).'}\selectfont'."\n" unless $line == $slide->[-1];
							$saved_fontsize = $line->{forcedsize};
						}
					} else {
						$latex .= $line->{line}."\n";
						$saved_fontsize = $fontsize;
					}

				} else {
					$line->{numeral} = numeral($counter);
					$latex .= '\newlength{\wz'.numeral($counter)."}\n";
					$latex .= '\newlength{\hz'.numeral($counter)."}\n";
					$latex .= '\settowidth{\wz'.numeral($counter).'}{'.accent2tex($line->{line})."}\n";
					$latex .= '\showthe\wz'.numeral($counter)."\n";
					$latex .= '\settoheight{\hz'.numeral($counter).'}{'.accent2tex($line->{line})."}\n";
					$latex .= '\showthe\hz'.numeral($counter)."\n";
					$counter++;
					$latex .= accent2tex($line->{line})."\n";
				}
			} elsif ($line->{type} eq "image") {
				if ($pass == 2) {
					$latex .= image($line->{image}, $line->{scale}) if -e $line->{image};
				} elsif (-e $line->{image}) {
					$line->{numeral} = numeral($counter);
					$latex .= '\newlength{\wz'.numeral($counter)."}\n";
					$latex .= '\newlength{\hz'.numeral($counter)."}\n";
					$latex .= '\settowidth{\wz'.numeral($counter).'}{'.image($line->{image}, $line->{scale})."}\n";
					$latex .= '\showthe\wz'.numeral($counter)."\n";
					$latex .= '\settoheight{\hz'.numeral($counter).'}{'.image($line->{image}, $line->{scale})."}\n";
					$latex .= '\showthe\hz'.numeral($counter)."\n";
					$counter++;
					$latex .= image($line->{image}, $line->{scale})."\n";
				}
				
			} elsif ($line->{type} =~ /gnuplot/) {
				my $gnuplot_image;
				if ($pass == 1) {
					$gnuplot_image = gnuplot($line->{script}, ($line->{type} =~ /\*/)?1:0, numeral($counter));
					$line->{image} = $gnuplot_image;
					$line->{numeral} = numeral($counter);
					$line->{scale} = 1.0;
					$latex .= '\newlength{\wz'.numeral($counter)."}\n";
					$latex .= '\newlength{\hz'.numeral($counter)."}\n";
					$latex .= '\settowidth{\wz'.numeral($counter).'}{'.image($line->{image}, $line->{scale})."}\n";
					$latex .= '\showthe\wz'.numeral($counter)."\n";
					$latex .= '\settoheight{\hz'.numeral($counter).'}{'.image($line->{image}, $line->{scale})."}\n";
					$latex .= '\showthe\hz'.numeral($counter)."\n";
					$counter++;
					$latex .= image($line->{image}, $line->{scale});					
				} else {
					
					$latex .= image($line->{image}, $line->{scale}) if -e $line->{image};
				}
			}
		}
		

		$latex .= '\end{center}'."\n";
		$latex .= '\end{frame}'."\n\n";
		#$counter++;
	}
	$latex .= '\end{document}'."\n";
	return \$latex;
}

sub gnuplot {
	my $script = shift;
	my $noheader = shift || 0;
	my $code = shift || 'xxx';
	my ($gpfh, $gpfn, $gpimfn);	
	
	#print "$noheader, $code\n";
	$gpfn = $infn.'!'.$code.'.plt';
	$gpimfn = $infn.'!'.$code.'.pdf';
	unless (!$redo_graphs and -e $gpimfn) {
		my $gnuplot_header1 = <<"GNUPLOTHEADER1";
set term pdfcairo enh font "LM Sans 10, 12" fontscale 1 lw 2
set out '$gpimfn';
GNUPLOTHEADER1

		my $gnuplot_header2 = <<"GNUPLOTHEADER2";
set out
GNUPLOTHEADER2

		open($gpfh, '>:encoding(UTF-8)', $gpfn) || die "Error opening temporary file\n";
		if ($noheader) {
			$script =~ s/set out \*/set out '$gpimfn'/;
		}
		print $gpfh $gnuplot_header1 unless $noheader;
		print $gpfh $script;
		print $gpfh $gnuplot_header2 unless $noheader;	
		close $gpfh;
	
		system($gnuplot_path, $gpfn);
	}
	return $gpimfn;
}

sub image {
	my $ifn = shift;
	my $scale = shift || 0.7;
	return '\includegraphics[width='.$scale.'\textwidth]{'.$ifn."}\n";
}

sub numeral {
	#my @digits = qw|zero one two three four five six seven eight nine|;
	my @digits = qw|a b c d e f g h i j|;
	return join 'x', map $digits[$_], split(//, $_[0]);
	
}

sub stupid_scaling_func {
	return int($_[0]+$layout{scale_a}*(1-2/(1+exp(2*$_[0]/$layout{scale_b}))));
}

# This shit is needed because pdflatex is a buggy piece of crap 
# that prints malformed utf-8 into its log file.
sub accent2tex {
	#shift;
	local $_=$_[0];
	s/á/\\'a/g;
	s/é/\\'e/g;
	s/í/\\'\{\\i\}/g;
	s/ó/\\'o/g;
	s/ú/\\'u/g;
	s/ö/\\"o/g;
	s/ü/\\"u/g;
	s/ő/\\H\{o\}/g;
	s/ű/\\H\{u\}/g;
	s/Á/\\'A/g;
	s/É/\\'E/g;
	s/Í/\\'I/g;
	s/Ó/\\'O/g;
	s/Ú/\\'U/g;
	s/Ö/\\"O/g;
	s/Ü/\\"U/g;
	s/Ő/\\H\{O\}/g;
	s/Ű/\\H\{U\}/g;
	return $_;
}
