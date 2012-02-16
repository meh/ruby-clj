# Loads mkmf which is used to make makefiles for Ruby extensions
require 'mkmf'

# Give it a name
extension_name = 'parser_ext'

# The destination
dir_config(parser_ext)

# Do the work
create_makefile(parser_ext)
