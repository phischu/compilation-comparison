{-# LANGUAGE Haskell2010 #-}
{-# LINE 1 "Control/Debounce.hs" #-}
{-# LANGUAGE ScopedTypeVariables #-}
-- | Debounce an action, ensuring it doesn't occur more than once for a given
-- period of time.
--
-- This is useful as an optimization, for example to ensure that logs are only
-- flushed to disk at most once per second. See the fast-logger package for an
-- example usage.
--
-- Since 0.1.2
module Control.Debounce
    ( -- * Type
      DebounceSettings
    , defaultDebounceSettings
      -- * Accessors
    , debounceFreq
    , debounceAction
      -- * Creation
    , mkDebounce
    ) where

import           Control.Concurrent      (forkIO, threadDelay)
import           Control.Concurrent.MVar (newEmptyMVar, takeMVar, tryPutMVar)
import           Control.Exception       (SomeException, handle, mask_)
import           Control.Monad           (forever, void)

-- | Settings to control how debouncing should work.
--
-- This should be constructed using @defaultDebounceSettings@ and record
-- update syntax, e.g.:
--
-- @
-- let set = defaultDebounceSettings { debounceAction = flushLog }
-- @
--
-- Since 0.1.2
data DebounceSettings = DebounceSettings
    { debounceFreq   :: Int
    -- ^ Microseconds lag required between subsequence calls to the debounced
    -- action.
    --
    -- Default: 1 second (1000000)
    --
    -- Since 0.1.2
    , debounceAction :: IO ()
    -- ^ Action to be performed.
    --
    -- Note: all exceptions thrown by this action will be silently discarded.
    --
    -- Default: does nothing.
    --
    -- Since 0.1.2
    }

-- | Default value for creating a @DebounceSettings@.
--
-- Since 0.1.2
defaultDebounceSettings :: DebounceSettings
defaultDebounceSettings = DebounceSettings
    { debounceFreq = 1000000
    , debounceAction = return ()
    }

-- | Generate an action which will trigger the debounced action to be
-- performed. The action will either be performed immediately, or after the
-- current cooldown period has expired.
--
-- Since 0.1.2
mkDebounce :: DebounceSettings -> IO (IO ())
mkDebounce (DebounceSettings freq action) = do
    baton <- newEmptyMVar
    mask_ $ void $ forkIO $ forever $ do
        takeMVar baton
        ignoreExc action
        threadDelay freq
    return $ void $ tryPutMVar baton ()

ignoreExc :: IO () -> IO ()
ignoreExc = handle $ \(_ :: SomeException) -> return ()
