all:
	time ghc -j1 -v1 -fPIC -Iinclude cbits/*.c -hide-all-packages -package template-haskell -package base -package ghc-prim -package integer-gmp src/*.hs -lpthread -lz -lutil
	du src/Main
	strip src/Main
	du src/Main

clean:
	rm src/Main src/*.o src/*.hi src/*.dyn_hi src/*.dyn_o cbits/*.o
