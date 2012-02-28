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
#define IS_EOF (string[*position] == '\0')
#define IS_EOF_AFTER(n) (string[*position + n] == '\0')
#define CURRENT (string[*position])
#define AFTER(n) (string[*position + 1])
#define SEEK(n) (*position += n)
#define IS_IGNORED(ch) (isspace(ch) || ch == ',')
#define IS_BOTH(ch) (ch == ' ' || ch == ',' || ch == '"' || ch == '{' || ch == '}' || ch == '(' || ch == ')' || ch == '[' || ch == ']' || ch == '#' || ch == ':' || ch == '\n' || ch == '\r' || ch == '\t')
#define IS_KEYWORD(ch) (ch == ' ' || ch == ',' || ch == '"' || ch == '{' || ch == '}' || ch == '(' || ch == ')' || ch == '[' || ch == ']' || ch == '#' || ch == ':' || ch == '\'' || ch == '^' || ch == '@' || ch == '`' || ch == '~' || ch == '\\' || ch == ';' || ch == '\n' || ch == '\r' || ch == '\t')

static VALUE string_read_next (VALUE self, char* string, size_t* position);

static void string_ignore (VALUE self, char* string, size_t* position)
{
	while (!IS_EOF && (IS_IGNORED(CURRENT))) {
		SEEK(1);
	}

	SEEK(-1);
}

static NodeType string_next_type (VALUE self, char* string, size_t* position)
{
	if (isdigit(CURRENT) || CURRENT == '-' || CURRENT == '+') {
		return NODE_NUMBER;
	}

	switch (CURRENT) {
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

	if (CURRENT == '#') {
		if (IS_EOF_AFTER(1)) {
			rb_raise(rb_eSyntaxError, "unexpected EOF");
		}

		switch (AFTER(1)) {
			case 'i': return NODE_INSTANT;
			case '{': return NODE_SET;
			case '"': return NODE_REGEXP;
		}
	}

	rb_raise(rb_eSyntaxError, "unknown type");
}

static VALUE string_read_metadata (VALUE self, char* string, size_t* position)
{
	VALUE  result;
	VALUE* metadatas = NULL;
	size_t length    = 0;

	while (string[*position] == '^') {
		metadatas = realloc(metadatas, ++length * sizeof(VALUE));

		SEEK(1);

		metadatas[length - 1] = string_read_next(self, string, position);
	}

	result = string_read_next(self, string, position);

	if (!rb_respond_to(result, rb_intern("metadata="))) {
		free(metadatas);

		rb_raise(rb_eSyntaxError, "the object cannot hold metadata");
	}

	for (size_t i = 0; i < length; i++) {
		rb_funcall(result, rb_intern("metadata="), 1, metadatas[i]);
	}

	free(metadatas);

	return result;
}

static VALUE string_read_nil (VALUE self, char* string, size_t* position)
{
	if (IS_EOF_AFTER(1) || IS_EOF_AFTER(2)) {
		rb_raise(rb_eSyntaxError, "unexpected EOF");
	}

	if (!(AFTER(1) == 'i' && AFTER(2) == 'l')) {
		rb_raise(rb_eSyntaxError, "expected nil, got n%c%c", AFTER(1), AFTER(2));
	}

	return Qnil;
}

static VALUE string_read_boolean (VALUE self, char* string, size_t* position)
{
	if (CURRENT == 't') {
		if (IS_EOF_AFTER(1) || IS_EOF_AFTER(2) || IS_EOF_AFTER(3)) {
			rb_raise(rb_eSyntaxError, "unexpected EOF");
		}

		if (!(AFTER(1) == 'r' && AFTER(2) == 'u' && AFTER(3) == 'e')) {
			rb_raise(rb_eSyntaxError, "expected true, got t%c%c%c", AFTER(1), AFTER(2), AFTER(3));
		}

		return Qtrue;
	}
	else {
		if (IS_EOF_AFTER(1) || IS_EOF_AFTER(2) || IS_EOF_AFTER(3) || IS_EOF_AFTER(4)) {
			rb_raise(rb_eSyntaxError, "unexpected EOF");
		}

		if (!(AFTER(1) == 'a' && AFTER(2) == 'l' && AFTER(3) == 's' && AFTER(4) == 'e')) {
			rb_raise(rb_eSyntaxError, "expected false, got f%c%c%c%c", AFTER(1), AFTER(2), AFTER(3), AFTER(4));
		}

		return Qfalse;
	}
}

static VALUE string_read_number (VALUE self, char* string, size_t* position)
{
	size_t length = 0;
	VALUE  rbPiece;
	char*  cPiece;
	char*  tmp;

	while (!IS_EOF_AFTER(length) && !IS_BOTH(AFTER(length))) {
		length++;
	}

	rbPiece = rb_str_new(&string[*position], length);
	cPiece  = rb_str_value_cstr(rbPiece);

	SEEK(length);

	if (strchr(cPiece, '/')) {
		return rb_funcall(rb_cObject, rb_intern("Rational"), 1, rbPiece);
	}
	else if ((tmp = strchr(cPiece, 'r')) || (tmp = strchr(cPiece, 'R'))) {
		return rb_funcall(rb_str_new(cPiece, tmp - cPiece), rb_intern("to_i"), 1,
			rb_funcall(rb_str_new_cstr(tmp), rb_intern("to_i"), 0));
	}
	else if (strchr(cPiece, '.') || strchr(cPiece, 'e') || strchr(cPiece, 'E') || cPiece[length - 1] == 'M') {
		if (cPiece[length - 1] == 'M') {
			return rb_funcall(rb_cObject, rb_intern("BigDecimal"), 1, rbPiece);
		}
		else {
			return rb_funcall(rb_cObject, rb_intern("Float"), 1, rbPiece);
		}
	}
	else {
		if (cPiece[length - 1] == 'N') {
			rb_str_set_len(rbPiece, length - 1);
		}

		return rb_funcall(rb_cObject, rb_intern("Integer"), 1, rbPiece);
	}
}


static VALUE string_read_next (VALUE self, char* string, size_t* position)
{
	string_ignore(self, string, position);

	if (IS_EOF) {
		rb_raise(rb_eSyntaxError, "unexpected EOF");
	}

	switch (string_next_type(self, string, position)) {
		case NODE_METADATA: return string_read_metadata(self, string, position);
		case NODE_NUMBER:   return string_read_number(self, string, position);
		case NODE_BOOLEAN:  return string_read_boolean(self, string, position);
		case NODE_NIL:      return string_read_nil(self, string, position);
		case NODE_CHAR:     return string_read_char(self, string, position);
		case NODE_KEYWORD:  return string_read_keyword(self, string, position);
		case NODE_STRING:   return string_read_string(self, string, position);
		case NODE_MAP:      return string_read_map(self, string, position);
		case NODE_LIST:     return string_read_list(self, string, position);
		case NODE_VECTOR:   return string_read_vector(self, string, position);
		case NODE_INSTANT:  return string_read_instant(self, string, position);
		case NODE_SET:      return string_read_set(self, string, position);
		case NODE_REGEXP:   return string_read_regexp(self, string, position);
	}
}

static VALUE string_parse (VALUE self)
{
	size_t position = 0;

	return string_read_next(self, rb_string_value_cstr(rb_iv_get(self, "@source")), &position);
}

#undef IS_EOF
#undef IS_EOF_AFTER
#undef CURRENT
#undef AFTER
#undef SEEK
#endif
