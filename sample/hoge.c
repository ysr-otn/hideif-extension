#include <stdio.h>
#include "hoge.h"
#include <fuga.h>

#define AAA 10
#define BBB 20

int
main(int argc, char *argv[])
{

#ifdef HOGE
	printf("HOGE is defined.\n");
#endif
	
#if FUGA == 1
	printf("FUGA is 1.\n");
#elif FUGA == 2
	printf("FUGA is 2.\n");
#else
	printf("FUGA is more than 2.\n");
#endif	
	
#if PIYO == AAA
	printf("PIYO is AAA.\n");
#elif PIYO == BBB
	printf("PIYO is BBB.\n");
#else
	printf("PIYO is not AAA or BBB.\n");
#endif

	return 0;
}
