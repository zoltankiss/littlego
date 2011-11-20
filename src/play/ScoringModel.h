// -----------------------------------------------------------------------------
// Copyright 2011 Patrick Näf (herzbube@herzbube.ch)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// -----------------------------------------------------------------------------


// Forward declarations
@class GoScore;


// -----------------------------------------------------------------------------
/// @brief The ScoringModel class provides user defaults data to its clients
/// that is related to scoring.
// -----------------------------------------------------------------------------
@interface ScoringModel : NSObject
{
}

- (id) init;
- (void) readUserDefaults;
- (void) writeUserDefaults;

// -----------------------------------------------------------------------------
/// @name User defaults properties
// -----------------------------------------------------------------------------
//@{
@property bool askGtpEngineForDeadStones;
@property bool markDeadStonesIntelligently;
@property float alphaTerritoryColorBlack;
@property float alphaTerritoryColorWhite;
@property float alphaTerritoryColorInconsistencyFound;
@property(retain) UIColor* deadStoneSymbolColor;
@property float deadStoneSymbolPercentage;
//@}

// -----------------------------------------------------------------------------
/// @name Scoring properties
// -----------------------------------------------------------------------------
//@{
/// @brief Is true if scoring mode is enabled on the Play view.
@property(nonatomic) bool scoringMode;
/// @brief The GoScore object that provides scoring data while scoring mode is
/// enabled. Is nil while scoring mode is disabled.
@property(retain) GoScore* score;
//@}

@end