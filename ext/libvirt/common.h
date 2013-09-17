#ifndef COMMON_H
#define COMMON_H

/* Macros to ease some of the boilerplate */
VALUE ruby_libvirt_new_class(VALUE klass, void *ptr, VALUE conn,
                             RUBY_DATA_FUNC free_func);

#define ruby_libvirt_get_struct(kind, v)                                \
    do {                                                                \
        vir##kind##Ptr ptr;                                             \
        Data_Get_Struct(v, vir##kind, ptr);                             \
        if (!ptr) {                                                     \
            rb_raise(rb_eArgError, #kind " has been freed");            \
        }                                                               \
        return ptr;                                                     \
    } while (0);

#define ruby_libvirt_free_struct(kind, p)                               \
    do {                                                                \
        int r;                                                          \
        r = vir##kind##Free((vir##kind##Ptr) p);                        \
        if (r < 0) {                                                    \
            rb_raise(rb_eSystemCallError, # kind " free failed");       \
        }                                                               \
    } while(0);

VALUE ruby_libvirt_create_error(VALUE error, const char* method,
                                virConnectPtr conn);

/*
 * Code generating macros.
 *
 * We only generate function bodies, not the whole function
 * declaration.
 */

/* Generate a call to a function FUNC which returns a string. The Ruby
 * function will return the string on success and throw an exception on
 * error. The string returned by FUNC is freed if dealloc is true.
 */
#define ruby_libvirt_generate_call_string(func, conn, dealloc, args...) \
    do {                                                                \
        const char *str;                                                \
        VALUE result;                                                   \
        int exception;                                                  \
                                                                        \
        str = func(args);                                               \
        _E(str == NULL, ruby_libvirt_create_error(e_Error, # func, conn));           \
                                                                        \
        if (dealloc) {                                                  \
            result = rb_protect(ruby_libvirt_str_new2_wrap, (VALUE)&str, &exception); \
            xfree((void *) str);                                        \
            if (exception) {                                            \
                rb_jump_tag(exception);                                 \
            }                                                           \
        }                                                               \
        else {                                                          \
            result = rb_str_new2(str);                                  \
        }                                                               \
        return result;                                                  \
    } while(0)

/* Generate a call to vir##KIND##Free and return Qnil. Set the the embedded
 * vir##KIND##Ptr to NULL. If that pointer is already NULL, do nothing.
 */
#define ruby_libvirt_generate_call_free(kind, s)                        \
    do {                                                                \
        vir##kind##Ptr ptr;                                             \
        Data_Get_Struct(s, vir##kind, ptr);                             \
        if (ptr != NULL) {                                              \
            int r = vir##kind##Free(ptr);                               \
            _E(r < 0, ruby_libvirt_create_error(e_Error, "vir" #kind "Free", ruby_libvirt_connect_get(s))); \
            DATA_PTR(s) = NULL;                                         \
        }                                                               \
        return Qnil;                                                    \
    } while (0)

/* Generate a call to a function FUNC which returns an int error, where -1
 * indicates error and 0 success. The Ruby function will return Qnil on
 * success and throw an exception on error.
 */
#define ruby_libvirt_generate_call_nil(func, conn, args...)             \
    do {                                                                \
        int _r_##func;                                                  \
        _r_##func = func(args);                                         \
        _E(_r_##func < 0, ruby_libvirt_create_error(e_Error, #func, conn));          \
        return Qnil;                                                    \
    } while(0)

/* Generate a call to a function FUNC which returns an int; -1 indicates
 * error, 0 indicates Qfalse, and 1 indicates Qtrue.
 */
#define ruby_libvirt_generate_call_truefalse(func, conn, args...)       \
    do {                                                                \
        int _r_##func;                                                  \
        _r_##func = func(args);                                         \
        _E(_r_##func < 0, ruby_libvirt_create_error(e_Error, #func, conn));          \
        return _r_##func ? Qtrue : Qfalse;                              \
    } while(0)

/* Generate a call to a function FUNC which returns an int error, where -1
 * indicates error and >= 0 success. The Ruby function will return the integer
 * success and throw an exception on error.
 */
#define ruby_libvirt_generate_call_int(func, conn, args...)             \
    do {                                                                \
        int _r_##func;                                                  \
        _r_##func = func(args);                                         \
        _E(_r_##func < 0, ruby_libvirt_create_error(e_RetrieveError, #func, conn));  \
        return INT2NUM(_r_##func);                                      \
    } while(0)

#define ruby_libvirt_generate_call_list_all(type, argc, argv, listfunc, object, val, newfunc, freefunc) \
    do {                                                                \
        VALUE flags;                                                    \
        type *list;                                                     \
        size_t i;                                                       \
        int ret;                                                        \
        VALUE result;                                                   \
        int exception = 0;                                              \
        struct ruby_libvirt_ary_push_arg arg;                           \
                                                                        \
        rb_scan_args(argc, argv, "01", &flags);                         \
        flags = ruby_libvirt_fixnum_set(flags, 0);                      \
        ret = listfunc(object, &list, NUM2UINT(flags));                 \
        _E(ret < 0, ruby_libvirt_create_error(e_RetrieveError, #listfunc, ruby_libvirt_connect_get(val))); \
        result = rb_protect(ruby_libvirt_ary_new2_wrap, (VALUE)&ret, &exception); \
        if (exception) {                                                \
            goto exception;                                             \
        }                                                               \
        for (i = 0; i < ret; i++) {                                     \
            arg.arr = result;                                           \
            arg.value = newfunc(list[i], val);                          \
            rb_protect(ruby_libvirt_ary_push_wrap, (VALUE)&arg, &exception); \
            if (exception) {                                            \
                goto exception;                                         \
            }                                                           \
        }                                                               \
                                                                        \
        free(list);                                                     \
                                                                        \
        return result;                                                  \
                                                                        \
    exception:                                                          \
        for (i = 0; i < ret; i++) {                                     \
            freefunc(list[i]);                                          \
        }                                                               \
        free(list);                                                     \
        rb_jump_tag(exception);                                         \
                                                                        \
        /* not needed, but here to shut the compiler up */              \
        return Qnil;                                                    \
    } while(0)

/* Error handling */
#define _E(cond, excep) \
    do { if (cond) rb_exc_raise(excep); } while(0)

int ruby_libvirt_is_symbol_or_proc(VALUE handle);

extern VALUE e_RetrieveError;
extern VALUE e_Error;
extern VALUE e_DefinitionError;
extern VALUE e_NoSupportError;

extern VALUE m_libvirt;

char *ruby_libvirt_get_cstring_or_null(VALUE arg);

VALUE ruby_libvirt_generate_list(int num, char **list);

VALUE ruby_libvirt_get_typed_parameters(int argc, VALUE *argv, VALUE d,
                                        virConnectPtr conn,
                                        int (*nparams_cb)(VALUE d,
                                                          unsigned int flags),
                                        char *(*get_cb)(VALUE d,
                                                        unsigned int flags,
                                                        virTypedParameterPtr params,
                                                        int *nparams));
VALUE ruby_libvirt_set_typed_parameters(VALUE d, VALUE in, virConnectPtr conn,
                                        int has_flags,
                                        int (*nparams_cb)(VALUE d,
                                                          unsigned int flags),
                                        char *(*get_cb)(VALUE d,
                                                        unsigned int flags,
                                                        virTypedParameterPtr params,
                                                        int *nparams),
                                        char *(*set_cb)(VALUE d,
                                                        unsigned int flags,
                                                        virTypedParameterPtr params,
                                                        int nparams));

VALUE ruby_libvirt_fixnum_set(VALUE in, int def);

VALUE ruby_libvirt_ary_new2_wrap(VALUE arg);
struct ruby_libvirt_ary_push_arg {
    VALUE arr;
    VALUE value;
};
VALUE ruby_libvirt_ary_push_wrap(VALUE arg);
struct ruby_libvirt_ary_store_arg {
    VALUE arr;
    long index;
    VALUE elem;
};
VALUE ruby_libvirt_ary_store_wrap(VALUE arg);

VALUE ruby_libvirt_str_new2_wrap(VALUE arg);
struct ruby_libvirt_str_new_arg {
    char *val;
    size_t size;
};
VALUE ruby_libvirt_str_new_wrap(VALUE arg);

#ifndef RARRAY_LEN
#define RARRAY_LEN(ar) (RARRAY(ar)->len)
#endif

#ifndef RSTRING_PTR
#define RSTRING_PTR(str) (RSTRING(str)->ptr)
#endif

#ifndef RSTRING_LEN
#define RSTRING_LEN(str) (RSTRING(str)->len)
#endif

#endif
