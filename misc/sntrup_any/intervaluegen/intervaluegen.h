#ifdef INTERVALUE_GEN

#ifndef IVG_DEFINE
  #define IVG_DEFINE

  #define IVG_SUCCESS         (0)
  #define IVG_FILE_OPEN_ERROR (-1)
  #define IVG_DATA_ERROR      (-3)
#endif

#include <stdint.h>

int ivg_fopen(int, int);

int ivg_fclose();

int ivg_print_int8array(char *, int8_t *, int);
int ivg_print_int16array(char *, int16_t *, int);
int ivg_print_uint8array(char *, uint8_t *, int);
int ivg_print_uint16array(char *, uint16_t *, int);

#endif
