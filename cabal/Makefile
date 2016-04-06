all:
	cabal sandbox init
	time cabal install -j1 --ghc-pkg-options="--global-package-db=$(CURDIR)/builtin_packages"
	du .cabal-sandbox/bin/my-server
	strip .cabal-sandbox/bin/my-server
	du .cabal-sandbox/bin/my-server

clean:
	cabal clean
	cabal sandbox delete
