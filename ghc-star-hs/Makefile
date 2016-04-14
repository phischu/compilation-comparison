all:
	time ghc -j1 -v1 -odir out -hidir out src/*.hs -fPIC -Iinclude cbits/*.c -hide-all-packages -package template-haskell -package base -package ghc-prim -package integer-gmp -lpthread -lz -lutil
	du src/Main
	strip src/Main
	du src/Main

clean:
	rm -r src/Main out/*
