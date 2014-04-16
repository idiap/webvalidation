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
my $user = User::authenticate($cgi);
unless ($user) {
	print $cgi->redirect($website_url_domain . $cgi_web_directory . 'login.pl');
}

my $project = $user->{project};
my $username = $user->{login};


###
# Print the folder names inside subdirectories of the annotation space.
# Each entry is an anchor element with an `href` to this same script and a
# `GET` parameter ('first' or 'second') with the folder name as its value.
#
# $level (string): 'first' or 'second'
# $content (hashref): content of a directory (see Webvalidation.pm#dircontent)
###
sub print_data_entries {
	my ($level, $content) = @_;
	my $url = "${cgi_web_directory}validate_sentences.pl"
		. "?level=${level}"
		. "&dataPath=${project}/user_space/${username}/${level}/";
	for (keys(%$content)) {
		print $cgi->a({-href => $url . $_}, $_);
		# print the number of sentences inside the folder
		# it's divided by 2 because each sentence have a wav and txt
		print $cgi->span({-class => 'elements'}, '[' . scalar(keys(%{$content->{$_}}))/2 . ']');
		print $cgi->br();
	}
}


print $cgi->header(-type => 'text/html; charset=UTF-8');
print $cgi->start_html(
	-title => 'User Space',
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
print $cgi->body({-id => 'userpage'});

print_navigation($cgi, 'user_space.pl', $user);

print $cgi->start_div({-id => 'validation', -class => 'whitebox'});

print $cgi->start_div({-id => 'logo'});
print $cgi->img({
	-src	=> $media_url . 'images/Idiap-logo-E-small.png',
	-height	=> '40px'
});
print $cgi->end_div();

print $cgi->start_div({-id => 'top-page'});
print $cgi->p("User Space - $username");
print $cgi->end_div();

print $cgi->start_div({-id => 'projectdiv'});
print $cgi->p($project);
print $cgi->end_div();

# first
print $cgi->start_div({-id => 'first-validation', -class => 'bluebox'});
print $cgi->h3('First Validation');
print_data_entries(
	'first',
	dircontent("${data_directory}${project}/user_space/${username}/first", 1)
);
print $cgi->end_div();

# second
print $cgi->start_div({-id => 'second-validation', -class => 'bluebox'});
print $cgi->h3('Second Validation');
print_data_entries(
	'second',
	dircontent("${data_directory}${project}/user_space/${username}/second", 1)
);
print $cgi->end_div();

print $cgi->end_div();
print $cgi->end_html();
