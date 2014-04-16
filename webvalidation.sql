create table "user" (
		id integer not null primary key,
		login varchar(50) not null unique,
		full_name varchar(200) not null,
		password character(40) not null,
		project varchar(200) not null,
		groupname varchar(30)
);

create table stats (
	id integer primary key,
	user_id integer not null,
	filename text not null,
	level integer not null,
	validated_at timestamp not null,
	spent integer not null,
	wavtime integer not null,
	acceptance integer not null
);

create index stats_user_id_idx on stats (user_id);
create index stats_filename_idx on stats (filename);
create index stats_validated_at_idx on stats (validated_at);
create index stats_acceptance_idx on stats (acceptance);

