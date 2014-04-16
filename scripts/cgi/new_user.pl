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
	@projects @groups
	print_navigation print_messages
);
use File::Path 'make_path';
use User;


my $cgi = new CGI;
# only admins can create users
my $user = User::authenticate($cgi, 'admin');
unless ($user) {
	print $cgi->redirect($website_url_domain . $cgi_web_directory . 'login.pl');
}


###
# Print the new user form
###
sub print_user_form {
	my @msgs = @_;

	print $cgi->header(-type => 'text/html; charset=UTF-8');
	print $cgi->start_html(
		-title => 'Create user',
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

	print_navigation($cgi, 'new_user.pl', $user);
	print_messages($cgi, @msgs);

	print $cgi->start_div({-id => 'login-wrapper', -style => 'top:10%'});
	print $cgi->start_form(
		-action => $cgi_web_directory . 'new_user.pl',
		-method => 'POST',
	);

	print $cgi->start_p();
	print $cgi->label('Username');
	print $cgi->textfield(
		-name		=> 'username',
		-class		=> 'text-input',
		-maxlength	=> 50
	);
	print $cgi->br({-style => 'clear:both'});
	print $cgi->end_p();

	print $cgi->start_p();
	print $cgi->label('Full Name');
	print $cgi->textfield(
		-name		=> 'full_name',
		-class		=> 'text-input',
		-maxlength	=> 200
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

	print $cgi->start_p();
	print $cgi->label('Confirm');
	print $cgi->password_field(
		-name		=> 'confirm_password',
		-class		=> 'text-input',
		-maxlength	=> 50
	);
	print $cgi->br({-style => 'clear:both'});
	print $cgi->end_p();

	print $cgi->start_p();
	print $cgi->label('Project');
	print $cgi->div({-class => 'select'},
		$cgi->popup_menu(
			-name		=> 'project',
			-values		=> ['-- Project --', @projects],
			-attributes	=> {'-- Project --' => {'value' => 0}}
		)
	);
	print $cgi->br({-style => 'clear:both'});
	print $cgi->end_p();

	print $cgi->start_p();
	print $cgi->label('Group');
	print $cgi->div({-class => 'select'},
		$cgi->popup_menu(
			-name		=> 'groupname',
			-values		=> ['-- Group --', @groups],
			-attributes	=> {'-- Group --' => {'value' => 0}}
		)
	);
	print $cgi->br({-style => 'clear:both'});
	print $cgi->end_p();

	print $cgi->submit(
		-name	=> 'create',
		-class	=> 'button',
		-value	=> 'Create'
	);

	print $cgi->end_form();
	print $cgi->end_div();
}


sub handle_post {
	my $result;
	my $username = $cgi->param('username');
	my $project = $cgi->param('project');
	eval {
		$result = User::create({
			username			=> $username,
			full_name			=> $cgi->param('full_name'),
			password			=> $cgi->param('password'),
			confirm_password	=> $cgi->param('confirm_password'),
			project				=> $project,
			groupname			=> $cgi->param('groupname')
		});
	};
	if ($@) {
		# dereference array with error messages
		return print_user_form(@{$@});
	}

	if ($result) {
		# create user folder
		make_path($data_directory . $project . '/user_space/' . $username);
		print_user_form('User created successfully');
	}
	else {
		print_user_form('Something went wrong while inserting user');
	}
}

if (defined($cgi->param('create'))) {
	handle_post();
}
else {
	print_user_form();
}
