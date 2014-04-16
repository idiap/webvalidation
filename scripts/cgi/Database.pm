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

package Database;

require Exporter;
use strict;
use DBI;
use Webvalidation '$db_config';

BEGIN {
	our @ISA = 'Exporter';
	our @EXPORT = '';
	our @EXPORT_OK = qw(select_all_raw select_one_raw select_one insert update);
}

my $db;


sub db_connect {
	return if ($db);

	$db = DBI->connect(
		'dbi:Pg:dbname='.${$db_config}{name}.';host='.${$db_config}{host},
		${$db_config}{user},
		${$db_config}{pass},
		{PrintError => 0, RaiseError => 1}
	);
}


sub db_disconnect {
	return if ($db);

	$db->disconnect();
}


###
# Returns a hash reference with all rows.
#
# $statement (string): sql statement
# $key (string): column name by which the rows are indexed in the hash
# @values (list): values to be replaced with the question marks in the statement
###
sub select_all_raw {
	db_connect();
	return unless ($db);

	my ($statement, $key, @values) = @_;
	my $result;
	eval {
		$result = $db->selectall_hashref($statement, $key, undef, @values);
	};
	print STDERR "$@ \n" if ($@);

	$result;
}


###
#
###
sub select_all {
	#TODO
}


###
# Returns a hash reference with the first row that matches the criteria.
#
# $statement (string): sql statement
# @values (array): values to be replaced with question marks in the statement
###
sub select_one_raw {
	db_connect();
	return unless ($db);

	my ($statement, @values) = @_;
	my $result;
	eval {
		$result = $db->selectrow_hashref($statement, undef, @values);
	};
	print STDERR "$@ \n" if ($@);

	$result;
}


###
# Returns a hash reference with the first row that matches the criteria.
#
# $table (string): table name
# $selector (string): [optional] fields to be selected, default is ['*']
# $constraints (hashref): [optional] keys are column names and values are the
#  criteria (multiple constraints will be separated by AND's)
#
# Example:
# $film = select_one('films', {id => 23});
# $film = select_one('films', ['id', 'title'], {year => 1984});
###
sub select_one {
	db_connect();
	return unless ($db);

	my ($table, $selector, $constraints) = @_;
	if (ref($selector) ne 'ARRAY') {
		$constraints = $selector;
		$selector = ['*'];
	}

	my $selector_str = join(',', @$selector);

	my @comparisons = ();
	push(@comparisons, "$_=?") for (keys(%$constraints));
	my $constraints_str = join(' AND ', @comparisons);

	my $sql = "SELECT $selector_str FROM $table";
	$sql .= " WHERE $constraints_str" if (length($constraints_str));
	my $result;
	eval {
		$result = $db->selectrow_hashref($sql, undef, values(%$constraints));
	};
	print STDERR "$@ \n" if ($@);

	$result;
}


###
# Execute an insert statement.
#
# $table (string): table name
# $row (hashref): keys are column names and values are the values to insert
#
# Returns: boolean
#
# Example:
# $result = insert('films', {id => 23, title => 'Dune', year => 1984});
###
sub insert {
	db_connect();
	return unless ($db);

	my ($table, $row) = @_;
	my $columns = join(',', keys(%$row));
	# list of question marks separated by commas (see repetition operator)
	my $question_marks = join(',', ('?') x keys(%$row));
	my $result;
	eval {
		my $statement = $db->prepare(
			"INSERT INTO $table ($columns) VALUES ($question_marks)"
		);
		$result = $statement->execute(values(%$row));
	};
	print STDERR "$@ \n" if ($@);

	$result;
}


###
# Execute an update statement.
#
# $table (string): table name
# $key (arrayref): key name and value of the row to update
# $row (hashref): keys are column names and values are the values to update
#
# Example:
# $result = update('films', ['id', 23], {title => 'The Terminator'});
###
sub update {
	db_connect();
	return unless ($db);

	my ($table, $key, $row) = @_;
	my $columns = join(',', keys(%$row));

	my @assignments = ();
	push(@assignments, "$_=?") for (keys(%$row));
	my $selector = $$key[0] . '=' . $$key[1];

	my $result;
	eval {
		my $statement = $db->prepare(
			"UPDATE $table SET " . join(',', @assignments) .
			"WHERE $selector"
		);
		$result = $statement->execute(values(%$row));
	};
	print STDERR "$@ \n" if ($@);

	$result;
}

1;
