{-# LANGUAGE Haskell2010, OverloadedStrings #-}
{-# LINE 1 "Network/Wai/Middleware/Jsonp.hs" #-}











































































































































{-# LANGUAGE RankNTypes, CPP #-}
---------------------------------------------------------
-- |
-- Module        : Network.Wai.Middleware.Jsonp
-- Copyright     : Michael Snoyman
-- License       : BSD3
--
-- Maintainer    : Michael Snoyman <michael@snoyman.com>
-- Stability     : Unstable
-- Portability   : portable
--
-- Automatic wrapping of JSON responses to convert into JSONP.
--
---------------------------------------------------------
module Network.Wai.Middleware.Jsonp (jsonp) where

import Network.Wai
import Network.Wai.Internal
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as B8
import Blaze.ByteString.Builder (copyByteString)
import Blaze.ByteString.Builder.Char8 (fromChar)
import Control.Monad (join)
import Data.Maybe (fromMaybe)
import qualified Data.ByteString as S
import Network.HTTP.Types (hAccept, hContentType)

-- | Wrap json responses in a jsonp callback.
--
-- Basically, if the user requested a \"text\/javascript\" and supplied a
-- \"callback\" GET parameter, ask the application for an
-- \"application/json\" response, then convert that into a JSONP response,
-- having a content type of \"text\/javascript\" and calling the specified
-- callback function.
jsonp :: Middleware
jsonp app env sendResponse = do
    let accept = fromMaybe B8.empty $ lookup hAccept $ requestHeaders env
    let callback :: Maybe B8.ByteString
        callback =
            if B8.pack "text/javascript" `B8.isInfixOf` accept
                then join $ lookup "callback" $ queryString env
                else Nothing
    let env' =
            case callback of
                Nothing -> env
                Just _ -> env
                        { requestHeaders = changeVal hAccept
                                           "application/json"
                                           $ requestHeaders env
                        }
    app env' $ \res ->
        case callback of
            Nothing -> sendResponse res
            Just c -> go c res
  where
    go c r@(ResponseBuilder s hs b) =
        sendResponse $ case checkJSON hs of
            Nothing -> r
            Just hs' -> responseBuilder s hs' $
                copyByteString c
                `mappend` fromChar '('
                `mappend` b
                `mappend` fromChar ')'
    go c r =
        case checkJSON hs of
            Just hs' -> addCallback c s hs' wb
            Nothing -> sendResponse r
      where
        (s, hs, wb) = responseToStream r

    checkJSON hs =
        case lookup hContentType hs of
            Just x
                | B8.pack "application/json" `S.isPrefixOf` x ->
                    Just $ fixHeaders hs
            _ -> Nothing
    fixHeaders = changeVal hContentType "text/javascript"

    addCallback cb s hs wb =
        wb $ \body -> sendResponse $ responseStream s hs $ \sendChunk flush -> do
            sendChunk $ copyByteString cb `mappend` fromChar '('
            _ <- body sendChunk flush
            sendChunk $ fromChar ')'

changeVal :: Eq a
          => a
          -> ByteString
          -> [(a, ByteString)]
          -> [(a, ByteString)]
changeVal key val old = (key, val)
                      : filter (\(k, _) -> k /= key) old
