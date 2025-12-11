#!/usr/bin/env cabal
{- cabal:
build-depends: base, async, unliftio
-}

{-# LANGUAGE NumericUnderscores #-}

import Control.Concurrent
import Control.Concurrent.Async (linkOnly)
import Control.Monad
import UnliftIO

main :: IO ()
main = do
    a <- forkIO $ do
        b <- forkIO $ do
            forever (sleep 1 >> putStrLn "1")
        error "failed"
    sleep 5

demo1 :: IO ()
demo1 = do
    let a = forever (sleep 1 >> putStrLn "1") `finally` putStrLn "Exit 1"
    let b = sleep 3 `finally` putStrLn "Exit 2"
    race_ a b
    putStrLn "Exit main"

sleep :: Int -> IO ()
sleep n = threadDelay (1_000_000 * n)
