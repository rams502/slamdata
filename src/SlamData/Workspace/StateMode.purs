{-
Copyright 2016 SlamData, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-}

module SlamData.Workspace.StateMode where

import SlamData.Quasar.Error (QError)

-- | The current state of the deck.
-- |
-- | - `Loading` indicates loading from the server is in progress
-- | - `Preparing` indicates a deck has been restored but not yet run
-- | - `Ready` indicates there are no pending load/setup operations.
-- | - `Error` is used when there is a problem restoring the deck.
data StateMode
  = Loading
  | Preparing
  | Ready
  | Error QError

isPreparing ∷ StateMode → Boolean
isPreparing =
  case _ of
    Preparing → true
    _ → false
