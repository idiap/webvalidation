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
	$website_url_domain $cgi_web_directory $media_url
	print_navigation
);
use User;
use Stats;
use Time::Piece;


my $cgi = new CGI;
# only admins can view statistics
my $user = User::authenticate($cgi, 'admin');
unless ($user) {
	print $cgi->redirect($website_url_domain . $cgi_web_directory . 'login.pl');
}

my $user_filter = $cgi->param('user');
my $date_filter = $cgi->param('date');

# default values
$user_filter = undef unless (defined($user_filter) && length($user_filter));
$date_filter = undef unless (defined($date_filter) && length($date_filter));


=c
###
# 
###
sub print_overall_stats {
	my $overall_stats = Stats::get_overall();

	my @trs = ();
	# first row is the table header
	push(@trs, $cgi->thead($cgi->Tr(
		$cgi->th(),
		$cgi->th('1st Annotated'),
		$cgi->th('1st Refused'),
		$cgi->th('2nd Annotated')
	)));

	#TODO: get `average_wavtime_LEVEL_ACCEPTANCE` from hash
	push(@trs, $cgi->Tr(
		$cgi->td('Average'),
		$cgi->td($overall_stats->{average_wavtime_1_1}),
		$cgi->td(),
		$cgi->td()
	));

	#TODO: get `median_wavtime_LEVEL_ACCEPTANCE` from hash
	push(@trs, $cgi->Tr(
		$cgi->td('Median'),
		$cgi->td(),
		$cgi->td(),
		$cgi->td()
	));

	if (scalar(keys(%$overview_stats))) {
		print $cgi->table({-id => 'overview_stats'},
			join('', @trs)
		);
	}
}
=cut


sub print_stats {
	my $stats_first = Stats::get_realtime_factor({
		user		=> $user_filter,
		date		=> $date_filter,
		level		=> 1,
		acceptance	=> 1
	});
	my $stats_first_ref = Stats::get_realtime_factor({
		user		=> $user_filter,
		date		=> $date_filter,
		level		=> 1,
		acceptance	=> 0
	});
	my $stats_second = Stats::get_realtime_factor({
		user		=> $user_filter,
		date		=> $date_filter,
		level		=> 2,
		acceptance	=> 1
	});

	my @trs = ();
	# first row is the table header
	push(@trs, $cgi->thead($cgi->Tr(
		$cgi->th('Day'),
		$cgi->th('User'),
		$cgi->th(),
		$cgi->th('1st Annotated'),
		$cgi->th('Spent'),
		$cgi->th('Ratio'),
		$cgi->th(),
		$cgi->th('1st Refused'),
		$cgi->th('Spent'),
		$cgi->th('Ratio'),
		$cgi->th(),
		$cgi->th('2nd Annotated'),
		$cgi->th('Spent'),
		$cgi->th('Ratio')
	)));

	my ($row_first, $row_first_ref, $row_second, @day_users, $day);
	my ($first_wav, $first_spent, $first_ratio);
	my ($first_wav_ref, $first_spent_ref, $first_ratio_ref);
	my ($second_wav, $second_spent, $second_ratio);
	# get the days from all stats
	my @stats_days = sort(keys(
		%{{%$stats_first, %$stats_first_ref, %$stats_second}}
	));

	for (@stats_days) {
		$day = $_;
		$row_first = exists($stats_first->{$_}) ? $stats_first->{$_} : {};
		$row_first_ref = exists($stats_first_ref->{$_}) ? $stats_first_ref->{$_} : {};
		$row_second = exists($stats_second->{$_}) ? $stats_second->{$_} : {};
		# get the users presented in this day
		@day_users = sort(keys(
			%{{%$row_first, %$row_first_ref, %$row_second}}
		));

		for (@day_users) {
			# values
			$first_wav = exists($row_first->{$_}) ? $row_first->{$_}->{total_wavtime} : 0;
			$first_spent = exists($row_first->{$_}) ? $row_first->{$_}->{total_spent} : 0;
			$first_ratio = $first_wav ? $first_spent / $first_wav : 0;

			$first_wav_ref = exists($row_first_ref->{$_}) ? $row_first_ref->{$_}->{total_wavtime} : 0;
			$first_spent_ref = exists($row_first_ref->{$_}) ? $row_first_ref->{$_}->{total_spent} : 0;
			$first_ratio_ref = $first_wav_ref ? $first_spent_ref / $first_wav_ref : 0;

			$second_wav = exists($row_second->{$_}) ? $row_second->{$_}->{total_wavtime} : 0;
			$second_spent = exists($row_second->{$_}) ? $row_second->{$_}->{total_spent} : 0;
			$second_ratio = $second_wav ? $second_spent / $second_wav : 0;

			push(@trs, $cgi->Tr(
				# Day
				$cgi->td($day),
				# User
				$cgi->td($_),
				$cgi->td(),
				# 1st Annotated
				$cgi->td($first_wav),
				# Spent
				$cgi->td($first_spent),
				# Ratio
				$cgi->td(sprintf("%.2f", $first_ratio)),
				$cgi->td(),
				# 1st Refused
				$cgi->td($first_wav_ref),
				# Spent
				$cgi->td($first_spent_ref),
				# Ratio
				$cgi->td(sprintf("%.2f", $first_ratio_ref)),
				$cgi->td(),
				# 2nd Annotated
				$cgi->td($second_wav),
				# Spent
				$cgi->td($second_spent),
				# Ratio
				$cgi->td(sprintf("%.2f", $second_ratio))
			));
		}
	}

	if (scalar(@stats_days)) {
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

print $cgi->start_body({-id => 'statspage'});

print_navigation($cgi, 'stats_user.pl', $user);

print $cgi->start_div({-id => 'content', -class => 'whitebox'});

print $cgi->start_div({-id => 'logo'});
print $cgi->img({
	-src	=> $media_url . 'images/Idiap-logo-E-small.png',
	-height	=> '40px'
});
print $cgi->end_div();

print $cgi->start_div({-id => 'top-page'});
print $cgi->p('User Statistics');
print $cgi->end_div();

#print_overall_stats();

print $cgi->start_form({
	-action => $cgi_web_directory . 'stats_user.pl',
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

print $cgi->end_form();

print_stats();

print $cgi->end_div();
print $cgi->end_body();
print $cgi->end_html();
