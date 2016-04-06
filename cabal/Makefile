all:
	cabal sandbox init
	time cabal install --ghc-pkg-options="--global-package-db=$(CURDIR)/builtin_packages"

clean:
	cabal clean
	cabal sandbox delete
