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
	$media_url $website_url_domain $cgi_web_directory $webapp_salt
	print_messages
);
use User;


my $cgi = new CGI;

###
# Prints the login page, with a form that submits 'username', 'password' and
# 'login 'to this same script.
###
sub print_login_page {
	my ($msgs) = @_;

	print $cgi->header(-type => 'text/html; charset=UTF-8');
	print $cgi->start_html(
		-title => 'Login',
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

	if ($msgs) {
		print_messages($cgi, ($msgs));
	}
	

	print $cgi->start_div({-id => 'login-top'});
	print $cgi->img({
		-src => $media_url . 'images/Idiap-logo-E.png',
		-height => '80px'
	});
	print $cgi->end_div();

	print $cgi->start_div({-id => 'login-wrapper'});
	print $cgi->start_form(
		-action => $cgi_web_directory . 'login.pl',
		-method => 'POST',
	);

	print $cgi->start_p();
	print $cgi->label('Username');
	print $cgi->textfield(
		-name		=> 'username',
		-class		=> 'text-input',
		-maxlength	=> 50,
		-autofocus	=> 1
	);
	print $cgi->br({-style => 'clear:both'});
	print $cgi->end_p();

	print $cgi->start_p();
	print $cgi->label('Password');
	print $cgi->password_field(
		-name		=> 'password',
		-class		=> 'text-input',
		-maxlength	=> 50
	);
	print $cgi->br({-style => 'clear:both'});
	print $cgi->end_p();

	print $cgi->submit(
		-name	=> 'login',
		-class	=> 'button',
		-value	=> 'Login'
	);

	print $cgi->end_form();
	print $cgi->end_div();
	print $cgi->end_html();
}


###
# Handle POST request
###
sub handle_post {
	eval {
		User::login(
			$cgi,
			$cgi->param('username'),
			$cgi->param('password'),
			$website_url_domain . $cgi_web_directory . 'user_space.pl'
		);
	};
	if ($@) {
		# dereference array with error messages
		print_login_page(@{$@});
	}
}


# redirect if the user is already logged in
if (User::authenticate($cgi)) {
	print $cgi->redirect(
		$website_url_domain . $cgi_web_directory . 'user_space.pl'
	);
}
# check if the form was submitted
elsif (defined($cgi->param('login'))) {
	handle_post();
}
else {
	print_login_page();
}

