all: 1 2 3 4 5

1:
	cat result1 | ./hex2raw | ./ctarget -q

2:
	gcc -c 2.s
	objdump -d 2.o
	cat result2 | ./hex2raw > raw
	cat result2 | ./hex2raw | ./ctarget -q

3:
	gcc -c 3.s
	objdump -d 3.o
	cat result3 | ./hex2raw > raw
	cat result3 | ./hex2raw | ./ctarget -q

4:
	gcc -c 4.s
	objdump -d 4.o
	cat result4 | ./hex2raw > raw
	cat result4 | ./hex2raw | ./rtarget -q

5:
	gcc -c 5.s
	objdump -d 5.o
	cat result5 | ./hex2raw > raw
	cat result5 | ./hex2raw | ./rtarget -q

clean:
	rm -rf *.o