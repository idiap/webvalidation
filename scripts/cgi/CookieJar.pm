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

package CookieJar;

require Exporter;
use strict;
use Webvalidation qw($webapp_salt $cookie_name);
use Digest::SHA 'sha1_hex';

BEGIN {
	our @ISA = 'Exporter';
	our @EXPORT = '';
	our @EXPORT_OK = qw(create_cookie destroy_cookie parse_cookie validate_cookie);
}


###
# Given a username, generates a string to be placed in the cookie value.
#
# $username (string): user unique identification
# $user_salt (string): user specific hash to salt the output
#
# Returns: string
###
sub generate_cookie_value {
	my ($username, $user_salt) = @_;
	"${username}_" . sha1_hex($username . $user_salt . $webapp_salt);
}


###
# Create a cookie based on a given username. This function sets the cookie in
# the HTTP response header. If you want to redirect, it has to be done here
# because a redirect response should be alone in the HTTP header.
#
# $cgi (CGI): a CGI object to set the cookie on
# $username (string): user unique identification
# $user_salt (string): user specific hash to salt the output
# $redirect (string): [optional] path to redirect after setting the cookie
###
sub create_cookie {
	my ($cgi, $username, $user_salt, $redirect) = @_;
	# generate the cookie value
	my $cookie_value = generate_cookie_value($username, $user_salt);
	# create a cookie and set it on the request's header
	my $cookie = $cgi->cookie(-name => $cookie_name, -value => $cookie_value);
	if ($redirect) {
		print $cgi->redirect(-uri => $redirect, -cookie => $cookie);
	}
	else {
		print $cgi->header(-cookie => $cookie);
	}
}


###
# Invalidates a cookie by creating one with the same name, an empty value and an
# expired date. If you want to redirect, it has to be done here because a
# redirect response should be alone in the HTTP header.
#
# $cgi (CGI): a CGI object to set the cookie on
# $redirect (string): [optional] path to redirect after unsetting the cookie
###
sub destroy_cookie {
	my ($cgi, $redirect) = @_;
	# create an empty and expired cookie, and set it on the request's header
	my $cookie = $cgi->cookie(
		-name => $cookie_name,
		-value => '',
		-expires => '-1d'
	);
	if ($redirect) {
		print $cgi->redirect(-uri => $redirect, -cookie => $cookie);
	}
	else {
		print $cgi->header(-cookie => $cookie);
	}
}


###
# Parse the cookie and return a list with username and hash to validate.
#
# $cgi (CGI): a CGI object
#
# Returns: list - ($username, $hash)
###
sub parse_cookie {
	my ($cgi) = @_;
	# get the cookie
	my $cookie = $cgi->cookie($cookie_name);
	return 0 unless ($cookie);
	# parse the username and hash from the cookie
	my @parsed = split(/(^.+)_(.+$)/, $cookie);
	shift(@parsed);
	@parsed;
}


###
# Generate a cookie again - using the same method as in `create_cookie` - and
# check if it matches the given cookie.
#
# $cgi (CGI): a CGI object
# $username (string): user unique identification
# $user_salt (string): user specific hash to salt the output
#
# Returns: boolean
###
sub validate_cookie {
	my ($cgi, $username, $user_salt) = @_;
	# generate the cookie value again to check if they match
	my $test_cookie = generate_cookie_value($username, $user_salt);
	# return the username if the cookie value is valid
	my $cookie = $cgi->cookie($cookie_name);
	$cookie eq $test_cookie;
}

1;