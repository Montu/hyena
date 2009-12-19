{-# LANGUAGE Rank2Types, ImpredicativeTypes #-}

------------------------------------------------------------------------
-- |
-- Module      :  Network.Wai
-- Copyright   :  (c) Johan Tibell 2008
-- License     :  BSD3-style (see LICENSE)
--
-- Maintainer  :  johan.tibell@gmail.com
-- Stability   :  experimental
-- Portability :  not portable, uses 2-rank types
--
-- Defines the interface implemented by all web applications.
--
-- Example application:
--
-- > {-# LANGUAGE Rank2Types, ImpredicativeTypes #-}
-- > module Main where
--
-- > import qualified Data.ByteString as S
-- > import qualified Data.ByteString.Char8 as C (pack, unpack)
-- > import Hyena.Server
-- > import Network.Wai (Application, Enumerator, pathInfo)
-- > import System.Directory (getCurrentDirectory)
-- > import System.FilePath ((</>), makeRelative)
-- > import System.IO
--
-- > sendFile :: FilePath -> IO Enumerator
-- > sendFile path = do
-- >   h <- openBinaryFile path ReadMode
-- >   let yieldBlock f z = do
-- >              block <- S.hGetNonBlocking h 1024
-- >              if S.null block then hClose h >> return z
-- >                else do
-- >                  z' <- f z block
-- >                  case z' of
-- >                    Left z''  -> hClose h >> return z''
-- >                    Right z'' -> yieldBlock f z''
-- >   return yieldBlock
--
-- > fileServer :: Application
-- > fileServer environ = do
-- >   cwd <- getCurrentDirectory
-- >   let path = (cwd </> makeRelative "/" (C.unpack $ pathInfo environ))
-- >   size <- getFileSize path
-- >   -- Here you should add security checks, etc.
-- >   let contentType = (C.pack "Content-Type",
-- >                      C.pack "text/plain")
-- >       contentLength = (C.pack "Content-Length",
-- >                        C.pack (show size))
-- >   enumerator <- sendFile path
-- >   return (200, C.pack "OK", [contentType,contentLength], enumerator)
--
-- > getFileSize :: String -> IO Integer
-- > getFileSize fn = withFile fn ReadMode hFileSize
--
-- > main :: IO ()
-- > main = serve fileServer
--
------------------------------------------------------------------------

module Network.Wai
    ( -- * The Application type
      Application,
      Enumerator,
      Environment(..),
      Headers,
      Method(..)
    ) where

import qualified Data.ByteString as S

-- | The HTTP request headers.
type Headers = [(S.ByteString, S.ByteString)]

-- | The HTTP request method.
data Method = Options | Get | Head | Post | Put | Delete | Trace | Connect
              deriving (Eq, Show)

-- | An environment providing information regarding the request.
data Environment = Environment
    { requestMethod   :: Method
    -- ^ The HTTP request method, such as \"GET\" or \"POST\".
    , scriptName      :: S.ByteString
    -- ^ The initial portion of the request URL's \"path\" that
    -- corresponds to the application, so that the application knows
    -- its virtual \"location\".  This may be an empty string, if the
    -- application corresponds to the \"root\" of the server.
    , pathInfo        :: S.ByteString
    -- ^ The remainder of the request URL's \"path\", designating the
    -- virtual \"location\" of the request's target within the
    -- application.  This may be an empty string, if the request URL
    -- targets the application root and does not have a trailing
    -- slash.
    , queryString     :: Maybe (S.ByteString)
    -- ^ The portion of the request URL that follows the @\"?\"@, if
    -- any.  May be empty or absent.
    , requestProtocol :: (Int, Int)
    -- ^ The version of the protocol the client used to send the
    -- request.  Typically this will be @(1, 0)@ or @(1, 1)@ and may
    -- be used by the application to determine how to treat any HTTP
    -- request headers.
    , headers         :: Headers
    -- ^ The client-supplied HTTP request headers.
    , input           :: Enumerator
    -- ^ An 'Enumerator' from which the HTTP body can be read.
    , errors          :: String -> IO ()
    -- ^ A function with which error output can be written, for the
    -- purpose of recording program or other errors in a standardized
    -- and possibly centralized location.  This function will not add
    -- a trailing newline to the string.
    }

-- | A left-fold enumerator.
type Enumerator = forall a. (a -> S.ByteString -> IO (Either a a)) -> a -> IO a

-- | An application takes an environment and returns a HTTP status
-- code, a sequence of headers and an 'Enumerator' containing the
-- response body.
type Application = Environment -> IO (Int, S.ByteString, Headers, Enumerator)

