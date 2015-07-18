#import <SpringBoard/SpringBoard.h>

#import "SBIconView.h"

@interface SBIcon (OS40)
- (NSString *)leafIdentifier;
- (void)updateLabel;
@end

static NSMutableDictionary *iconMappings;

#define kSettingsFilePath "/var/mobile/Library/Preferences/ch.rpetri.iconrenamer.plist"

static NSString *displayNameForIcon(SBIcon *icon)
{
	if ([icon respondsToSelector:@selector(displayNameForLocation:)])
		return [icon displayNameForLocation:0];
	else
		return [icon displayName];
}

__attribute__((visibility("hidden")))
@interface IconRenamer : NSObject <UIAlertViewDelegate, UITextFieldDelegate> {
@private
	SBIcon *_icon;
	SBIconView *_iconView;
	UIAlertView *_av;
	BOOL _hasTouch;
}
- (id)initWithIcon:(SBIcon *)icon iconView:(SBIconView *)iconView;
- (void)receiveTouch;
@end

static NSInteger originalName;

@implementation IconRenamer

static IconRenamer *currentRenamer;

+ (id)renamerWithIcon:(SBIcon *)icon iconView:(SBIconView *)iconView
{
	return [[[self alloc] initWithIcon:icon iconView:iconView] autorelease];
}

- (id)initWithIcon:(SBIcon *)icon iconView:(SBIconView *)iconView
{
	if ((self = [super init])) {
		currentRenamer = self;
		_icon = [icon retain];
		_iconView = [iconView retain];
	}
	return self;
}

- (void)receiveTouch
{
	if (!_hasTouch) {
		_hasTouch = YES;
		[self performSelector:@selector(show) withObject:nil afterDelay:0.25];
	} else {
		[NSObject cancelPreviousPerformRequestsWithTarget:self];
	}
}

- (void)show
{
	if (!_av) {
		_av = [[UIAlertView alloc] init];
		_av.delegate = self;
		originalName++;
		NSString *title = displayNameForIcon(_icon);
		originalName--;
		_av.title = [@"Rename " stringByAppendingString:title];
		UITextField *textField = [_av addTextFieldWithValue:displayNameForIcon(_icon) label:nil];
		textField.delegate = self;
		textField.returnKeyType = UIReturnKeyDone;
		textField.clearButtonMode = UITextFieldViewModeAlways;
		_av.cancelButtonIndex = [_av addButtonWithTitle:@"Cancel"];
		[_av addButtonWithTitle:@"Apply"];
		[_av show];
		[self retain];
	}
}

- (void)save
{
	NSString *identifier = [_icon leafIdentifier];
	NSString *newDisplayName = [[_av textFieldAtIndex:0] text];
	if (![displayNameForIcon(_icon) isEqualToString:newDisplayName]) {
		[iconMappings setObject:newDisplayName forKey:identifier];
		[iconMappings writeToFile:@kSettingsFilePath atomically:YES];
		if (_iconView) {
			if ([_iconView respondsToSelector:@selector(updateLabel)])
				[_iconView updateLabel];
			else
				[_iconView _updateLabel];
		} else {
			[_icon updateLabel];
		}
	}
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	textField.delegate = nil;
	[self save];
	_av.delegate = nil;
	[_av dismissWithClickedButtonIndex:0 animated:YES];
	[_av release];
	_av = nil;
	[self release];
	return NO;
}

- (void)alertView:(UIAlertView *)av clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex != _av.cancelButtonIndex)
		[self save];
	[[_av textFieldAtIndex:0] setDelegate:nil];
	_av.delegate = nil;
	[_av release];
	_av = nil;
	[self release];
}

- (void)dealloc
{
	if (currentRenamer == self)
		currentRenamer = nil;
	[_icon release];
	[_iconView release];
	[super dealloc];
}

@end

%hook SBApplicationIcon

- (NSString *)displayName
{
	if (originalName == 0) {
		NSString *title = [iconMappings objectForKey:[self leafIdentifier]];
		if (title)
			return title;
	}
	return %orig();
}

- (NSString *)displayNameForLocation:(NSInteger)location
{
	if (originalName == 0) {
		NSString *title = [iconMappings objectForKey:[self leafIdentifier]];
		if (title)
			return title;
	}
	return %orig();
}

static BOOL inTap;
static NSTimeInterval lastTapTime;
static SBApplicationIcon *lastTapIcon;

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	inTap = [(SBIconController *)[%c(SBIconController) sharedInstance] isEditing];
	%orig();
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	inTap = NO;
	%orig();
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (inTap) {
		if ([[iconMappings objectForKey:@"IRRequiresDoubleTap"] boolValue]) {
			UITouch *touch = [touches anyObject];
			NSTimeInterval currentTapTime = touch.timestamp;
			if ((currentTapTime - lastTapTime < 0.5) && (lastTapIcon == self))
				[[IconRenamer renamerWithIcon:self iconView:nil] show];
			[lastTapIcon autorelease];
			lastTapIcon = [self retain];
			lastTapTime = currentTapTime;
		} else {
			[currentRenamer ?: [IconRenamer renamerWithIcon:self iconView:nil] receiveTouch];
		}
	}
	%orig();
}

%end

static SBIconView *lastTapIconView;

%hook SBIconView

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	inTap = [(SBIconController *)[%c(SBIconController) sharedInstance] isEditing];
	%orig();
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	inTap = NO;
	%orig();
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (inTap) {
		SBIcon *icon = self.icon;
		if ([icon isKindOfClass:%c(SBApplicationIcon)]) {
			if ([[iconMappings objectForKey:@"IRRequiresDoubleTap"] boolValue]) {
				UITouch *touch = [touches anyObject];
				NSTimeInterval currentTapTime = touch.timestamp;
				if ((currentTapTime - lastTapTime < 0.5) && (lastTapIconView == self))
					[[IconRenamer renamerWithIcon:self.icon iconView:self] show];
				[lastTapIconView autorelease];
				lastTapIconView = [self retain];
				lastTapTime = currentTapTime;
			} else {
				[currentRenamer ?: [IconRenamer renamerWithIcon:self.icon iconView:self] receiveTouch];
			}
		}
	}
	%orig();
}

%end

static void LoadSettings()
{
	[iconMappings release];
	iconMappings = [[NSMutableDictionary alloc] initWithContentsOfFile:@kSettingsFilePath] ?: [[NSMutableDictionary alloc] init];
}

%ctor
{
	%init();
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (void *)LoadSettings, CFSTR("ch.rpetri.iconrenamer/settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	LoadSettings();
	[pool drain];
}
