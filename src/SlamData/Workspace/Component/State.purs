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

module SlamData.Workspace.Component.State
  ( State
  , initialState
  , _deckId
  , _stateMode
  , _cardGuideStep
  , _flipGuideStep
  , cardGuideStepNext
  , flipGuideStepNext
  ) where

import SlamData.Prelude

import Data.Lens (Lens', lens)

import SlamData.Workspace.Deck.DeckId (DeckId)
import SlamData.Workspace.StateMode (StateMode(..))

type State =
  { deckId ∷ Maybe DeckId
  , stateMode ∷ StateMode
  , cardGuideStep ∷ Maybe Int
  , flipGuideStep ∷ Maybe Int
  }

initialState ∷ State
initialState =
  { deckId: Nothing
  , stateMode: Loading
  , cardGuideStep: Nothing
  , flipGuideStep: Nothing
  }

_deckId ∷ ∀ a r. Lens' { deckId ∷ a | r } a
_deckId = lens _.deckId _ { deckId = _ }

_stateMode ∷ Lens' State StateMode
_stateMode = lens _.stateMode _ { stateMode = _ }

_cardGuideStep ∷ Lens' State (Maybe Int)
_cardGuideStep = lens _.cardGuideStep _ { cardGuideStep = _ }

_flipGuideStep ∷ Lens' State (Maybe Int)
_flipGuideStep = lens _.flipGuideStep _ { flipGuideStep = _ }

cardGuideStepNext ∷ State → State
cardGuideStepNext st = st { cardGuideStep = add 1 <$> st.cardGuideStep }

flipGuideStepNext ∷ State → State
flipGuideStepNext st = st { flipGuideStep = add 1 <$> st.flipGuideStep }
