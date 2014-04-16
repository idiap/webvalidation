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
use Webvalidation qw(
	$website_url_domain $cgi_web_directory $media_url $data_directory
	@projects
	print_navigation print_messages array_has dircontent
);
use User;
use Stats;
use Time::Piece;


###
# THIS PAGE IS DEPRECATED
###


my $cgi = new CGI;
# only admins can view statistics
my $user = User::authenticate($cgi, 'admin');
unless ($user) {
	print $cgi->redirect($website_url_domain . $cgi_web_directory . 'login.pl');
}

my $user_filter = $cgi->param('user');
my $date_filter = $cgi->param('date');
my $level_filter = $cgi->param('level');
my $acceptance_filter = $cgi->param('acceptance');

# default values
$user_filter = undef unless (defined($user_filter) && length($user_filter));
$date_filter = undef unless (defined($date_filter) && length($date_filter));
$level_filter = 0 unless (defined($level_filter));
$acceptance_filter = 2 unless (defined($acceptance_filter));


sub print_stats {
	my $stats = Stats::get_all({
		user		=> $user_filter,
		date		=> $date_filter,
		level		=> $level_filter,
		acceptance	=> $acceptance_filter
	});
	my @stats_keys = sort(keys(%$stats));

	#use Data::Dumper;
	#print $cgi->pre(Dumper($stats));

	my @trs = ();
	# first row is the table header
	push(@trs, $cgi->thead($cgi->Tr(
		$cgi->th('User'),
		$cgi->th('Date'),
		$cgi->th('Sentence'),
		$cgi->th('Length'),
		$cgi->th('Level'),
		$cgi->th('Acceptance')
	)));

	my $row;
	for (@stats_keys) {
		$row = $stats->{$_};
		push(@trs, $cgi->Tr(
			$cgi->td($row->{user}),
			$cgi->td(Time::Piece->strptime($row->{validated_at}, "%Y-%m-%d %T")->ymd()),
			$cgi->td($row->{filename}),
			$cgi->td($row->{wavtime}),
			$cgi->td($row->{level} == 1 ? 'first' : 'second'),
			$cgi->td($row->{acceptance} == 1 ? 'accepted' : 'refused')
		));
	}

	#TODO: table sorter
	#      http://joequery.github.io/Stupid-Table-Plugin/
	#      http://tristen.ca/tablesort/demo/

	#TODO: graphs?
	#      http://code.shutterstock.com/rickshaw/

	if (scalar(@stats_keys)) {
		print $cgi->table({-id => 'stats'},
			join('', @trs)
		);
	}
	else {
		print $cgi->p('No data.');
	}
}


print $cgi->header(-type => 'text/html; charset=UTF-8');
print $cgi->start_html(
	-title => 'Statistics',
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

print $cgi->body({-id => 'statspage'});

print_navigation($cgi, 'stats.pl', $user);

print $cgi->start_div({-id => 'content', -class => 'whitebox'});

print $cgi->start_div({-id => 'logo'});
print $cgi->img({
	-src	=> $media_url . 'images/Idiap-logo-E-small.png',
	-height	=> '40px'
});
print $cgi->end_div();

print $cgi->start_div({-id => 'top-page'});
print $cgi->p('Statistics');
print $cgi->end_div();

print $cgi->start_form({
	-action => $cgi_web_directory . 'stats.pl',
	-method => 'GET',
	-id => 'filterform'
});

#TODO: move to app.js
my $on_change = 'document.getElementById("filterform").submit()';

print $cgi->div(
	$cgi->label('Date'),
	$cgi->input({
		-name => 'date',
		-type => 'date',
		-class => 'text-input',
		-value => $date_filter,
		-onChange => $on_change
	})
);

print $cgi->div(
	$cgi->label('User'),
	$cgi->div({-class => 'select'},
		$cgi->popup_menu({
			-name => 'user',
			-values => ['', User::get_all_usernames()],
			-default => $user_filter,
			-onChange => $on_change
		})
	)
);

print $cgi->div(
	$cgi->label('Level'),
	$cgi->div({-class => 'select'},
		$cgi->popup_menu({
			-name => 'level',
			-values => [0, 1, 2],
			-labels => {0 => 'Both', 1 => 'First', 2 => 'Second'},
			-default => $level_filter,
			-onChange => $on_change
		})
	)
);

print $cgi->div(
	$cgi->label('Acceptance'),
	$cgi->div({-class => 'select'},
		$cgi->popup_menu({
			-name => 'acceptance',
			-values => [2, 1, 0],
			-labels => {2 => 'Both', 1 => 'Accepted', 0 => 'Refused'},
			-default => $acceptance_filter,
			-onChange => $on_change
		})
	)
);

print $cgi->end_form();

print_stats();

print $cgi->end_div();
