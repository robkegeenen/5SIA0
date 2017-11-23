#include <stdint.h>
#include <limits.h>
#include <stdio.h>

#define order 10
#define SCALE 16
#define NP 2000

static const int32_t a[order+1] = {65536, 0, -64572, 0, 63818, 0, -25323, 0, 7287, 0, -740};
static const int32_t b[order+1] = {7104, 0, -35513, 0, 71021, 0, -71021, 0, 35513, 0, -7104};

void bw0_int(int np, int32_t *xi, int32_t *yo)
{
  int i, j;
  int32_t yy;

  static int32_t x[order+1];
  static int32_t y[order+1];

  while(np--)
    {
      for (i=1; i<=order; i++)
        {
          x[i-1]=x[i];
          y[i-1]=y[i];
        }

      i = order;
      x[i] = *xi++;
      yy = 0;

      for (j=0;j<order+1;j++)
        yy = yy + (uint32_t)(((int64_t)(b[j])*(int64_t)(x[i-j])) >> SCALE);
      for (j=0;j<order;j++)
        yy = yy - (int32_t)(((int64_t)(a[j+1])*(int64_t)(y[i-j-1])) >> SCALE);
      *yo++ = y[i] = yy;
    }
}

void main(void)
{
  int i;
  int32_t xi[NP], yo[NP];
  int32_t iReadData;
  FILE * fInput;
  FILE * fOutput;

  fInput = fopen("xi.txt","r");
  while(fscanf(fInput,"%d",&iReadData)==1)
    xi[i++] = iReadData;
  fclose(fInput);

  bw0_int(NP, xi, yo);

  fOutput = fopen("yo.txt","w");
  for(i=0; i<20; i++)
    fprintf(fOutput, "%d\n",yo[i]);
  fclose(fOutput);
}
