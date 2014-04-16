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

package User;

use strict;
use Digest::SHA 'sha1_hex';
use Webvalidation qw($webapp_salt @projects @groups array_has);
use Database qw(select_all_raw select_one insert);
use CookieJar qw(create_cookie destroy_cookie parse_cookie validate_cookie);

my $table = '"user"';


###
# Create a new user.
# This function raises an arrayref with error messages.
#
# $values (hashref): keys are field names and values are the values to insert
###
sub create {
	my $values		= shift(@_);
	my $username	= $values->{username};
	my $full_name	= $values->{full_name};
	my $password	= $values->{password};
	my $confirm		= $values->{confirm_password};
	my $project		= $values->{project};
	my $groupname	= $values->{groupname};

	# validate input data
	my @errors = ();
	push(@errors, 'Username is empty') if (length($username) == 0);
	push(@errors, 'Password is empty') if (length($password) == 0);
	# username must only have alphabetic characters
	push(@errors, 'Username must be [a-zA-Z]') if ($username !~ /[a-zA-Z]+/);
	# check username and password are not greater than 50 chars
	push(@errors, 'Username is too big') if (length($username) > 50);
	push(@errors, 'Password is too big') if (length($password) > 50);
	# check passwords
	push(@errors, 'Passwords must match') if ($password ne $confirm);
	# check groupname is a valid group and project is a valid project
	push(@errors, 'Invalid project') if (!array_has($project, @projects));
	push(@errors, 'Invalid group') if (!array_has($groupname, @groups));
	# raise exception if there are errors
	die(\@errors) if (scalar(@errors));

	my $id = select_one($table, ['max(id)+1 as cnt'])->{cnt};
	$id = 1 unless ($id);

	insert($table, {
		id			=> $id,
		login		=> $username,
		full_name	=> $full_name,
		password	=> sha1_hex($password . $webapp_salt),
		project		=> $project,
		groupname	=> $groupname
	});
}


###
# Return an array with all existing usernames.
###
sub get_all_usernames {
	#TODO: create a Database::select_all
	my $users = select_all_raw("SELECT login from $table", 'login');
	sort(keys(%$users));
}


sub get_by_username {
	my $username = shift(@_);
	select_one($table, {login => $username});
}


###
# Log in the user. You can specify a redirect URL (must be an absolute path).
# This function raises an arrayref with error messages.
#
# $cgi (CGI): a CGI object
# $username (string)
# $password (string)
# $redirect (string): [optional] path to redirect after logging the user
###
sub login {
	my ($cgi, $username, $password, $redirect) = @_;

	# validate input data
	my @errors = ();
	push(@errors, 'Username greater than 50') if (length($username) > 50);
	push(@errors, 'Password greater than 50') if (length($password) > 50);
	# raise exception if there are errors
	die(\@errors) if (scalar(@errors));

	# hash the password
	$password = sha1_hex($password . $webapp_salt);

	my $user = select_one($table, {
		login		=> $username,
		password	=> $password
	});

	push(@errors, 'Invalid username/password') if (!$user);
	# raise exception if there is an error
	die(\@errors) if (scalar(@errors));

	# create a cookie for the user
	create_cookie($cgi, $user->{login}, $user->{password}, $redirect);
}


###
# Destroy the cookie of a logged in user.
#
# $cgi (CGI): a CGI object
# $redirect (string): [optional] path to redirect after unsetting the cookie
###
sub logout {
	my ($cgi, $redirect) = @_;
	destroy_cookie($cgi, $redirect) if (authenticate($cgi));
}


###
# Get the cookie, parse it and check if the user is valid. If the user is valid
# return it, otherwise return false. You can provide a group name to verify if
# the current logged in user belongs to it.
#
# $cgi (CGI): a CGI object
# $check_group (string): [optional] group name to check
#
# Returns: user hash or false
###
sub authenticate {
	my ($cgi, $check_group) = @_;
	my ($username, $hash) = parse_cookie($cgi);
	# return if cookie couldn't be parsed
	return 0 unless ($username);

	# get the user from database
	my $user = get_by_username($username);
	# return if there is no user in the database
	return 0 unless ($user);

	# check if the cookie value match the original cookie
	my $valid = validate_cookie($cgi, $user->{login}, $user->{password});
	# if a group was provided, also check if user belongs to it
	if (defined($check_group)) {
		$valid = $user->{groupname} eq $check_group && $valid;
	}

	$valid ? $user : 0;
}

1;
