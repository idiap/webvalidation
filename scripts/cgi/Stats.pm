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

package Stats;

use strict;
use Database qw(select_all_raw select_one insert);
use User;
use Time::Piece;
use Time::Seconds;

my $table = 'stats';


###
#
###
sub create {
	my $values		= shift(@_);
	my $user		= $values->{user};
	my $path		= $values->{path};
	my $filename	= $values->{filename};
	my $level		= $values->{level};
	my $time		= $values->{time};
	my $spent		= $values->{spent};
	my $acceptance	= $values->{acceptance};

	#TODO: validate input data (see User::create)
	$spent = 0 unless ($spent);

	if ($level eq 'first') {
		$level = 1;
	}
	elsif ($level eq 'second') {
		$level = 2;
	}
	else {
		$level = 0;
	}

	# get length of the wav file
	my $wavtime;
	eval {
		my $mediainfo = '-n stat 2>&1 | sed -n "s#^Length (seconds):[^0-9]*\([0-9.]*\)\$#\1#p"';

		#In seconds
		$wavtime = `sox ${path}${filename}.wav ${mediainfo}`;
		$wavtime = sprintf("%.0f", $wavtime);
	};
	if ($@ || !$wavtime) {
		$wavtime = 0;
	}

	my $id = select_one($table, ['max(id)+1 as cnt'])->{cnt};
	$id = 1 unless ($id);

	insert($table, {
		id				=> $id,
		user_id			=> $user->{id},
		filename		=> $filename,
		level			=> $level,
		validated_at	=> $time->datetime(),
		spent			=> $spent,
		wavtime			=> $wavtime,
		acceptance		=> $acceptance
	});
}


###
# Generate SQL constraints to use in the SQL WHERE statement.
#
# $filter (hashref): user, date, level and acceptance values
#
# Returns: array, first element is the SQL string and the following are values
#  to use in the select_all_raw method
###
sub _get_constraints {
	my $filter		= shift(@_);
	my $username	= $filter->{user};
	my $date		= $filter->{date};
	my $level		= $filter->{level};
	my $acceptance	= $filter->{acceptance};

	#TODO: validate input data
	#TODO: move sql nonsense to Database::select_all

	my @constraints = ();
	my @values = ();

	if (defined($username)) {
		my $user = User::get_by_username($username);
		if ($user) {
			push(@constraints, 'user_id = ?');
			push(@values, $user->{id});
		}
	}

	if (defined($date)) {
		my $start_date = Time::Piece->strptime($date, "%Y-%m-%d");
		my $end_date = $start_date + ONE_DAY;
		push(@constraints, 'validated_at >= ?', 'validated_at < ?');
		push(@values, $start_date, $end_date);
	}

	if (defined($level) && $level > 0 && $level <= 2) {
		push(@constraints, 'level = ?');
		push(@values, $level);
	}

	if (defined($acceptance) && $acceptance >= 0 && $acceptance < 2) {
		push(@constraints, 'acceptance = ?');
		push(@values, $acceptance);
	}

	(join(' AND ', @constraints), @values);
}


sub get_all {
	my ($constraints, @values) = _get_constraints(@_);

	my $sql = "SELECT s.*, u.login AS user FROM $table s JOIN \"user\" u ON u.id = s.user_id";
	$sql .= " WHERE $constraints" if (length($constraints));
	select_all_raw($sql, 'id', @values);
}


=c
Alternative calculation to get the first validation ratio without relying in the
time spent on the page:

second_ratio_constant = 1.6

first_daytime = (select sum(wavtime) from stats where level = 1 and user_id = X and DAY < validated_at < DAY+1)
second_daytime = (select sum(wavtime) from stats where level = 2 and user_id = X and DAY < validated_at < DAY+1)

second_daytime = second_wavtime * second_ratio_constant
first_daytime = 7 * 60 * 60 - second_daytime
first_ratio = first_daytime / first_wavtime
=cut

###
# Get wavtime and spent time from the database. You can use date and user
# filters.
#
# $filter (hashref): you can specify `user` and `date` keys
###
sub get_realtime_factor {
	my ($constraints, @values) = _get_constraints(@_);

=c
Example:

select
	date(validated_at) as day,
	login,
	sum(wavtime) as total_wavtime,
	sum(spent) as total_spent
from stats s join "user" u on u.id=s.user_id
where
	validated_at > '2013-7-8' and
	validated_at < '2013-7-10' and
	level = 1 and
	acceptance = 1
group by login, day;
=cut

	my $sql = 'SELECT DATE(validated_at) AS day, login AS user, SUM(wavtime) AS total_wavtime, SUM(spent) AS total_spent';
	$sql .= " FROM $table s JOIN \"user\" u ON u.id = s.user_id";
	$sql .= " WHERE $constraints" if (length($constraints));
	$sql .= ' GROUP BY login, day';
	select_all_raw($sql, ['day', 'user'], @values);
}


=c
AVERAGE:
	select avg(total_wavtime) from (
		select sum(wavtime) as total_wavtime 
		from stats s
		join "user" u on u.id=s.user_id
		where
			level=X and
			acceptance=Y
		group by login, date(validated_at)
	) as average_wavtime;

MEDIAN:
	select median(array(
		select sum(wavtime) as total_wavtime
		from stats s
		join "user" u on u.id=s.user_id
		where
			level=X and
			acceptance=Y
		group by login, date(validated_at)
		order by total_wavtime
	)) as median_wavtime;
=cut

###
# Get average and median for 1st, 1st refused and 2nd validations.
###
=c
sub get_overall {

	my $sql = sub {
		my ($level, $acceptance) = @_;
		my $inner_select = <<"SQL";
			SELECT SUM(wavtime) AS total_wavtime
			FROM stats s
			JOIN "user" u ON u.id = s.user_id
			WHERE
				level = $level AND
				acceptance = $acceptance
			GROUP BY login, DATE(validated_at)
			ORDER BY total_wavtime
SQL

		<<"SQL";
		SELECT AVG(total_wavtime) FROM (
			$inner_select
		) AS average_wavtime_${level}_${acceptance};

		SELECT median(array(
			$inner_select
		)) AS median_wavtime_${level}_${acceptance};
SQL
	};

	select_all_raw(&$sql(1, 1) . &$sql(1, 2) . &$sql(2, 1));
}
=cut

1;
