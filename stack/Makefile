all:
	time stack build
	du .stack-work/install/x86_64-linux/lts-2.22/7.8.4/bin/my-server
	strip .stack-work/install/x86_64-linux/lts-2.22/7.8.4/bin/my-server
	du .stack-work/install/x86_64-linux/lts-2.22/7.8.4/bin/my-server

clean:
	stack clean
	rm -r .stack-work
	rm -r ~/.stack/snapshots/x86_64-linux/lts-2.22
