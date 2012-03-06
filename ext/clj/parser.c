/**
 *            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
 *                    Version 2, December 2004
 *
 *            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 *
 *  0. You just DO WHAT THE FUCK YOU WANT TO.
 **/

#include <stdbool.h>
#include <ctype.h>

#include "ruby.h"

static VALUE cClojure;
static VALUE cParser;

static VALUE UNICODE_REGEX;
static VALUE OCTAL_REGEX;

typedef enum {
	NODE_METADATA,
	NODE_NUMBER,
	NODE_BOOLEAN,
	NODE_NIL,
	NODE_CHAR,
	NODE_KEYWORD,
	NODE_STRING,
	NODE_MAP,
	NODE_LIST,
	NODE_VECTOR,
	NODE_INSTANT,
	NODE_SET,
	NODE_REGEXP,
	NODE_SYMBOL
} NodeType;

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
#define IS_NOT_EOF_UP_TO(n) (is_not_eof_up_to(string, position, n))
#define IS_EQUAL_UP_TO(str, n) (strncmp(CURRENT_PTR, str, (n)) == 0)
#define IS_EQUAL(str) IS_EQUAL_UP_TO(str, strlen(str))
#define IS_IGNORED(ch) (isspace(ch) || ch == ',')
#define IS_SYMBOL(ch) (isdigit(ch) || isalpha(ch) || ch == '+' || ch == '!' || ch == '-' || ch == '_' || ch == '?' || ch == '.' || ch == ':' || ch == '/')
#define IS_BOTH_SEPARATOR(ch) (ch == '\0' || ch == ' ' || ch == ',' || ch == '"' || ch == '{' || ch == '}' || ch == '(' || ch == ')' || ch == '[' || ch == ']' || ch == '#' || ch == ':' || ch == '\n' || ch == '\r' || ch == '\t')
#define IS_KEYWORD_SEPARATOR(ch) (ch == '\0' || ch == ' ' || ch == ',' || ch == '"' || ch == '{' || ch == '}' || ch == '(' || ch == ')' || ch == '[' || ch == ']' || ch == '#' || ch == ':' || ch == '\'' || ch == '^' || ch == '@' || ch == '`' || ch == '~' || ch == '\\' || ch == ';' || ch == '\n' || ch == '\r' || ch == '\t')

static VALUE read_next (STATE);

static inline bool is_not_eof_up_to (char* string, size_t* position, size_t n)
{
	size_t i;

	for (i = 0; i < n; i++) {
		if (IS_EOF_AFTER(i)) {
			return false;
		}
	}

	return true;
}

static void ignore (STATE)
{
	while (!IS_EOF && IS_IGNORED(CURRENT)) {
		SEEK(1);
	}
}

static NodeType next_type (STATE)
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

	return NODE_SYMBOL;
}

static VALUE read_metadata (STATE)
{
	VALUE  result;
	VALUE* metadatas = NULL;
	size_t length    = 0;
	size_t i;

	while (CURRENT == '^') {
		metadatas = realloc(metadatas, ++length * sizeof(VALUE));

		SEEK(1);

		metadatas[length - 1] = CALL(read_next);
	}

	result = CALL(read_next);

	if (!rb_respond_to(result, rb_intern("metadata="))) {
		free(metadatas);

		rb_raise(rb_eSyntaxError, "the object cannot hold metadata");
	}

	// FIXME: this could lead to a memleak if #metadata= raises
	for (i = 0; i < length; i++) {
		rb_funcall(result, rb_intern("metadata="), 1, metadatas[i]);
	}

	free(metadatas);

	return result;
}

static VALUE read_symbol (STATE)
{
	size_t length = 0;

	while (IS_SYMBOL(AFTER(length))) {
		length++;
	}

	SEEK(length);

	return rb_funcall(rb_funcall(rb_str_new(BEFORE_PTR(length), length), rb_intern("to_sym"), 0),
		rb_intern("symbol!"), 0);
}

static VALUE read_nil (STATE)
{
	if (!IS_NOT_EOF_UP_TO(3) || !IS_EQUAL_UP_TO("nil", 3) || !IS_BOTH_SEPARATOR(AFTER(3))) {
		return CALL(read_symbol);
	}

	SEEK(3);

	return Qnil;
}

static VALUE read_boolean (STATE)
{
	if (CURRENT == 't') {
		if (!IS_NOT_EOF_UP_TO(4) || !IS_EQUAL_UP_TO("true", 4) || !IS_BOTH_SEPARATOR(AFTER(4))) {
			return CALL(read_symbol);
		}
		
		SEEK(4);

		return Qtrue;
	}
	else {
		if (!IS_NOT_EOF_UP_TO(5) || !IS_EQUAL_UP_TO("false", 5) || !IS_BOTH_SEPARATOR(AFTER(5))) {
			return CALL(read_symbol);
		}

		SEEK(5);

		return Qfalse;
	}
}

static VALUE read_number (STATE)
{
	size_t length = 0;
	VALUE  rbPiece;
	char*  cPiece;
	char*  tmp;

	while (!IS_EOF_AFTER(length) && !IS_BOTH_SEPARATOR(AFTER(length))) {
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

static VALUE read_char (STATE)
{
	SEEK(1);

	if (IS_EOF_AFTER(1) || IS_BOTH_SEPARATOR(AFTER(1))) {
		SEEK(1); return rb_str_new(BEFORE_PTR(1), 1);
	}
	else if (IS_NOT_EOF_UP_TO(7) && IS_EQUAL_UP_TO("newline", 7) && IS_BOTH_SEPARATOR(AFTER(7))) {
		SEEK(7); return rb_str_new2("\n");
	}
	else if (IS_NOT_EOF_UP_TO(5) && IS_EQUAL_UP_TO("space", 5) && IS_BOTH_SEPARATOR(AFTER(5))) {
		SEEK(5); return rb_str_new2(" ");
	}
	else if (IS_NOT_EOF_UP_TO(3) && IS_EQUAL_UP_TO("tab", 3) && IS_BOTH_SEPARATOR(AFTER(3))) {
		SEEK(3); return rb_str_new2("\t");
	}
	else if (IS_NOT_EOF_UP_TO(9) && IS_EQUAL_UP_TO("backspace", 9) && IS_BOTH_SEPARATOR(AFTER(9))) {
		SEEK(9); return rb_str_new2("\b");
	}
	else if (IS_NOT_EOF_UP_TO(8) && IS_EQUAL_UP_TO("formfeed", 8) && IS_BOTH_SEPARATOR(AFTER(8))) {
		SEEK(8); return rb_str_new2("\f");
	}
	else if (IS_NOT_EOF_UP_TO(6) && IS_EQUAL_UP_TO("return", 6) && IS_BOTH_SEPARATOR(AFTER(6))) {
		SEEK(6); return rb_str_new2("\r");
	}
	else if (CURRENT == 'u' && IS_NOT_EOF_UP_TO(5) && !NIL_P(rb_funcall(rb_str_new(AFTER_PTR(1), 4), rb_intern("=~"), 1, UNICODE_REGEX)) && IS_BOTH_SEPARATOR(AFTER(5))) {
		SEEK(5); return rb_funcall(rb_ary_new3(1, rb_funcall(rb_str_new(BEFORE_PTR(4), 4), rb_intern("to_i"), 1, INT2FIX(16))),
			rb_intern("pack"), 1, rb_str_new2("U"));
	}
	else if (CURRENT == 'o') {
		size_t length = 1;
		size_t i;

		for (i = 1; i < 5; i++) {
			if (IS_BOTH_SEPARATOR(AFTER(i))) {
				break;
			}

			length++;
		}

		if (length > 1 && !NIL_P(rb_funcall(rb_str_new(AFTER_PTR(1), length - 1), rb_intern("=~"), 1, OCTAL_REGEX)) && IS_BOTH_SEPARATOR(AFTER(length))) {
			SEEK(length); return rb_funcall(rb_funcall(rb_str_new(BEFORE_PTR(length - 1), length - 1), rb_intern("to_i"), 1, INT2FIX(8)),
				rb_intern("chr"), 0);
		}
	}

	rb_raise(rb_eSyntaxError, "unknown character type");
}

static VALUE read_keyword (STATE)
{
	size_t length = 0;

	SEEK(1);

	while (!IS_KEYWORD_SEPARATOR(AFTER(length))) {
		length++;
	}

	SEEK(length);

	return rb_funcall(rb_funcall(rb_str_new(BEFORE_PTR(length), length), rb_intern("to_sym"), 0),
		rb_intern("keyword!"), 0);
}

static VALUE read_string (STATE)
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

	return rb_funcall(cClojure, rb_intern("unescape"), 1, rb_str_new(BEFORE_PTR(length + 1), length));
}

static VALUE read_regexp (STATE)
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

static VALUE read_instant (STATE)
{
	SEEK(1);

	if (!IS_NOT_EOF_UP_TO(4)) {
		rb_raise(rb_eSyntaxError, "unexpected EOF");
	}

	if (!IS_EQUAL_UP_TO("inst", 4)) {
		rb_raise(rb_eSyntaxError, "expected inst, got %c%c%c%c", AFTER(0), AFTER(1), AFTER(2), AFTER(3));
	}

	SEEK(4);

	CALL(ignore);

	return rb_funcall(rb_const_get(rb_cObject, rb_intern("DateTime")), rb_intern("rfc3339"), 1, CALL(read_string));
}

static VALUE read_list (STATE)
{
	VALUE result = rb_class_new_instance(0, NULL, rb_iv_get(self, "@list_class"));

	SEEK(1); CALL(ignore);

	while (CURRENT != ')') {
		rb_funcall(result, rb_intern("<<"), 1, CALL(read_next));

		CALL(ignore);
	}

	SEEK(1);

	return result;
}

static VALUE read_vector (STATE)
{
	VALUE result = rb_class_new_instance(0, NULL, rb_iv_get(self, "@vector_class"));

	SEEK(1); CALL(ignore);

	while (CURRENT != ']') {
		rb_funcall(result, rb_intern("<<"), 1, CALL(read_next));

		CALL(ignore);
	}

	SEEK(1);

	return result;
}

static VALUE read_set (STATE)
{
	VALUE result = rb_class_new_instance(0, NULL, rb_iv_get(self, "@set_class"));

	SEEK(2); CALL(ignore);

	while (CURRENT != '}') {
		rb_funcall(result, rb_intern("<<"), 1, CALL(read_next));

		CALL(ignore);
	}

	SEEK(1);

	if (!NIL_P(rb_funcall(result, rb_intern("uniq!"), 0))) {
		rb_raise(rb_eSyntaxError, "the set contains non unique values");
	}

	return result;
}

static VALUE read_map (STATE)
{
	VALUE result = rb_class_new_instance(0, NULL, rb_iv_get(self, "@map_class"));
	VALUE key;
	VALUE value;

	SEEK(1); CALL(ignore);

	while (CURRENT != '}') {
		key = CALL(read_next);
		CALL(ignore);
		value = CALL(read_next);

		rb_funcall(result, rb_intern("[]="), 2, key, value);
	}

	SEEK(1);

	return result;
}

static VALUE read_next (STATE)
{
	CALL(ignore);

	if (IS_EOF) {
		rb_raise(rb_eSyntaxError, "unexpected EOF");
	}

	switch (CALL(next_type)) {
		case NODE_METADATA: return CALL(read_metadata);
		case NODE_NUMBER:   return CALL(read_number);
		case NODE_BOOLEAN:  return CALL(read_boolean);
		case NODE_NIL:      return CALL(read_nil);
		case NODE_CHAR:     return CALL(read_char);
		case NODE_KEYWORD:  return CALL(read_keyword);
		case NODE_STRING:   return CALL(read_string);
		case NODE_MAP:      return CALL(read_map);
		case NODE_LIST:     return CALL(read_list);
		case NODE_VECTOR:   return CALL(read_vector);
		case NODE_INSTANT:  return CALL(read_instant);
		case NODE_SET:      return CALL(read_set);
		case NODE_REGEXP:   return CALL(read_regexp);
		case NODE_SYMBOL:   return CALL(read_symbol);
	}
}

static VALUE t_init (int argc, VALUE* argv, VALUE self)
{
	VALUE tmp;
	VALUE source;
	VALUE options;

	if (argc < 1) {
		rb_raise(rb_eArgError, "wrong number of arguments (0 for 1)");
	}
	else if (argc > 2) {
		rb_raise(rb_eArgError, "wrong number of arguments (%d for 2)", argc);
	}

	if (!rb_obj_is_kind_of(argv[0], rb_cString) && !rb_obj_is_kind_of(argv[0], rb_cIO)) {
		rb_raise(rb_eArgError, "you have to pass a String or an IO");
	}

	source  = argv[0];
	options = argc == 2 ? argv[1] : rb_hash_new();

	rb_iv_set(self, "@source", source);
	rb_iv_set(self, "@options", options);

	if (!NIL_P(tmp = rb_hash_aref(options, rb_intern("map_class")))) {
		rb_iv_set(self, "@map_class", tmp);
	}
	else {
		rb_iv_set(self, "@map_class", rb_const_get(cClojure, rb_intern("Map")));
	}

	if (!NIL_P(tmp = rb_hash_aref(options, rb_intern("vector_class")))) {
		rb_iv_set(self, "@vector_class", tmp);
	}
	else {
		rb_iv_set(self, "@vector_class", rb_const_get(cClojure, rb_intern("Vector")));
	}

	if (!NIL_P(tmp = rb_hash_aref(options, rb_intern("list_class")))) {
		rb_iv_set(self, "@list_class", tmp);
	}
	else {
		rb_iv_set(self, "@list_class", rb_const_get(cClojure, rb_intern("Vector")));
	}

	if (!NIL_P(tmp = rb_hash_aref(options, rb_intern("set_class")))) {
		rb_iv_set(self, "@set_class", tmp);
	}
	else {
		rb_iv_set(self, "@set_class", rb_const_get(cClojure, rb_intern("Vector")));
	}

	return self;
}

static VALUE t_parse (VALUE self)
{
	size_t position = 0;
	VALUE  source   = rb_iv_get(self, "@source");

	if (!rb_obj_is_kind_of(source, rb_cString)) {
		if (rb_obj_is_kind_of(source, rb_cIO)) {
			source = rb_funcall(source, rb_intern("read"), 0);
		}
		else {
			source = rb_funcall(source, rb_intern("to_str"), 0);
		}
	}

	return read_next(self, StringValueCStr(source), &position);
}

void
Init_parser_ext (void)
{
	cClojure = rb_const_get(rb_cObject, rb_intern("Clojure"));
	cParser  = rb_define_class_under(cClojure, "Parser", rb_cObject);

	rb_define_method(cParser, "initialize", t_init, -1);
	rb_define_method(cParser, "parse", t_parse, 0);

	VALUE args[] = { Qnil };

	args[0]       = rb_str_new2("[0-9|a-f|A-F]{4}");
	UNICODE_REGEX = rb_class_new_instance(1, args, rb_cRegexp);
	rb_define_const(cClojure, "UNICODE_REGEX", UNICODE_REGEX);

	args[0]     = rb_str_new2("[0-3]?[0-7]?[0-7]");
	OCTAL_REGEX = rb_class_new_instance(1, args, rb_cRegexp);
	rb_define_const(cClojure, "OCTAL_REGEX", OCTAL_REGEX);
}
