//
// intervaluegen.c
//
// Copyright 2023 Bo-Yuan Peng.
//

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdbool.h>
#include "intervaluegen.h"

#ifdef INTERVALUE_GEN

static char fn_ivg_template [] = "SNTRUP%d_IV%05d.json";
static char fn_ivg [100];

static FILE *fp_ivg = NULL;
static bool fp_first = true;

int ivg_fopen(int prime_p, int num) {
  sprintf(fn_ivg, fn_ivg_template, prime_p, num);
  if ( (fp_ivg = fopen(fn_ivg, "w")) == NULL ) {
    fprintf(stderr, "Coundn't open <%s> for write\n", fn_ivg);
    return IVG_FILE_OPEN_ERROR;
  } else {
    fprintf(fp_ivg, "{\n");
    fp_first = true;
    return IVG_SUCCESS;
  }
}

int ivg_fclose() {
  if ( fp_ivg != NULL ) {
    fprintf(fp_ivg, "\n }");
    if ( fclose(fp_ivg) != 0 ) {
      fprintf(stderr, "fp_ivg is not opened.\n");
      fp_ivg = NULL;
      return IVG_FILE_OPEN_ERROR;
    }
    fp_ivg = NULL;
  }
  return IVG_SUCCESS;
}

int ivg_print_int8array(char *str_n, int8_t *int_arr, int size) {
  if ( fp_ivg != NULL ) {
    if(!fp_first) fprintf(fp_ivg, " , \n");
    fprintf(fp_ivg, " \"%s\" :", str_n);
    if(size == 1) {
      fprintf(fp_ivg, " %4d }", int_arr[0]);
    } else if(size > 1) {
      fprintf(fp_ivg, " [");
      for(int idx = 0; idx < size; idx++) {
        if(idx != 0) fprintf(fp_ivg, ", ");
        fprintf(fp_ivg, " %4d", int_arr[idx]);
      }
      fprintf(fp_ivg, " ]");
    }
  }
  fp_first = false;
  return IVG_SUCCESS;
}

int ivg_print_int16array(char *str_n, int16_t *int_arr, int size) {
  if ( fp_ivg != NULL ) {
    if(!fp_first) fprintf(fp_ivg, " , \n");
    fprintf(fp_ivg, " \"%s\" :", str_n);
    if(size == 1) {
      fprintf(fp_ivg, " %5d }", int_arr[0]);
    } else if(size > 1) {
      fprintf(fp_ivg, " [");
      for(int idx = 0; idx < size; idx++) {
        if(idx != 0) fprintf(fp_ivg, ", ");
        fprintf(fp_ivg, " %5d", int_arr[idx]);
      }
      fprintf(fp_ivg, " ]");
    }
  }
  fp_first = false;
  return IVG_SUCCESS;
}

int ivg_print_uint8array(char *str_n, uint8_t *int_arr, int size) {
  if ( fp_ivg != NULL ) {
    if(!fp_first) fprintf(fp_ivg, " , \n");
    fprintf(fp_ivg, " \"%s\" :", str_n);
    if(size == 1) {
      fprintf(fp_ivg, " %3u }", int_arr[0]);
    } else if(size > 1) {
      fprintf(fp_ivg, " [");
      for(int idx = 0; idx < size; idx++) {
        if(idx != 0) fprintf(fp_ivg, ", ");
        fprintf(fp_ivg, " %3u", int_arr[idx]);
      }
      fprintf(fp_ivg, " ]");
    }
  }
  fp_first = false;
  return IVG_SUCCESS;
}

int ivg_print_uint16array(char *str_n, uint16_t *int_arr, int size) {
  if ( fp_ivg != NULL ) {
    if(!fp_first) fprintf(fp_ivg, " , \n");
    fprintf(fp_ivg, " \"%s\" :", str_n);
    if(size == 1) {
      fprintf(fp_ivg, " %4u }", int_arr[0]);
    } else if(size > 1) {
      fprintf(fp_ivg, " [");
      for(int idx = 0; idx < size; idx++) {
        if(idx != 0) fprintf(fp_ivg, ", ");
        fprintf(fp_ivg, " %4u", int_arr[idx]);
      }
      fprintf(fp_ivg, " ]");
    }
  }
  fp_first = false;
  return IVG_SUCCESS;
}



#endif

