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
#define CALL(what) (what(self, string, position))
#define STATE VALUE self, char* string, size_t* position
#define IS_EOF (string[*position] == '\0')
#define IS_EOF_AFTER(n) (string[*position + (n)] == '\0')
#define CURRENT (string[*position])
#define CURRENT_PTR (&string[*position])
#define AFTER(n) (string[*position + (n)])
#define AFTER_PTR(n) (&string[*position + (n)])
#define BEFORE(n) (string[*position - (n)])
#define BEFORE_PTR(n) (&string[*position - (n)])
#define SEEK(n) (*position += (n))
#define IS_IGNORED(ch) (isspace(ch) || ch == ',')
#define IS_BOTH(ch) (ch == ' ' || ch == ',' || ch == '"' || ch == '{' || ch == '}' || ch == '(' || ch == ')' || ch == '[' || ch == ']' || ch == '#' || ch == ':' || ch == '\n' || ch == '\r' || ch == '\t')
#define IS_KEYWORD(ch) (ch == ' ' || ch == ',' || ch == '"' || ch == '{' || ch == '}' || ch == '(' || ch == ')' || ch == '[' || ch == ']' || ch == '#' || ch == ':' || ch == '\'' || ch == '^' || ch == '@' || ch == '`' || ch == '~' || ch == '\\' || ch == ';' || ch == '\n' || ch == '\r' || ch == '\t')
#define IS_NOT_EOF_UP_TO(n) (is_not_eof_up_to(string, position, n))
#define IS_EQUAL_UP_TO(str, n) (strncmp(CURRENT_PTR, str, (n)) == 0)
#define IS_EQUAL(str) IS_EQUAL_UP_TO(str, strlen(str))

static VALUE string_read_next (VALUE self, char* string, size_t* position);

static inline bool is_not_eof_up_to (char* string, size_t* position, size_t n)
{
	for (size_t i = 0; i < n; i++) {
		if (IS_EOF_AFTER(i)) {
			return false;
		}
	}

	return true;
}

static void string_ignore (STATE)
{
	while (!IS_EOF && IS_IGNORED(CURRENT)) {
		SEEK(1);
	}
}

static NodeType string_next_type (STATE)
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

static VALUE string_read_metadata (STATE)
{
	VALUE  result;
	VALUE* metadatas = NULL;
	size_t length    = 0;

	while (CURRENT == '^') {
		metadatas = realloc(metadatas, ++length * sizeof(VALUE));

		SEEK(1);

		metadatas[length - 1] = CALL(string_read_next);
	}

	result = CALL(string_read_next);

	if (!rb_respond_to(result, rb_intern("metadata="))) {
		free(metadatas);

		rb_raise(rb_eSyntaxError, "the object cannot hold metadata");
	}

	// FIXME: this could lead to a memleak if #metadata= raises
	for (size_t i = 0; i < length; i++) {
		rb_funcall(result, rb_intern("metadata="), 1, metadatas[i]);
	}

	free(metadatas);

	return result;
}

static VALUE string_read_nil (STATE)
{
	if (!IS_NOT_EOF_UP_TO(3)) {
		rb_raise(rb_eSyntaxError, "unexpected EOF");
	}

	if (!IS_EQUAL_UP_TO("nil", 3)) {
		rb_raise(rb_eSyntaxError, "expected nil, got n%c%c", AFTER(1), AFTER(2));
	}

	SEEK(3);

	return Qnil;
}

static VALUE string_read_boolean (STATE)
{
	if (CURRENT == 't') {
		if (!IS_NOT_EOF_UP_TO(4)) {
			rb_raise(rb_eSyntaxError, "unexpected EOF");
		}

		if (!IS_EQUAL_UP_TO("true", 4)) {
			rb_raise(rb_eSyntaxError, "expected true, got t%c%c%c", AFTER(1), AFTER(2), AFTER(3));
		}

		SEEK(4);

		return Qtrue;
	}
	else {
		if (!IS_NOT_EOF_UP_TO(5)) {
			rb_raise(rb_eSyntaxError, "unexpected EOF");
		}

		if (!IS_EQUAL_UP_TO("false", 5)) {
			rb_raise(rb_eSyntaxError, "expected false, got f%c%c%c%c", AFTER(1), AFTER(2), AFTER(3), AFTER(4));
		}

		SEEK(5);

		return Qfalse;
	}
}

static VALUE string_read_number (STATE)
{
	size_t length = 0;
	VALUE  rbPiece;
	char*  cPiece;
	char*  tmp;

	while (!IS_EOF_AFTER(length) && !IS_BOTH(AFTER(length))) {
		length++;
	}

	SEEK(length);

	rbPiece = rb_str_new(BEFORE_PTR(length), length);
	cPiece  = StringValueCStr(rbPiece);

	if (strchr(cPiece, '/')) {
		return rb_funcall(rb_cObject, rb_intern("Rational"), 1, rbPiece);
	}
	else if ((tmp = strchr(cPiece, 'r')) || (tmp = strchr(cPiece, 'R'))) {
		return rb_funcall(rb_str_new2(tmp + 1), rb_intern("to_i"), 1,
			rb_funcall(rb_str_new(cPiece, tmp - cPiece), rb_intern("to_i"), 0));
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

static VALUE string_read_char (STATE)
{
	SEEK(1);

	if (IS_EOF_AFTER(1) || IS_BOTH(AFTER(1))) {
		SEEK(1); return rb_str_new(BEFORE_PTR(1), 1);
	}
	else if (IS_NOT_EOF_UP_TO(7) && IS_EQUAL_UP_TO("newline", 7) && (IS_EOF_AFTER(7) || IS_BOTH(AFTER(7)))) {
		SEEK(7); return rb_str_new2("\n");
	}
	else if (IS_NOT_EOF_UP_TO(5) && IS_EQUAL_UP_TO("space", 5) && (IS_EOF_AFTER(5) || IS_BOTH(AFTER(5)))) {
		SEEK(5); return rb_str_new2(" ");
	}
	else if (IS_NOT_EOF_UP_TO(3) && IS_EQUAL_UP_TO("tab", 3) && (IS_EOF_AFTER(3) || IS_BOTH(AFTER(3)))) {
		SEEK(3); return rb_str_new2("\t");
	}
	else if (IS_NOT_EOF_UP_TO(9) && IS_EQUAL_UP_TO("backspace", 9) && (IS_EOF_AFTER(9) || IS_BOTH(AFTER(9)))) {
		SEEK(9); return rb_str_new2("\b");
	}
	else if (IS_NOT_EOF_UP_TO(8) && IS_EQUAL_UP_TO("formfeed", 8) && (IS_EOF_AFTER(8) || IS_BOTH(AFTER(8)))) {
		SEEK(8); return rb_str_new2("\f");
	}
	else if (IS_NOT_EOF_UP_TO(6) && IS_EQUAL_UP_TO("return", 6) && (IS_EOF_AFTER(6) || IS_BOTH(AFTER(6)))) {
		SEEK(6); return rb_str_new2("\r");
	}
	else if (CURRENT == 'u' && IS_NOT_EOF_UP_TO(5) && !NIL_P(rb_funcall(rb_str_new(AFTER_PTR(1), 4), rb_intern("=~"), 1, UNICODE_REGEX)) && (IS_EOF_AFTER(5) || IS_BOTH(AFTER(5)))) {
		SEEK(5); return rb_funcall(rb_ary_new3(1, rb_funcall(rb_str_new(BEFORE_PTR(4), 4), rb_intern("to_i"), 1, INT2FIX(16))),
			rb_intern("pack"), 1, rb_str_new2("U"));
	}
	else if (CURRENT == 'o') {
		size_t length = 1;

		for (size_t i = 1; i < 5; i++) {
			if (IS_EOF_AFTER(i) || IS_BOTH(AFTER(i))) {
				break;
			}

			length++;
		}

		if (length > 1 && !NIL_P(rb_funcall(rb_str_new(AFTER_PTR(1), length - 1), rb_intern("=~"), 1, OCTAL_REGEX)) && (IS_EOF_AFTER(length) || IS_BOTH(AFTER(length)))) {
			SEEK(length); return rb_funcall(rb_funcall(rb_str_new(BEFORE_PTR(length - 1), length - 1), rb_intern("to_i"), 1, INT2FIX(8)),
				rb_intern("chr"), 0);
		}
	}

	// TODO: add unicode and octal chars support

	rb_raise(rb_eSyntaxError, "unknown character type");
}

static VALUE string_read_keyword (STATE)
{
	size_t length = 0;

	SEEK(1);

	while (!IS_EOF_AFTER(length) && !IS_KEYWORD(AFTER(length))) {
		length++;
	}

	SEEK(length);

	return rb_funcall(rb_str_new(BEFORE_PTR(length), length), rb_intern("to_sym"), 0);
}

static VALUE string_read_string (STATE)
{
	size_t length = 0;

	SEEK(1);

	while (AFTER(length) != '"') {
		if (IS_EOF_AFTER(length)) {
			rb_raise(rb_eSyntaxError, "unexpected EOF");
		}

		if (AFTER(length) == '\\') {
			length++;
		}

		length++;
	}

	SEEK(length + 1);

	// TODO: make the escapes work properly

	return rb_funcall(cClojure, rb_intern("unescape"), 1, rb_str_new(BEFORE_PTR(length + 1), length));
}

static VALUE string_read_regexp (STATE)
{
	size_t length = 0;
	VALUE  args[] = { Qnil };

	SEEK(2);

	while (AFTER(length) != '"') {
		if (IS_EOF_AFTER(length)) {
			rb_raise(rb_eSyntaxError, "unexpected EOF");
		}

		if (AFTER(length) == '\\') {
			length++;
		}

		length++;
	}

	SEEK(length + 1);

	args[0] = rb_str_new(BEFORE_PTR(length + 1), length);

	return rb_class_new_instance(1, args, rb_cRegexp);
}

static VALUE string_read_instant (STATE)
{
	SEEK(1);

	if (!IS_NOT_EOF_UP_TO(4)) {
		rb_raise(rb_eSyntaxError, "unexpected EOF");
	}

	if (!IS_EQUAL_UP_TO("inst", 4)) {
		rb_raise(rb_eSyntaxError, "expected inst, got %c%c%c%c", AFTER(0), AFTER(1), AFTER(2), AFTER(3));
	}

	SEEK(4);

	CALL(string_ignore);

	return rb_funcall(rb_const_get(rb_cObject, rb_intern("DateTime")), rb_intern("rfc3339"), 1, CALL(string_read_string));
}

static VALUE string_read_list (STATE)
{
	VALUE result = rb_class_new_instance(0, NULL, rb_iv_get(self, "@list_class"));

	SEEK(1); CALL(string_ignore);

	while (CURRENT != ')') {
		rb_funcall(result, rb_intern("<<"), 1, CALL(string_read_next));

		CALL(string_ignore);
	}

	SEEK(1);

	return result;
}

static VALUE string_read_vector (STATE)
{
	VALUE result = rb_class_new_instance(0, NULL, rb_iv_get(self, "@vector_class"));

	SEEK(1); CALL(string_ignore);

	while (CURRENT != ']') {
		rb_funcall(result, rb_intern("<<"), 1, CALL(string_read_next));

		CALL(string_ignore);
	}

	SEEK(1);

	return result;
}

static VALUE string_read_set (STATE)
{
	VALUE result = rb_class_new_instance(0, NULL, rb_iv_get(self, "@set_class"));

	SEEK(2); CALL(string_ignore);

	while (CURRENT != '}') {
		rb_funcall(result, rb_intern("<<"), 1, CALL(string_read_next));

		CALL(string_ignore);
	}

	SEEK(1);

	if (!NIL_P(rb_funcall(result, rb_intern("uniq!"), 0))) {
		rb_raise(rb_eSyntaxError, "the set contains non unique values");
	}

	return result;
}

static VALUE string_read_map (STATE)
{
	VALUE result = rb_class_new_instance(0, NULL, rb_iv_get(self, "@map_class"));
	VALUE key;
	VALUE value;

	SEEK(1); CALL(string_ignore);

	while (CURRENT != '}') {
		key = CALL(string_read_next);
		CALL(string_ignore);
		value = CALL(string_read_next);

		rb_funcall(result, rb_intern("[]="), 2, key, value);
	}

	SEEK(1);

	return result;
}

static VALUE string_read_next (STATE)
{
	CALL(string_ignore);

	if (IS_EOF) {
		rb_raise(rb_eSyntaxError, "unexpected EOF");
	}

	switch (CALL(string_next_type)) {
		case NODE_METADATA: return CALL(string_read_metadata);
		case NODE_NUMBER:   return CALL(string_read_number);
		case NODE_BOOLEAN:  return CALL(string_read_boolean);
		case NODE_NIL:      return CALL(string_read_nil);
		case NODE_CHAR:     return CALL(string_read_char);
		case NODE_KEYWORD:  return CALL(string_read_keyword);
		case NODE_STRING:   return CALL(string_read_string);
		case NODE_MAP:      return CALL(string_read_map);
		case NODE_LIST:     return CALL(string_read_list);
		case NODE_VECTOR:   return CALL(string_read_vector);
		case NODE_INSTANT:  return CALL(string_read_instant);
		case NODE_SET:      return CALL(string_read_set);
		case NODE_REGEXP:   return CALL(string_read_regexp);
	}
}

static VALUE string_parse (VALUE self)
{
	size_t position = 0;
	VALUE  source   = rb_iv_get(self, "@source");

	return string_read_next(self, StringValueCStr(source), &position);
}

#undef CALL
#undef STATE
#undef IS_EOF
#undef IS_EOF_AFTER
#undef CURRENT
#undef CURRENT_PTR
#undef AFTER
#undef AFTER_PTR
#undef BEFORE
#undef BEFORE_PTR
#undef SEEK
#undef IS_IGNORED
#undef IS_BOTH
#undef IS_KEYWORD
#undef IS_NOT_EOF_UP_TO
#undef IS_EQUAL_UP_TO
#undef IS_EQUAL
#endif
