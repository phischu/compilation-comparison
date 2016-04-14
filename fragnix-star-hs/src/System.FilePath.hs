{-# LANGUAGE Haskell98 #-}
{-# LINE 1 "System/FilePath.hs" #-}









































{-# LANGUAGE CPP #-}
{-# LANGUAGE Safe #-}
{- |
Module      :  System.FilePath
Copyright   :  (c) Neil Mitchell 2005-2007
License     :  BSD3

Maintainer  :  libraries@haskell.org
Stability   :  stable
Portability :  portable

A library for 'FilePath' manipulations, using Posix or Windows filepaths
depending on the platform.

Both "System.FilePath.Posix" and "System.FilePath.Windows" provide the
same interface. See either for examples and a list of the available
functions.
-}

module System.FilePath(module System.FilePath.Posix) where
import System.FilePath.Posix

