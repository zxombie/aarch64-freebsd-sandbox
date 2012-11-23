
static void
puthex(unsigned long long data, int length)
{
	volatile unsigned int *uart = (unsigned int *)0x1c090000;
	char ch;

	if (length == 0)
		return;

	puthex(data >> 4, length - 1);
	ch = data & 0xf;
	if (ch <= 9)
		uart[0] = '0' + ch;
	else
		uart[0] = 'A' + ch - 0xa;
	
}

void
start(void *a, void *b, void *c)
{
	volatile unsigned int *uart = (unsigned int *)0x1c090000;

	puthex((unsigned long long)a, 16);
	uart[0] = '\r';
	uart[0] = '\n';
	puthex((unsigned long long)b, 16);
	uart[0] = '\r';
	uart[0] = '\n';
#if 0
	puthex((unsigned long long)c, 16);
	uart[0] = '\r';
	uart[0] = '\n';
#endif
	
	while(1);
}

