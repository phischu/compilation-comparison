{-# LANGUAGE Haskell2010 #-}
{-# LINE 1 "dist/dist-sandbox-60209c9d/build/System/Posix/Directory/ByteString.hs" #-}
{-# LINE 1 "System/Posix/Directory/ByteString.hsc" #-}
{-# LANGUAGE CApiFFI #-}
{-# LINE 2 "System/Posix/Directory/ByteString.hsc" #-}
{-# LANGUAGE NondecreasingIndentation #-}

{-# LINE 4 "System/Posix/Directory/ByteString.hsc" #-}
{-# LANGUAGE Safe #-}

{-# LINE 8 "System/Posix/Directory/ByteString.hsc" #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  System.Posix.Directory.ByteString
-- Copyright   :  (c) The University of Glasgow 2002
-- License     :  BSD-style (see the file libraries/base/LICENSE)
--
-- Maintainer  :  libraries@haskell.org
-- Stability   :  provisional
-- Portability :  non-portable (requires POSIX)
--
-- String-based POSIX directory support
--
-----------------------------------------------------------------------------


{-# LINE 24 "System/Posix/Directory/ByteString.hsc" #-}

-- hack copied from System.Posix.Files

{-# LINE 29 "System/Posix/Directory/ByteString.hsc" #-}

module System.Posix.Directory.ByteString (
   -- * Creating and removing directories
   createDirectory, removeDirectory,

   -- * Reading directories
   DirStream,
   openDirStream,
   readDirStream,
   rewindDirStream,
   closeDirStream,
   DirStreamOffset,

{-# LINE 42 "System/Posix/Directory/ByteString.hsc" #-}
   tellDirStream,

{-# LINE 44 "System/Posix/Directory/ByteString.hsc" #-}

{-# LINE 45 "System/Posix/Directory/ByteString.hsc" #-}
   seekDirStream,

{-# LINE 47 "System/Posix/Directory/ByteString.hsc" #-}

   -- * The working dirctory
   getWorkingDirectory,
   changeWorkingDirectory,
   changeWorkingDirectoryFd,
  ) where

import System.IO.Error
import System.Posix.Types
import Foreign
import Foreign.C

import Data.ByteString.Char8 as BC

import System.Posix.Directory.Common
import System.Posix.ByteString.FilePath

-- | @createDirectory dir mode@ calls @mkdir@ to
--   create a new directory, @dir@, with permissions based on
--  @mode@.
createDirectory :: RawFilePath -> FileMode -> IO ()
createDirectory name mode =
  withFilePath name $ \s ->
    throwErrnoPathIfMinus1Retry_ "createDirectory" name (c_mkdir s mode)
    -- POSIX doesn't allow mkdir() to return EINTR, but it does on
    -- OS X (#5184), so we need the Retry variant here.

foreign import ccall unsafe "mkdir"
  c_mkdir :: CString -> CMode -> IO CInt

-- | @openDirStream dir@ calls @opendir@ to obtain a
--   directory stream for @dir@.
openDirStream :: RawFilePath -> IO DirStream
openDirStream name =
  withFilePath name $ \s -> do
    dirp <- throwErrnoPathIfNullRetry "openDirStream" name $ c_opendir s
    return (DirStream dirp)

foreign import capi unsafe "HsUnix.h opendir"
   c_opendir :: CString  -> IO (Ptr CDir)

-- | @readDirStream dp@ calls @readdir@ to obtain the
--   next directory entry (@struct dirent@) for the open directory
--   stream @dp@, and returns the @d_name@ member of that
--  structure.
readDirStream :: DirStream -> IO RawFilePath
readDirStream (DirStream dirp) =
  alloca $ \ptr_dEnt  -> loop ptr_dEnt
 where
  loop ptr_dEnt = do
    resetErrno
    r <- c_readdir dirp ptr_dEnt
    if (r == 0)
         then do dEnt <- peek ptr_dEnt
                 if (dEnt == nullPtr)
                    then return BC.empty
                    else do
                     entry <- (d_name dEnt >>= peekFilePath)
                     c_freeDirEnt dEnt
                     return entry
         else do errno <- getErrno
                 if (errno == eINTR) then loop ptr_dEnt else do
                 let (Errno eo) = errno
                 if (eo == 0)
                    then return BC.empty
                    else throwErrno "readDirStream"

-- traversing directories
foreign import ccall unsafe "__hscore_readdir"
  c_readdir  :: Ptr CDir -> Ptr (Ptr CDirent) -> IO CInt

foreign import ccall unsafe "__hscore_free_dirent"
  c_freeDirEnt  :: Ptr CDirent -> IO ()

foreign import ccall unsafe "__hscore_d_name"
  d_name :: Ptr CDirent -> IO CString


-- | @getWorkingDirectory@ calls @getcwd@ to obtain the name
--   of the current working directory.
getWorkingDirectory :: IO RawFilePath
getWorkingDirectory = go (4096)
{-# LINE 129 "System/Posix/Directory/ByteString.hsc" #-}
  where
    go bytes = do
        r <- allocaBytes bytes $ \buf -> do
            buf' <- c_getcwd buf (fromIntegral bytes)
            if buf' /= nullPtr
                then do s <- peekFilePath buf
                        return (Just s)
                else do errno <- getErrno
                        if errno == eRANGE
                            -- we use Nothing to indicate that we should
                            -- try again with a bigger buffer
                            then return Nothing
                            else throwErrno "getWorkingDirectory"
        maybe (go (2 * bytes)) return r

foreign import ccall unsafe "getcwd"
   c_getcwd   :: Ptr CChar -> CSize -> IO (Ptr CChar)

-- | @changeWorkingDirectory dir@ calls @chdir@ to change
--   the current working directory to @dir@.
changeWorkingDirectory :: RawFilePath -> IO ()
changeWorkingDirectory path =
  modifyIOError (`ioeSetFileName` (BC.unpack path)) $
    withFilePath path $ \s ->
       throwErrnoIfMinus1Retry_ "changeWorkingDirectory" (c_chdir s)

foreign import ccall unsafe "chdir"
   c_chdir :: CString -> IO CInt

removeDirectory :: RawFilePath -> IO ()
removeDirectory path =
  modifyIOError (`ioeSetFileName` BC.unpack path) $
    withFilePath path $ \s ->
       throwErrnoIfMinus1Retry_ "removeDirectory" (c_rmdir s)

foreign import ccall unsafe "rmdir"
   c_rmdir :: CString -> IO CInt
