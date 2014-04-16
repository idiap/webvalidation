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
use File::Basename;
use Webvalidation qw(
	$website_url_domain $cgi_web_directory $media_url $data_directory
	dircontent move_directory print_navigation print_loading_layer print_messages
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
my $first = $cgi->param('first');
my $second = $cgi->param('second');
my $chosen_data = $first || $second;


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
	my $url = "${cgi_web_directory}annotation_space.pl?${level}=";
	for (keys(%$content)) {
		print $cgi->a({-href => $url . $_}, $_);
		# print the number of sentences inside the folder
		# it's divided by 2 because each sentence have a wav and txt
		print $cgi->span({-class => 'elements'}, '[' . scalar(keys(%{$content->{$_}}))/2 . ']');
		print $cgi->br();
	}
}


sub print_annotation_page {
	my @msgs = @_;
	print $cgi->header(-type => 'text/html; charset=UTF-8');
	print $cgi->start_html(
		-title => 'Annotation Space',
		-encoding => 'utf-8',
		-style => [{
			-src	=> $media_url . 'css/mystyle.css',
			-type	=> 'text/css',
			-media	=> 'all'
		}],
		-script => [{
			-src	=> $media_url . 'js/jquery.min.js',
			-type	=> 'text/javascript'
		}, {
			-type	=> 'text/javascript',
			-src	=> $media_url . 'js/app.js'
		}]
	);

	print $cgi->body({-id => 'annotationpage'});

	print_navigation($cgi, 'annotation_space.pl', $user);
	print_messages($cgi, @msgs);

	print $cgi->start_div({-id => 'validation', -class => 'whitebox'});

	print $cgi->start_div({-id => 'logo'});
	print $cgi->img({
		-src => $media_url . 'images/Idiap-logo-E-small.png',
		-height => '40px'
	});
	print $cgi->end_div();

	print $cgi->start_div({-id => 'projectdiv'});
	print $cgi->p($project);
	print $cgi->end_div();

	print $cgi->start_div({-id => 'top-page'});
	print $cgi->p('Annotation Space');
	print $cgi->end_div();

	print $cgi->start_div({-id => 'first-validation', -class => 'bluebox'});
	print $cgi->h3('First Validation');
	print_data_entries(
		'first',
		dircontent($data_directory . $project . '/annotation_space/first', 1)
	);
	print $cgi->end_div();

	print $cgi->start_div({-id => 'second-validation', -class => 'bluebox'});
	print $cgi->h3('Second Validation');
	print_data_entries(
		'second',
		dircontent($data_directory . $project . '/annotation_space/second', 1)
	);
	print $cgi->end_div();

	print $cgi->end_div();
	print_loading_layer($cgi);
	print $cgi->end_html;
}


###
# Move given directory to user_space and redirect to the edit tool.
#
# $level (string): 'first' or 'second'
# $chosen_data (string): name of the data folder
###
sub handle_move_request {
	my ($level, $chosen_data) = @_;
	my $new_chosen_data = "${chosen_data}_${username}";
	my $annotation_space = $data_directory . $project . '/annotation_space/';
	my $user_space = $data_directory . $project . "/user_space/${username}/";
	my $source = $annotation_space . "${level}/${chosen_data}";
	# when moving folders, the username should be appended to it so we know
	# which user did the first and second validations
	my $destination = $user_space . "${level}/${new_chosen_data}";
	# move directory to user space
	if (-d $source){
		move_directory($source, $destination);
		print $cgi->redirect(
			$website_url_domain . $cgi_web_directory . 'user_space.pl'
		);
	}
	else {
		print_annotation_page('Data doesn\'t exist');
	}
}


# move given directory to user_space/<user>/first
if ($first) {
	handle_move_request('first', $chosen_data);
}
# move given directory to user_space/<user>/second
elsif ($second) {
	handle_move_request('second', $chosen_data);
}
else {
	print_annotation_page();
}
