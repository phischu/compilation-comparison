{-# LANGUAGE Haskell2010 #-}
{-# LINE 1 "dist/dist-sandbox-60209c9d/build/System/Posix/Signals/Exts.hs" #-}




















































{-# LINE 1 "System/Posix/Signals/Exts.hsc" #-}
{-# LANGUAGE CPP #-}
{-# LINE 2 "System/Posix/Signals/Exts.hsc" #-}
{-# LANGUAGE Safe #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  System.Posix.Signals.Exts
-- Copyright   :  (c) The University of Glasgow 2002
-- License     :  BSD-style (see the file libraries/base/LICENSE)
--
-- Maintainer  :  libraries@haskell.org
-- Stability   :  provisional
-- Portability :  non-portable (requires POSIX, includes Linuxisms/BSDisms)
--
-- non-POSIX signal support commonly available
--
-----------------------------------------------------------------------------


{-# LINE 19 "System/Posix/Signals/Exts.hsc" #-}
























































































































































































































































































































{-# LINE 22 "System/Posix/Signals/Exts.hsc" #-}

{-# LINE 23 "System/Posix/Signals/Exts.hsc" #-}

{-# LINE 24 "System/Posix/Signals/Exts.hsc" #-}

module System.Posix.Signals.Exts (
  module System.Posix.Signals
  , sigINFO
  , sigWINCH
  , infoEvent
  , windowChange
  ) where

import Foreign.C
import System.Posix.Signals

sigINFO   :: CInt
sigINFO   = -1

sigWINCH   :: CInt
sigWINCH   = 28


infoEvent :: Signal
infoEvent = sigINFO

windowChange :: Signal
windowChange = sigWINCH