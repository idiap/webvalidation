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
	$website_url_domain $cgi_web_directory $media_url $webapp_salt $data_directory
	@projects @groups
	print_navigation print_messages array_has
);
use Digest::SHA 'sha1_hex';
use Database qw(select_one update);
use User;
use File::Path 'make_path';


my $cgi = new CGI;
# check if user is logged in
my $user = User::authenticate($cgi);
unless ($user) {
	print $cgi->redirect($website_url_domain . $cgi_web_directory . 'login.pl');
}

# this allows the admin to edit other users
my $user_edit;
my $username = $cgi->param('user');
if ($username) {
	$user_edit = select_one('"user"', {login => $username});
}
else {
	$user_edit = $user;
}


###
# Print the new user form
###
sub print_user_form {
	my @msgs = @_;

	print $cgi->header(-type => 'text/html; charset=UTF-8');
	print $cgi->start_html(
		-title => 'Edit user',
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

	print_navigation($cgi, 'edit_user.pl', $user);
	print_messages($cgi, @msgs);

	print $cgi->start_div({-id => 'login-wrapper', -style => 'top:10%'});
	print $cgi->start_form(
		-action => $cgi_web_directory . 'edit_user.pl' . ($username?"?user=${username}":''),
		-method => 'POST',
	);

	print $cgi->start_p();
	print $cgi->label('Username');
	print $cgi->textfield(
		-name		=> 'username',
		-class		=> 'text-input',
		-value		=> $user_edit->{login},
		-maxlength	=> 50,
		-readonly	=> 'readonly'
	);
	print $cgi->br({-style => 'clear:both'});
	print $cgi->end_p();

	print $cgi->start_p();
	print $cgi->label('Full Name');
	print $cgi->textfield(
		-name		=> 'full_name',
		-class		=> 'text-input',
		-value		=> $user_edit->{full_name},
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

	if ($user->{groupname} eq 'admin') {
		print $cgi->start_p();
		print $cgi->label('Project');
		print $cgi->div({-class => 'select'},
			$cgi->popup_menu(
				-name		=> 'project',
				-values		=> ['-- Project --', @projects],
				-attributes	=> {
					'-- Project --' => {'value' => 0},
					$user_edit->{project} => {'selected' => 1}
				}
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
				-attributes	=> {
					'-- Group --' => {'value' => 0},
					$user_edit->{groupname} => {'selected' => 'selected'}
				}
			)
		);
		print $cgi->br({-style => 'clear:both'});
		print $cgi->end_p();

		print $cgi->hidden('user', $username);
	}

	print $cgi->submit(
		-name	=> 'edit',
		-class	=> 'button',
		-value	=> 'Edit'
	);

	print $cgi->end_form();
	print $cgi->end_div();
}


sub handle_post {
	my $full_name			= $cgi->param('full_name');
	my $password			= $cgi->param('password');
	my $confirm_password	= $cgi->param('confirm_password');
	my $project				= $cgi->param('project');
	my $groupname			= $cgi->param('groupname');

	my @errors = ();
	push(@errors, 'Password is too big') if (length($password) > 50);
	# check passwords
	push(@errors, 'Passwords don\'t match') if ($password ne $confirm_password);
	if ($user->{groupname} eq 'admin') {
		# check groupname is a valid group and project is a valid project
		push(@errors, 'Project doesn\'t exist') if (!array_has($project, @projects));
		push(@errors, 'Group doesn\'t exist') if (!array_has($groupname, @groups));
	}
	# go back to the user form if there were any errors
	return print_user_form(@errors) if (scalar(@errors));

	#TODO: move this to User module

	$user_edit->{full_name} = $full_name;
	# only change password if the user entered any text
	if (length($password) > 0) {
		$user_edit->{password} = sha1_hex($password . $webapp_salt);
	}
	# only change group or project if the user is admin
	if ($user->{groupname} eq 'admin') {
		$user_edit->{project} = $project;
		$user_edit->{groupname} = $groupname;
	}

	if (update('"user"', ['id', $user_edit->{id}], $user_edit)) {
		print_user_form('User edited successfully');
	}
	else {
		print_user_form('Something went wrong while editing user');
	}
}


if (defined($cgi->param('edit'))) {
	handle_post();
}
else {
	print_user_form();
}
