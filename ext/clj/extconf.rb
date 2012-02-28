require 'mkmf'

unless $CFLAGS.gsub!(/ -O[\dsz]?/, ' -O3')
	$CFLAGS << ' -O3'
end

if CONFIG['CC'] =~ /gcc/
	$CFLAGS << ' -Wall' << ' -std=c99'

	if $DEBUG && !$CFLAGS.gsub!(/ -O[\dsz]?/, ' -O0 -ggdb')
		$CFLAGS << ' -O0 -ggdb'
	end
end

create_makefile 'clj/parser_ext'
