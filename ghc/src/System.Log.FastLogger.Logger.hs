{-# LANGUAGE Haskell98 #-}
{-# LINE 1 "System/Log/FastLogger/Logger.hs" #-}























































{-# LANGUAGE BangPatterns, CPP #-}

module System.Log.FastLogger.Logger (
    Logger(..)
  , newLogger
  , pushLog
  , flushLog
  ) where

import Control.Concurrent (MVar, newMVar, withMVar)
import Control.Monad (when)
import Foreign.Ptr (plusPtr)
import GHC.IO.FD (FD, writeRawBufferPtr)
import System.Log.FastLogger.IO
import System.Log.FastLogger.LogStr
import System.Log.FastLogger.IORef

----------------------------------------------------------------

data Logger = Logger (MVar Buffer) !BufSize (IORef LogStr)

----------------------------------------------------------------

newLogger :: BufSize -> IO Logger
newLogger size = do
    buf <- getBuffer size
    mbuf <- newMVar buf
    lref <- newIORef mempty
    return $ Logger mbuf size lref

----------------------------------------------------------------

pushLog :: FD -> Logger -> LogStr -> IO ()
pushLog fd logger@(Logger mbuf size ref) nlogmsg@(LogStr nlen nbuilder)
  | nlen > size = do
      flushLog fd logger
      withMVar mbuf $ \buf -> toBufIOWith buf size (write fd) nbuilder
  | otherwise = do
    mmsg <- atomicModifyIORef' ref checkBuf
    case mmsg of
        Nothing  -> return ()
        Just msg -> withMVar mbuf $ \buf -> writeLogStr fd buf size msg
  where
    checkBuf ologmsg@(LogStr olen _)
      | size < olen + nlen = (nlogmsg, Just ologmsg)
      | otherwise          = (ologmsg <> nlogmsg, Nothing)

----------------------------------------------------------------

flushLog :: FD -> Logger -> IO ()
flushLog fd (Logger mbuf size lref) = do
    logmsg <- atomicModifyIORef' lref (\old -> (mempty, old))
    -- If a special buffer is prepared for flusher, this MVar could
    -- be removed. But such a code does not contribute logging speed
    -- according to experiment. And even with the special buffer,
    -- there is no grantee that this function is exclusively called
    -- for a buffer. So, we use MVar here.
    -- This is safe and speed penalty can be ignored.
    withMVar mbuf $ \buf -> writeLogStr fd buf size logmsg

----------------------------------------------------------------

-- | Writting 'LogStr' using a buffer in blocking mode.
--   The size of 'LogStr' must be smaller or equal to
--   the size of buffer.
writeLogStr :: FD
            -> Buffer
            -> BufSize
            -> LogStr
            -> IO ()
writeLogStr fd buf size (LogStr len builder)
  | size < len = error "writeLogStr"
  | otherwise  = toBufIOWith buf size (write fd) builder

write :: FD -> Buffer -> Int -> IO ()
write fd buf len' = loop buf (fromIntegral len')
  where
    loop bf !len = do
        written <- writeRawBufferPtr "write" fd bf 0 (fromIntegral len)
        when (written < len) $
            loop (bf `plusPtr` fromIntegral written) (len - written)
