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

VALUE cClojure;
VALUE cParser;

#define _INSIDE_PARSER
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
	NODE_REGEXP
} NodeType;

#include "string_parser.c"
#include "io_parser.c"
#undef _INSIDE_PARSER

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

	if (NIL_P(tmp = rb_hash_aref(options, rb_intern("map_class")))) {
		rb_iv_set(self, "@map_class", tmp);
	}
	else {
		rb_iv_set(self, "@map_class", rb_const_get(cClojure, rb_intern("Map")));
	}

	if (NIL_P(tmp = rb_hash_aref(options, rb_intern("vector_class")))) {
		rb_iv_set(self, "@vector_class", tmp);
	}
	else {
		rb_iv_set(self, "@vector_class", rb_const_get(cClojure, rb_intern("Vector")));
	}

	if (NIL_P(tmp = rb_hash_aref(options, rb_intern("list_class")))) {
		rb_iv_set(self, "@list_class", tmp);
	}
	else {
		rb_iv_set(self, "@list_class", rb_const_get(cClojure, rb_intern("Vector")));
	}

	if (NIL_P(tmp = rb_hash_aref(options, rb_intern("set_class")))) {
		rb_iv_set(self, "@set_class", tmp);
	}
	else {
		rb_iv_set(self, "@set_class", rb_const_get(cClojure, rb_intern("Vector")));
	}

	return self;
}

static VALUE t_parse (VALUE self)
{
	VALUE source = rb_iv_get(self, "@source");

	if (rb_obj_is_kind_of(source, rb_cString)) {
		return string_parse(self);
	}
	else if (rb_obj_is_kind_of(source, rb_cIO)) {
		return io_parse(self);
	}
}

void
Init_parser_ext (void)
{
	cClojure = rb_const_get(rb_cObject, rb_intern("Clojure"));
	cParser  = rb_define_class_under(cClojure, "Parser", rb_cObject);

	rb_define_method(cParser, "initialize", t_init, -1);
	rb_define_method(cParser, "parse", t_parse, 0);
}
