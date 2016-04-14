{-# LANGUAGE Haskell98 #-}
{-# LINE 1 "Network/Wai/Handler/Warp/Timeout.hs" #-}













































































{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE MagicHash #-}
{-# LANGUAGE UnboxedTuples #-} -- for GHC 7.4 or earlier

-- |
--
-- In order to provide slowloris protection, Warp provides timeout handlers. We
-- follow these rules:
--
-- * A timeout is created when a connection is opened.
--
-- * When all request headers are read, the timeout is tickled.
--
-- * Every time at least 2048 bytes of the request body are read, the timeout
--   is tickled.
--
-- * The timeout is paused while executing user code. This will apply to both
--   the application itself, and a ResponseSource response. The timeout is
--   resumed as soon as we return from user code.
--
-- * Every time data is successfully sent to the client, the timeout is tickled.

module Network.Wai.Handler.Warp.Timeout (
  -- * Types
    Manager
  , TimeoutAction
  , Handle
  -- * Manager
  , initialize
  , stopManager
  , withManager
  -- * Registration
  , register
  , registerKillThread
  -- * Control
  , tickle
  , cancel
  , pause
  , resume
  -- * Exceptions
  , TimeoutThread (..)
  ) where


import Control.Concurrent (mkWeakThreadId, ThreadId)
import Control.Concurrent (myThreadId)
import qualified Control.Exception as E
import GHC.Weak (Weak (..))
import Network.Wai.Handler.Warp.IORef (IORef)
import qualified Network.Wai.Handler.Warp.IORef as I
import System.Mem.Weak (deRefWeak)
import Data.Typeable (Typeable)
import Control.Reaper

----------------------------------------------------------------

-- | A timeout manager
type Manager = Reaper [Handle] Handle

-- | An action to be performed on timeout.
type TimeoutAction = IO ()

-- | A handle used by 'Manager'
data Handle = Handle TimeoutAction (IORef State)

data State = Active    -- Manager turns it to Inactive.
           | Inactive  -- Manager removes it with timeout action.
           | Paused    -- Manager does not change it.
           | Canceled  -- Manager removes it without timeout action.

----------------------------------------------------------------

-- | Creating timeout manager which works every N micro seconds
--   where N is the first argument.
initialize :: Int -> IO Manager
initialize timeout = mkReaper defaultReaperSettings
        { reaperAction = mkListAction prune
        , reaperDelay = timeout
        }
  where
    prune m@(Handle onTimeout iactive) = do
        state <- I.atomicModifyIORef' iactive (\x -> (inactivate x, x))
        case state of
            Inactive -> do
                onTimeout `E.catch` ignoreAll
                return Nothing
            Canceled -> return Nothing
            _        -> return $ Just m

    inactivate Active = Inactive
    inactivate x = x

----------------------------------------------------------------

-- | Stopping timeout manager.
stopManager :: Manager -> IO ()
stopManager mgr = E.mask_ (reaperStop mgr >>= mapM_ fire)
  where
    fire (Handle onTimeout _) = onTimeout `E.catch` ignoreAll

ignoreAll :: E.SomeException -> IO ()
ignoreAll _ = return ()

----------------------------------------------------------------

-- | Registering a timeout action.
register :: Manager -> TimeoutAction -> IO Handle
register mgr onTimeout = do
    iactive <- I.newIORef Active
    let h = Handle onTimeout iactive
    reaperAdd mgr h
    return h

-- | Registering a timeout action of killing this thread.
registerKillThread :: Manager -> IO Handle
registerKillThread m = do
    wtid <- myThreadId >>= mkWeakThreadId
    register m $ killIfExist wtid

-- If ThreadId is hold referred by a strong reference,
-- it leaks even after the thread is killed.
-- So, let's use a weak reference so that CG can throw ThreadId away.
-- deRefWeak checks if ThreadId referenced by the weak reference
-- exists. If exists, it means that the thread is alive.
killIfExist :: Weak ThreadId -> TimeoutAction
killIfExist wtid = deRefWeak wtid >>= maybe (return ()) (`E.throwTo` TimeoutThread)

data TimeoutThread = TimeoutThread
    deriving Typeable
instance E.Exception TimeoutThread
instance Show TimeoutThread where
    show TimeoutThread = "Thread killed by Warp's timeout reaper"


----------------------------------------------------------------

-- | Setting the state to active.
--   'Manager' turns active to inactive repeatedly.
tickle :: Handle -> IO ()
tickle (Handle _ iactive) = I.writeIORef iactive Active

-- | Setting the state to canceled.
--   'Manager' eventually removes this without timeout action.
cancel :: Handle -> IO ()
cancel (Handle _ iactive) = I.writeIORef iactive Canceled

-- | Setting the state to paused.
--   'Manager' does not change the value.
pause :: Handle -> IO ()
pause (Handle _ iactive) = I.writeIORef iactive Paused

-- | Setting the paused state to active.
--   This is an alias to 'tickle'.
resume :: Handle -> IO ()
resume = tickle

----------------------------------------------------------------

-- | Call the inner function with a timeout manager.
withManager :: Int -- ^ timeout in microseconds
            -> (Manager -> IO a)
            -> IO a
withManager timeout f = do
    -- FIXME when stopManager is available, use it
    man <- initialize timeout
    f man
