/**
 *            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
 *                    Version 2, December 2004
 *
 *            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 *
 *  0. You just DO WHAT THE FUCK YOU WANT TO.
 **/

#ifdef _INSIDE_PARSER
#define IS_END(s, p) (s[*p] == '\0')

static NodeType string_next_type (VALUE self, char* string, size_t* position)
{
	char current = string[*position];

	if (isdigit(current) || current == '-' || current == '+') {
		return NODE_NUMBER;
	}

	switch (current) {
		case '^':           return NODE_METADATA;
		case 't': case 'f': return NODE_BOOLEAN;
		case 'n':           return NODE_NIL;
		case '\\':          return NODE_CHAR;
		case ':':           return NODE_KEYWORD;
		case '"':           return NODE_STRING;
		case '{':           return NODE_MAP;
		case '(':           return NODE_LIST;
		case '[':           return NODE_VECTOR;
	}

	if (current == '#') {
		current = string[++*position];

		if (IS_END(string, position)) {
			rb_raise(rb_eSyntaxError, "unexpected EOF");
		}

		switch (current) {
			case 'i': return NODE_INSTANT;
			case '{': return NODE_SET;
			case '"': return NODE_REGEXP;
		}
	}

	rb_raise(rb_eSyntaxError, "unknown type");
}

static VALUE string_read_next (VALUE self, char* string, size_t* position)
{
	string_ignore(string, position);
}

static VALUE string_parse (VALUE self)
{
	size_t position = 0;

	return string_read_next(self, rb_string_value_cstr(rb_iv_get(self, "@source")), &position);
}

#undef IS_END
#endif
