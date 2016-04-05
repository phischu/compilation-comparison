all:
	time ghc -v1 -fPIC -Iinclude cbits/*.c -hide-all-packages -package template-haskell -package base -package ghc-prim -package integer-gmp src/*.hs -lpthread -lz -lutil

clean:
	rm src/Main src/*.o src/*.hi src/*.dyn_hi src/*.dyn_o cbits/*.o
