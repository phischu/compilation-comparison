{-# LANGUAGE Haskell2010, OverloadedStrings #-}
{-# LINE 1 "Network/Wai/Middleware/StreamFile.hs" #-}
-- |
--
-- Since 3.0.4
module Network.Wai.Middleware.StreamFile
    (streamFile) where

import Network.Wai (responseStream)
import Network.Wai.Internal
import Network.Wai (Middleware, responseToStream)
import qualified Data.ByteString.Char8 as S8
import System.PosixCompat (getFileStatus, fileSize, FileOffset)
import Network.HTTP.Types (hContentLength)

-- |Convert ResponseFile type responses into ResponseStream type
--
-- Checks the response type, and if it's a ResponseFile, converts it
-- into a ResponseStream. Other response types are passed through
-- unchanged.
--
-- Converted responses get a Content-Length header.
--
-- Streaming a file will bypass a sendfile system call, and may be
-- useful to work around systems without working sendfile
-- implementations.
--
-- Since 3.0.4
streamFile :: Middleware
streamFile app env sendResponse = app env $ \res ->
    case res of
      ResponseFile _ _ fp _ -> withBody sendBody
          where
            (s, hs, withBody) = responseToStream res
            sendBody :: StreamingBody -> IO ResponseReceived
            sendBody body = do
               len <- getFileSize fp
               let hs' = (hContentLength, (S8.pack (show len))) : hs
               sendResponse $ responseStream s hs' body
      _ -> sendResponse res

getFileSize :: FilePath -> IO FileOffset
getFileSize path = do
    stat <- getFileStatus path
    return (fileSize stat)
