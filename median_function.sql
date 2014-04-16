create or replace function median(anyarray)
    returns double precision as $$
            select ($1[array_upper($1,1)/2+1]::double precision + $1[(array_upper($1,1)+1) / 2]::double precision) / 2.0; 
    $$ language sql immutable strict;

