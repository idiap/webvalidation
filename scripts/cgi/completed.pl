#!/usr/bin/perl -w

# Copyright (c) 2014 Idiap Research Institute, http://www.idiap.ch/
# Written by Alexandre Nanchen <alexandre.nanchen@idiap.ch>,
# Christine Marcel <christine.marcel@idiap.ch>,
# Renato S. Martins

# This file is part of Webvalidation.

# Web validation is free software: you can redistribute it and/or modify
# it under the terms of the BSD 3-Clause License as published by
# the Open Source Initiative.

# Web validation is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# BSD 3-Clause License for more details.

# You should have received a copy of the BSD 3-Clause License
# along with Web validation. If not, see <http://opensource.org/licenses/>.

use strict;
use CGI::Pretty;
use File::Copy::Recursive qw(dirmove);
use Webvalidation qw(
	$website_url_domain $cgi_web_directory $media_url $data_directory
	dircontent print_navigation
);
use User;


my $cgi = new CGI;
# check if user is logged in
my $user = User::authenticate($cgi, 'admin');
unless ($user) {
	print $cgi->redirect($website_url_domain . $cgi_web_directory . 'login.pl');
}

my $project = $user->{project};
my $username = $user->{login};


###
# Print the directory content recursively. Depth will be incresed every time
# a recursion is made - this will set a `data` attribute in the div.
#
# $content (hashref): content of a directory (see Webvalidation.pm#dircontent)
###
sub print_divs {
	my ($content, $depth) = @_;
	$depth = 0 if (!defined($depth));
	my ($value, $is_dir, $type);
	for (sort(keys(%$content))) {
		$value = ${$content}{$_};
		# check if the value is a hash reference (ie. another directory)
		$is_dir = ref($value) eq 'HASH';
		$type = $is_dir ? 'folder' : 'file';
		print "<div class='$type' data-depth='$depth'><span class='name'>$_</span>\n";
		# if it is a directory use recursion to print it
		$is_dir && print_divs($value, $depth + 1);
		print "</div>\n";
	}
}


print $cgi->header(-type => 'text/html; charset=UTF-8');
print $cgi->start_html(
	-title => 'Completed',
	-encoding => 'utf-8',
	-style => [{
		-src	=> $media_url . 'css/mystyle.css',
		-type	=> 'text/css',
		-media	=> 'all'
	}],
	-script => [{
		-type	=> 'text/javascript',
		-src	=> $media_url . 'js/jquery.min.js'
	}, {
		-type	=> 'text/javascript',
		-src	=> $media_url . 'js/app.js'
	}]
);
print $cgi->body({-id => 'completedpage'});

print_navigation($cgi, 'completed.pl', $user);

print $cgi->start_div({-class => 'whitebox'});

print $cgi->start_div({-id => 'logo'});
print $cgi->img({
	-src	=> $media_url . 'images/Idiap-logo-E-small.png',
	-height	=> '40px'
});
print $cgi->end_div();

print $cgi->start_div({-id => 'top-page'});
print $cgi->p('Completed');
print $cgi->end_div();

print $cgi->start_div({-id => 'projectdiv'});
print $cgi->p($project);
print $cgi->end_div();

print $cgi->start_div({-id => 'completed', -class => 'bluebox'});
# dircontent called with infinite depth and don't ignore `accepted` & `refused`
print_divs(dircontent("${data_directory}${project}/completed", -1, 1));
print $cgi->end_div();

print $cgi->end_div();
print $cgi->end_html();
