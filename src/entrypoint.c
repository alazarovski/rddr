#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

void R_init_rddr_extendr(DllInfo *dll);

void attribute_visible R_init_rddr(DllInfo *dll) {
    R_init_rddr_extendr(dll);
}
