// -----------------------------------------------------------------------------
// Copyright 2011-2013 Patrick Näf (herzbube@herzbube.ch)
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


// Project includes
#import "PlayViewController.h"
#import "PlayView.h"
#import "boardposition/BoardPositionListViewController.h"
#import "boardposition/BoardPositionModel.h"
#import "boardposition/BoardPositionTableListViewController.h"
#import "boardposition/BoardPositionToolbarController.h"
#import "boardposition/BoardPositionView.h"
#import "boardposition/BoardPositionViewMetrics.h"
#import "boardposition/CurrentBoardPositionViewController.h"
#import "controller/DebugPlayViewController.h"
#import "controller/StatusViewController.h"
#import "gesture/DoubleTapGestureController.h"
#import "gesture/TapGestureController.h"
#import "gesture/TwoFingerTapGestureController.h"
#import "scrollview/PlayViewScrollController.h"
#import "splitview/LeftPaneViewController.h"
#import "splitview/RightPaneViewController.h"
#import "../main/ApplicationDelegate.h"
#import "../go/GoBoardPosition.h"
#import "../go/GoGame.h"
#import "../command/CommandBase.h"
#import "../ui/UiElementMetrics.h"
#import "../ui/UiUtilities.h"

// System includes
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <math.h>

// Constants
NSString* associatedCommandObjectKey = @"AssociatedCommandObject";

// Enums
enum ActionType
{
  ActionTypePlay,
  ActionTypeDiscard
};


// -----------------------------------------------------------------------------
/// @brief Class extension with private properties for PlayViewController.
// -----------------------------------------------------------------------------
@interface PlayViewController()
@property(nonatomic, retain) UIScrollView* playViewScrollView;
@property(nonatomic, retain) PlayViewScrollController* playViewScrollController;
@property(nonatomic, retain) PlayView* playView;
@property(nonatomic, retain) UINavigationBar* navigationBarMain;
@property(nonatomic, retain) UIToolbar* toolbarBoardPositionNavigation;
@property(nonatomic, retain) ItemScrollView* boardPositionListView;
@property(nonatomic, retain) BoardPositionView* currentBoardPositionView;
@property(nonatomic, retain) UIView* boardPositionListContainerView;
@property(nonatomic, retain) BoardPositionViewMetrics* boardPositionViewMetrics;
@property(nonatomic, retain) UISplitViewController* splitViewController;
@property(nonatomic, retain) LeftPaneViewController* leftPaneViewController;
@property(nonatomic, retain) RightPaneViewController* rightPaneViewController;
@property(nonatomic, retain) NavigationBarController* navigationBarController;
@property(nonatomic, retain) StatusViewController* statusViewController;
@property(nonatomic, retain) BoardPositionToolbarController* boardPositionToolbarController;
@property(nonatomic, retain) BoardPositionListViewController* boardPositionListViewController;
@property(nonatomic, retain) CurrentBoardPositionViewController* currentBoardPositionViewController;
@property(nonatomic, retain) BoardPositionTableListViewController* boardPositionTableListViewController;
@property(nonatomic, retain) PanGestureController* panGestureController;
@property(nonatomic, retain) DoubleTapGestureController* doubleTapGestureController;
@property(nonatomic, retain) TapGestureController* tapGestureController;
@property(nonatomic, retain) TwoFingerTapGestureController* twoFingerTapGestureController;
@property(nonatomic, retain) DebugPlayViewController* debugPlayViewController;
@end


@implementation PlayViewController

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this PlayViewController object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self releaseObjects];
  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for dealloc and viewDidUnload
// -----------------------------------------------------------------------------
- (void) releaseObjects
{
  self.view = nil;
  self.playViewScrollView = nil;
  self.playViewScrollController = nil;
  self.playView = nil;
  self.navigationBarMain = nil;
  self.toolbarBoardPositionNavigation = nil;
  self.boardPositionListView = nil;
  self.currentBoardPositionView = nil;
  self.boardPositionListContainerView = nil;
  self.boardPositionViewMetrics = nil;
  self.splitViewController = nil;
  self.leftPaneViewController = nil;
  self.rightPaneViewController = nil;
  self.navigationBarController = nil;
  self.statusViewController = nil;
  self.boardPositionToolbarController = nil;
  self.boardPositionListViewController = nil;
  self.currentBoardPositionViewController = nil;
  self.boardPositionTableListViewController = nil;
  self.panGestureController = nil;
  self.doubleTapGestureController = nil;
  self.tapGestureController = nil;
  self.twoFingerTapGestureController = nil;
  self.debugPlayViewController = nil;
}

// -----------------------------------------------------------------------------
/// @brief Creates the view that this controller manages.
// -----------------------------------------------------------------------------
- (void) loadView
{
  // Note: If the user is holding the device in landscape orientation while the
  // application is starting up, iOS will first start up in portrait orientation
  // and then initiate an auto-rotation to landscape orientation. Because the
  // main view has an autoresizing mask, it will have the correct size at the
  // time viewDidLoad() is invoked.
  [self setupMainView];

  // Prerequisite for setupSplitViewController()
  [self setupNavigationBarController];

  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
  {
    self.splitViewController = nil;
    self.leftPaneViewController = nil;
    self.rightPaneViewController = nil;
  }
  else
  {
    // Cannot delay creation of UISplitViewControlller until viewDidLoad() is
    // invoked, otherwise swipe gestures are initially not recognized when the
    // app is launched in portrait mode. UISplitViewControlller starts to
    // recgonize swipe gesture if the device is rotated to landscape and back
    // to portrait, but not before. The reason for this behaviour of
    // UISplitViewControlller is unknown, but the only way I have found to fix
    // the problem is to not delay creation of the controller.
    // TODO: Check if this comment is still relevant. In an earlier
    // implementation, the comment did not talk about viewDidLoad, but about
    // makeControllerReadyForAction() which was invoked with a delay.
    [self setupSplitViewController];
    [self setupSplitView];
  }

  // Setup of remaining views is delayed to viewDidLoad()
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked by loadView().
// -----------------------------------------------------------------------------
- (void) setupMainView
{
  CGRect mainViewFrame = [self mainViewFrame];
  self.view = [[[UIView alloc] initWithFrame:mainViewFrame] autorelease];
  self.view.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:woodenBackgroundImageResource]];
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked by setupMainView().
// -----------------------------------------------------------------------------
- (CGRect) mainViewFrame
{
  int mainViewX = 0;
  int mainViewY = 0;
  int mainViewWidth = [UiElementMetrics screenWidth];
  int mainViewHeight = ([UiElementMetrics screenHeight]
                        - [UiElementMetrics tabBarHeight]
                        - [UiElementMetrics statusBarHeight]);
  return CGRectMake(mainViewX, mainViewY, mainViewWidth, mainViewHeight);
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (void) setupSplitView
{
  UIView* superView = [self splitViewSuperview];
  CGRect splitViewControllerViewFrame = [self splitViewFrame];
  self.splitViewController.view.frame = splitViewControllerViewFrame;
  [superView addSubview:self.splitViewController.view];

  // Set left/right panes to use the same height as the split view
  CGRect leftPaneViewFrame = self.leftPaneViewController.view.frame;
  leftPaneViewFrame.size.height = splitViewControllerViewFrame.size.height;
  self.leftPaneViewController.view.frame = leftPaneViewFrame;
  CGRect rightPaneViewFrame = self.rightPaneViewController.view.frame;
  rightPaneViewFrame.size.height = splitViewControllerViewFrame.size.height;
  self.rightPaneViewController.view.frame = rightPaneViewFrame;

  self.rightPaneViewController.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:woodenBackgroundImageResource]];
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked by setupMainView().
// -----------------------------------------------------------------------------
- (CGRect) splitViewFrame
{
  UIView* superView = [self splitViewSuperview];
  return superView.bounds;
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (UIView*) splitViewSuperview
{
  return self.view;
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (void) setupNavigationBarMain
{
  CGRect viewFrame = [self navigationBarMainFrame];
  self.navigationBarMain = [[[UINavigationBar alloc] initWithFrame:viewFrame] autorelease];
  UIView* superView = [self navigationBarMainSuperview];
  [superView addSubview:self.navigationBarMain];

  self.navigationBarMain.autoresizingMask = UIViewAutoresizingFlexibleWidth;
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (CGRect) navigationBarMainFrame
{
  UIView* superView = [self navigationBarMainSuperview];
  int viewX = 0;
  int viewY = 0;
  int viewWidth = superView.bounds.size.width;
  int viewHeight = [UiElementMetrics navigationBarHeight];
  return CGRectMake(viewX, viewY, viewWidth, viewHeight);
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (UIView*) navigationBarMainSuperview
{
  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    return self.view;
  else
    return self.rightPaneViewController.view;
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (void) setupToolbarBoardPositionNavigation
{
  CGRect toolbarFrame = [self toolbarBoardPositionNavigationFrame];
  self.toolbarBoardPositionNavigation = [[[UIToolbar alloc] initWithFrame:toolbarFrame] autorelease];
  UIView* superView = [self toolbarBoardPositionNavigationSuperview];
  [superView addSubview:self.toolbarBoardPositionNavigation];
  
  self.toolbarBoardPositionNavigation.autoresizingMask = UIViewAutoresizingFlexibleWidth;
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (CGRect) toolbarBoardPositionNavigationFrame
{
  UIView* superView = [self toolbarBoardPositionNavigationSuperview];
  int toolbarViewX = 0;
  int toolbarViewWidth = superView.bounds.size.width;
  int toolbarViewHeight = [UiElementMetrics toolbarHeight];
  int toolbarViewY;
  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    toolbarViewY = superView.bounds.size.height - toolbarViewHeight;
  else
    toolbarViewY = 0;
  return CGRectMake(toolbarViewX, toolbarViewY, toolbarViewWidth, toolbarViewHeight);
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (UIView*) toolbarBoardPositionNavigationSuperview
{
  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    return self.view;
  else
    return self.leftPaneViewController.view;
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (void) setupPlayViewScrollView
{
  CGRect scrollViewFrame = [self playViewScrollViewFrame];
  self.playViewScrollView = [[[UIScrollView alloc] initWithFrame:scrollViewFrame] autorelease];
  UIView* superView = [self playViewScrollViewSuperview];
  [superView addSubview:self.playViewScrollView];

  self.playViewScrollView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
  self.playViewScrollView.backgroundColor = [UIColor clearColor];
  self.playViewScrollView.bouncesZoom = NO;
  self.playViewScrollView.contentSize = scrollViewFrame.size;
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (CGRect) playViewScrollViewFrame
{
  UIView* superView = [self playViewScrollViewSuperview];
  CGSize superViewSize = superView.bounds.size;
  int viewX = 0;
  int viewY = CGRectGetMaxY(self.navigationBarMain.frame);
  int viewWidth = superViewSize.width;
  int viewHeight;
  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
  {
    viewHeight = (superViewSize.height
                      - self.navigationBarMain.frame.size.height
                      - self.toolbarBoardPositionNavigation.frame.size.height);
  }
  else
  {
    viewHeight = (superViewSize.height
                      - self.navigationBarMain.frame.size.height);
  }
  return CGRectMake(viewX, viewY, viewWidth, viewHeight);
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (UIView*) playViewScrollViewSuperview
{
  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    return self.view;
  else
    return self.rightPaneViewController.view;
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (void) setupCoordinateLabelScrollViews
{
  UIView* superView = [self coordinateLabelScrollViewsSuperview];
  NSArray* scrollViews = [NSArray arrayWithObjects:
                          self.playView.coordinateLabelsLetterViewScrollView,
                          self.playView.coordinateLabelsNumberViewScrollView,
                          nil];
  for (UIView* scrollView in scrollViews)
  {
    CGRect scrollViewFrame = scrollView.frame;
    scrollViewFrame.origin = self.playViewScrollView.frame.origin;
    scrollView.frame = scrollViewFrame;
    [superView addSubview:scrollView];
  }
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (UIView*) coordinateLabelScrollViewsSuperview
{
  return [self playViewScrollViewSuperview];
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (void) setupPlayView
{
  CGRect playViewFrame = [self playViewFrame];
  self.playView = [[[PlayView alloc] initWithFrame:playViewFrame] autorelease];
  UIView* superView = [self playViewSuperview];
  [superView addSubview:self.playView];

  self.playView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
  self.playView.backgroundColor = [UIColor clearColor];
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (CGRect) playViewFrame
{
  CGSize contentSize = self.playViewScrollView.contentSize;
  return CGRectMake(0, 0, contentSize.width, contentSize.height);
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (UIView*) playViewSuperview
{
  return self.playViewScrollView;
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (void) setupBoardPositionListView
{
  self.boardPositionListView = [[[ItemScrollView alloc] initWithFrame:[self boardPositionListViewFrame]
                                                          orientation:ItemScrollViewOrientationHorizontal] autorelease];
  self.boardPositionListView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  self.boardPositionListView.backgroundColor = [UIColor clearColor];
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (CGRect) boardPositionListViewFrame
{
  int listViewX = 0;
  int listViewY = 0;
  int listViewWidth = (self.toolbarBoardPositionNavigation.frame.size.width
                       - (2 * [UiElementMetrics toolbarPaddingHorizontal])
                       - self.boardPositionViewMetrics.boardPositionViewWidth
                       - (2 * [UiElementMetrics toolbarSpacing]));
  int listViewHeight = self.boardPositionViewMetrics.boardPositionViewHeight;
  return CGRectMake(listViewX, listViewY, listViewWidth, listViewHeight);
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (void) setupCurrentBoardPositionView
{
  self.currentBoardPositionView = [[[BoardPositionView alloc] initWithBoardPosition:-1
                                                                        viewMetrics:self.boardPositionViewMetrics] autorelease];
  self.currentBoardPositionView.frame = [self currentBoardPositionViewFrame];
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (CGRect) currentBoardPositionViewFrame
{
  int boardPositionViewX = 0;
  int boardPositionViewY = 0;
  int boardPositionViewWidth = self.boardPositionViewMetrics.boardPositionViewWidth;
  int boardPositionViewHeight = self.boardPositionViewMetrics.boardPositionViewHeight;
  return CGRectMake(boardPositionViewX, boardPositionViewY, boardPositionViewWidth, boardPositionViewHeight);
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (void) setupBoardPositionListContainerView
{
  CGRect boardPositionListContainerViewFrame = [self boardPositionListContainerViewFrame];
  self.boardPositionListContainerView = [[[UIView alloc] initWithFrame:boardPositionListContainerViewFrame] autorelease];
  UIView* superView = [self boardPositionListContainerViewSuperview];
  [superView addSubview:self.boardPositionListContainerView];

  self.boardPositionListContainerView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (CGRect) boardPositionListContainerViewFrame
{
  UIView* superView = [self boardPositionListContainerViewSuperview];
  int listViewX = 0;
  int listViewY = CGRectGetMaxY(self.toolbarBoardPositionNavigation.frame);
  int listViewWidth = [UiElementMetrics splitViewLeftPaneWidth];
  int listViewHeight = (superView.frame.size.height - listViewY);
  return CGRectMake(listViewX, listViewY, listViewWidth, listViewHeight);
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (UIView*) boardPositionListContainerViewSuperview
{
  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    return nil;
  else
    return self.leftPaneViewController.view;
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked when the view hierarchy is
/// created.
// -----------------------------------------------------------------------------
- (void) setupDebugView
{
  self.debugPlayViewController = [[[DebugPlayViewController alloc] init] autorelease];
  [self.view addSubview:self.debugPlayViewController.view];
  CGRect debugPlayViewFrame = self.debugPlayViewController.view.frame;
  debugPlayViewFrame.origin.y += self.navigationBarMain.frame.size.height;
  self.debugPlayViewController.view.frame = debugPlayViewFrame;
}

// -----------------------------------------------------------------------------
/// @brief Called after the controller’s view is loaded into memory, usually
/// to perform additional initialization steps.
// -----------------------------------------------------------------------------
- (void) viewDidLoad
{
  [super viewDidLoad];
  [self setupSubviews];
  [self setupSubcontrollers];
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked by viewDidLoad().
// -----------------------------------------------------------------------------
- (void) setupSubviews
{
  self.boardPositionViewMetrics = [[[BoardPositionViewMetrics alloc] init] autorelease];
  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
  {
    [self setupNavigationBarMain];
    [self setupToolbarBoardPositionNavigation];
    [self setupPlayViewScrollView];
    [self setupPlayView];
    [self setupCoordinateLabelScrollViews];
    [self setupBoardPositionListView];
    [self setupCurrentBoardPositionView];
    self.boardPositionListContainerView = nil;
  }
  else
  {
    [self setupNavigationBarMain];
    [self setupToolbarBoardPositionNavigation];
    [self setupPlayViewScrollView];
    [self setupPlayView];
    [self setupCoordinateLabelScrollViews];
    [self setupBoardPositionListContainerView];
    self.boardPositionListView = nil;
    self.currentBoardPositionView = nil;
  }
  // Activate the following code to display controls that you can use to change
  // Play view drawing parameters that are normally immutable at runtime. This
  // is nice for debugging changes to the drawing system.
  //  [self setupDebugView];
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked by viewDidLoad().
// -----------------------------------------------------------------------------
- (void) setupSubcontrollers
{
  ScoringModel* scoringModel = [ApplicationDelegate sharedDelegate].scoringModel;

  self.statusViewController = [[[StatusViewController alloc] initWithPlayView:self.playView
                                                                 scoringModel:scoringModel] autorelease];
  [self.navigationBarController setupWithScoringModel:scoringModel
                                        navigationBar:self.navigationBarMain
                                           statusViewController:self.statusViewController];
  self.playViewScrollController = [[[PlayViewScrollController alloc] initWithScrollView:self.playViewScrollView playView:self.playView] autorelease];
  self.doubleTapGestureController = [[[DoubleTapGestureController alloc] initWithScrollView:self.playViewScrollView] autorelease];
  self.twoFingerTapGestureController = [[[TwoFingerTapGestureController alloc] initWithScrollView:self.playViewScrollView] autorelease];

  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
  {
    self.boardPositionToolbarController = [[[BoardPositionToolbarController alloc] initWithToolbar:self.toolbarBoardPositionNavigation
                                                                             boardPositionListView:self.boardPositionListView
                                                                          currentBoardPositionView:self.currentBoardPositionView] autorelease];
  }
  else
  {
    self.boardPositionToolbarController = [[[BoardPositionToolbarController alloc] initWithToolbar:self.toolbarBoardPositionNavigation] autorelease];
  }

  self.boardPositionListViewController = [[[BoardPositionListViewController alloc] initWithBoardPositionListView:self.boardPositionListView
                                                                                                     viewMetrics:self.boardPositionViewMetrics] autorelease];
  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
  {
    self.currentBoardPositionViewController = [[[CurrentBoardPositionViewController alloc] initWithCurrentBoardPositionView:self.currentBoardPositionView] autorelease];
    self.currentBoardPositionViewController.delegate = self;
    self.boardPositionTableListViewController = nil;
  }
  else
  {
    self.boardPositionTableListViewController = [[[BoardPositionTableListViewController alloc] initWithContainerView:self.boardPositionListContainerView] autorelease];
    self.currentBoardPositionViewController = nil;
  }
  self.panGestureController = [[[PanGestureController alloc] initWithPlayView:self.playView
                                                                 scoringModel:scoringModel
                                                                     delegate:self
                                                         parentViewController:self] autorelease];
  self.tapGestureController = [[[TapGestureController alloc] initWithPlayView:self.playView scoringModel:scoringModel] autorelease];
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked at the appropriate time to setup
/// the controller that manages the main navigation bar.
// -----------------------------------------------------------------------------
- (void) setupNavigationBarController
{
  self.navigationBarController = [[[NavigationBarController alloc] initWithDelegate:self
                                                               parentViewController:self] autorelease];
}

// -----------------------------------------------------------------------------
/// @brief This is an internal helper invoked at the appropriate time to setup
/// the split view controller used by the iPad layout.
// -----------------------------------------------------------------------------
- (void) setupSplitViewController
{
  self.splitViewController = [[[UISplitViewController alloc] initWithNibName:nil bundle:nil] autorelease];
  self.leftPaneViewController = [[[LeftPaneViewController alloc] initWithNibName:nil bundle:nil] autorelease];
  self.rightPaneViewController = [[[RightPaneViewController alloc] initWithNibName:nil bundle:nil] autorelease];
  // Assign view controllers before first use of self.splitViewController.view
  // (if we do it the other way round, a message is printed in the debug area in
  // Xcode that warns us about the mistake; we should heed this warning,
  // although no bad things [tm] could actually be observed)
  self.splitViewController.viewControllers = [NSArray arrayWithObjects:self.leftPaneViewController, self.rightPaneViewController, nil];
  // The following statement is essential so that the split view controller
  // properly receives rotation events in iOS 5. In iOS6 rotation seems to work
  // even if the statement is missing. Behaviour of iOS 5 was tested in
  // simulator only.
  [self addChildViewController:self.splitViewController];
  // Must assign a delegate, otherwise UISplitViewController will not react to
  // swipe gestures (tested in 5.1 and 6.0 simulator; 5.0 does not support the
  // swipe anyway). Reported to Apple with problem ID 13133575.
  self.splitViewController.delegate = self.navigationBarController;
}

// -----------------------------------------------------------------------------
/// @brief Exists for compatibility with iOS 5. Is not invoked in iOS 6 and can
/// be removed if deployment target is set to iOS 6.
// -----------------------------------------------------------------------------
- (void) viewDidUnload
{
  [super viewDidUnload];

  // Here we need to undo all of the stuff that is happening in
  // viewDidLoad(). Notes:
  // - If the game info view is currently visible, it will not be visible
  //   anymore when viewDidLoad() is invoked the next time
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self releaseObjects];
}

// -----------------------------------------------------------------------------
/// @brief UIViewController method.
// -----------------------------------------------------------------------------
- (void) didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // In iOS 5, the system purges the view and self.isViewLoaded becomes false
  // before didReceiveMemoryWarning() is invoked. In iOS 6 the system does not
  // purge the view and self.isViewLoaded is still true when we get here. The
  // view's window property then becomes important: It is nil if the main tab
  // bar controller displays a different tab than the one where the view is
  // visible.
  if (self.isViewLoaded && ! self.view.window)
  {
    // Do not release anything in iOS 6 and later (as opposed to iOS 5 where we
    // are forced to release stuff in viewDidUnload). A run through Instruments
    // shows that releasing objects here frees between 100-300 KB. Since the
    // user is expected to switch back to the Play tab anyway, this gain is
    // only temporary.
  }
}

// -----------------------------------------------------------------------------
/// @brief Exists for compatibility with iOS 5. Is not invoked in iOS 6 and can
/// be removed if deployment target is set to iOS 6.
// -----------------------------------------------------------------------------
- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return [UiUtilities shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}

// -----------------------------------------------------------------------------
/// @brief NavigationBarControllerDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) navigationBarController:(NavigationBarController*)controller playOrAlertWithCommand:(CommandBase*)command
{
  [self alertOrAction:ActionTypePlay withCommand:command];
}

// -----------------------------------------------------------------------------
/// @brief NavigationBarControllerDelegateDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) navigationBarController:(NavigationBarController*)controller discardOrAlertWithCommand:(CommandBase*)command
{
  [self alertOrAction:ActionTypeDiscard withCommand:command];
}

// -----------------------------------------------------------------------------
/// @brief NavigationBarControllerDelegateDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) navigationBarController:(NavigationBarController*)controller makeVisible:(bool)makeVisible gameInfoViewController:(UIViewController*)gameInfoViewController
{
  if (makeVisible)
    [self.navigationController pushViewController:gameInfoViewController animated:YES];
  else
    [self.navigationController popViewControllerAnimated:YES];
}

// -----------------------------------------------------------------------------
/// @brief PanGestureControllerDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) panGestureController:(PanGestureController*)controller playOrAlertWithCommand:(CommandBase*)command
{
  [self alertOrAction:ActionTypePlay withCommand:command];
}

// -----------------------------------------------------------------------------
/// @brief CurrentBoardPositionViewControllerDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) didTapCurrentBoardPositionViewController:(CurrentBoardPositionViewController*)controller
{
  [self.boardPositionToolbarController toggleToolbarItems];
}

// -----------------------------------------------------------------------------
/// @brief UIAlertViewDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) alertView:(UIAlertView*)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
  CommandBase* command = objc_getAssociatedObject(alertView, associatedCommandObjectKey);
  // objc_setAssociatedObject() will invoke release, so we must make sure that
  // the command survives until it is submitted
  [[command retain] autorelease];
  objc_setAssociatedObject(alertView, associatedCommandObjectKey, nil, OBJC_ASSOCIATION_RETAIN);
  switch (buttonIndex)
  {
    case AlertViewButtonTypeYes:
    {
      [command submit];
      break;
    }
    default:
    {
      break;
    }
  }
}

// -----------------------------------------------------------------------------
/// @brief Executes @a command, or displays an alert and delays execution until
/// the alert is dismissed by the user.
///
/// @a actionType is used to tweak the alert message so that contains a useful
/// description of what the user tries to do.
///
/// If the Play view currently displays the last board position of the game,
/// @a command is executed immediately.
///
/// If the Play view displays a board position in the middle of the game, an
/// alert is shown that warns the user that discarding now will discard all
/// future board positions. If the user confirms that this is OK, @a command is
/// executed. If the user cancels the operation, @a command is not executed.
/// Handling of the user's response happens in
/// alertView:didDismissWithButtonIndex:().
///
/// The user can suppress the alert in the user preferences. In this case
/// @a command is immediately executed.
// -----------------------------------------------------------------------------
- (void) alertOrAction:(enum ActionType)actionType withCommand:(CommandBase*)command
{
  GoBoardPosition* boardPosition = [GoGame sharedGame].boardPosition;
  BoardPositionModel* boardPositionModel = [ApplicationDelegate sharedDelegate].boardPositionModel;
  if (boardPosition.isLastPosition || ! boardPositionModel.discardFutureMovesAlert)
  {
    [command submit];
  }
  else
  {
    NSString* actionDescription;
    if (ActionTypePlay == actionType)
    {
      if (GoGameTypeComputerVsComputer == [GoGame sharedGame].type)
        actionDescription = @"If you let the computer play now,";
      else
      {
        // Use a generic expression because we don't know which user interaction
        // triggered the alert (could be a pass move, a play move (via panning),
        // or the "computer play" function).
        actionDescription = @"If you play now,";
      }
    }
    else
    {
      if (boardPosition.isFirstPosition)
        actionDescription = @"If you proceed,";
      else
        actionDescription = @"If you proceed not only this move, but";
    }
    NSString* formatString;
    if (boardPosition.isFirstPosition)
      formatString = @"You are looking at the board position at the beginning of the game. %@ all moves of the entire game will be discarded.\n\nDo you want to continue?";
    else
      formatString = @"You are looking at a board position in the middle of the game. %@ all moves that have been made after this position will be discarded.\n\nDo you want to continue?";
    NSString* messageString = [NSString stringWithFormat:formatString, actionDescription];
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Future moves will be discarded"
                                                    message:messageString
                                                   delegate:self
                                          cancelButtonTitle:@"No"
                                          otherButtonTitles:@"Yes", nil];
    alert.tag = AlertViewTypeActionWillDiscardAllFutureMoves;
    [alert show];
    [alert release];
    // Store command object for later use by the alert handler
    objc_setAssociatedObject(alert, associatedCommandObjectKey, command, OBJC_ASSOCIATION_RETAIN);
  }
}

@end
