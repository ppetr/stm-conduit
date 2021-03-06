{-# LANGUAGE Rank2Types, KindSignatures #-}
-- | Contains a simple source and sink linking together conduits in
--   different threads. For extended examples of usage and bottlenecks
--   see 'Data.Conduit.TMChan'.
--
--   TQueue is an amoritized FIFO queue behaves like TChan, with two
--   important differences:
--
--     * it's faster (but amortized thus the cost of individual operations
--     may vary a lot)
--
--     * it doesn't provide equivalent of the dupTChan and cloneTChan
--     operations
--
--
--   Here is short description of data structures:
--     
--     * TQueue   - unbounded infinite queue
--     * TBQueue  - bounded infinite queue
--     * TMQueue  - unbounded finite (closable) queue
--     * TBMQueue - bounded finite (closable) queue
--
-- Caveats
-- 
--   Infinite operations means that source doesn't know when stream is
--   ended so one need to use other methods of finishing stream like
--   sending an exception or finish conduit in downstream.
--

module Data.Conduit.TQueue
  ( -- * Connectors
    -- ** TQueue connectors 
    sourceTQueue
  , sinkTQueue
    -- ** TBQueue connectors
  , sourceTBQueue
  , sinkTBQueue
    -- ** TMQueue connectors
  , sourceTMQueue
  , sinkTMQueue
    -- ** TBMQueue connectors
  , sourceTBMQueue
  , sinkTBMQueue
  , module Control.Concurrent.STM.TQueue
  ) where

import Control.Concurrent.STM
import Control.Concurrent.STM.TQueue
import Control.Concurrent.STM.TBMQueue
import Control.Concurrent.STM.TMQueue
import Control.Monad.IO.Class
import Data.Conduit
import Data.Conduit.Internal



sourceTQueue :: MonadIO m => TQueue a -> Source m a
sourceTQueue q = ConduitM src
  where src = PipeM pull
        pull = do x <- liftSTM $ readTQueue q
                  return $ HaveOutput src close x
        close = return ()

sinkTQueue :: MonadIO m => TQueue a -> Sink a m ()
sinkTQueue q = ConduitM src
  where src        = sink
        sink       = NeedInput push close
        push input = PipeM ((liftSTM $ writeTQueue q input)
                            >> (return $ NeedInput push close))
        close _    = return ()

sourceTBQueue :: MonadIO m => TBQueue a -> Source m a
sourceTBQueue q = ConduitM src
  where src = PipeM pull
        pull = do x <- liftSTM $ readTBQueue q
                  return $ HaveOutput src close x
        close = return ()

sinkTBQueue :: MonadIO m => TBQueue a -> Sink a m ()
sinkTBQueue q = ConduitM src
  where src        = sink
        sink       = NeedInput push close
        push input = PipeM ((liftSTM $ writeTBQueue q input)
                            >> (return $ NeedInput push close))
        close _    = return ()

sourceTMQueue :: MonadIO m => TMQueue a -> Source m a
sourceTMQueue q = ConduitM src
  where src = PipeM pull
        pull = do mx <- liftSTM $ readTMQueue q
                  case mx of
                      Nothing -> return $ Done ()
                      Just x -> return $ HaveOutput src close x
        close = do liftSTM $ closeTMQueue q
                   return ()

sinkTMQueue :: MonadIO m => TMQueue a -> Sink a m ()
sinkTMQueue q = ConduitM src
  where src = sink
        sink =  NeedInput push close
        push input = PipeM ((liftSTM $ writeTMQueue q input)
                            >> (return $ NeedInput push close))
        close _ = do liftSTM $ closeTMQueue q
                     return ()

sourceTBMQueue :: MonadIO m => TBMQueue a -> Source m a
sourceTBMQueue q = ConduitM src
  where src = PipeM pull
        pull = do mx <- liftSTM $ readTBMQueue q
                  case mx of
                      Nothing -> return $ Done ()
                      Just x -> return $ HaveOutput src close x
        close = do liftSTM $ closeTBMQueue q
                   return ()

sinkTBMQueue :: MonadIO m => TBMQueue a -> Sink a m ()
sinkTBMQueue q = ConduitM src
  where src = sink
        sink =  NeedInput push close
        push input = PipeM ((liftSTM $ writeTBMQueue q input)
                            >> (return $ NeedInput push close))
        close _ = do liftSTM $ closeTBMQueue q
                     return ()


liftSTM :: forall (m :: * -> *) a. MonadIO m => STM a -> m a
liftSTM = liftIO . atomically
