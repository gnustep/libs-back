.PHONY: all clean

all : backtrace.dll test.exe

backtrace.dll : backtrace.c
	gcc -O2 -shared -Wall -o $@ $^ -lbfd -lintl -liberty -limagehlp -lz

test.exe : test.c
	gcc -g -Wall -o $@ $^

clean :
	-rm -f backtrace.dll test.exe
