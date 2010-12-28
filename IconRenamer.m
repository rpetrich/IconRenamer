#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>

@interface SBIcon (OS40)
- (NSString *)leafIdentifier;
- (void)updateLabel;
@end

static NSMutableDictionary *iconMappings;

#define kSettingsFilePath "/var/mobile/Library/Preferences/ch.rpetri.iconrenamer.plist"

__attribute__((visibility("hidden")))
@interface IconRenamer : NSObject <UIAlertViewDelegate, UITextFieldDelegate> {
@private
	SBIcon *_icon;
	UIAlertView *_av;
}
@end

@implementation IconRenamer

+ (id)renamerWithIcon:(SBIcon *)icon
{
	return [[[self alloc] initWithIcon:icon] autorelease];
}

- (id)initWithIcon:(SBIcon *)icon
{
	if ((self = [super init])) {
		_icon = [icon retain];
	}
	return self;
}

- (void)show
{
	if (!_av) {
		_av = [[UIAlertView alloc] init];
		_av.delegate = self;
		_av.title = @"Rename Icon";
		UITextField *textField = [_av addTextFieldWithValue:[_icon displayName] label:nil];
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
	if (![[_icon displayName] isEqualToString:newDisplayName]) {
		[iconMappings setObject:newDisplayName forKey:identifier];
		[iconMappings writeToFile:@kSettingsFilePath atomically:YES];
		[_icon updateLabel];
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
	[_icon release];
	[super dealloc];
}

@end

CHDeclareClass(SBApplicationIcon);
CHDeclareClass(SBIconController);

CHOptimizedMethod(0, self, NSString *, SBApplicationIcon, displayName)
{
	return [iconMappings objectForKey:[self leafIdentifier]] ?: CHSuper(0, SBApplicationIcon, displayName);
}

static BOOL inTap;

CHOptimizedMethod(2, super, void, SBApplicationIcon, touchesBegan, NSSet *, touches, withEvent, UIEvent *, event)
{
	inTap = [CHSharedInstance(SBIconController) isEditing];
	CHSuper(2, SBApplicationIcon, touchesBegan, touches, withEvent, event);
}

CHOptimizedMethod(2, super, void, SBApplicationIcon, touchesMoved, NSSet *, touches, withEvent, UIEvent *, event)
{
	inTap = NO;
	CHSuper(2, SBApplicationIcon, touchesMoved, touches, withEvent, event);
}

CHOptimizedMethod(2, super, void, SBApplicationIcon, touchesEnded, NSSet *, touches, withEvent, UIEvent *, event)
{
	if (inTap)
		[[IconRenamer renamerWithIcon:self] show];
	CHSuper(2, SBApplicationIcon, touchesEnded, touches, withEvent, event);
}

CHConstructor {
	CHLoadLateClass(SBApplicationIcon);
	CHHook(0, SBApplicationIcon, displayName);
	CHHook(2, SBApplicationIcon, touchesBegan, withEvent);
	CHHook(2, SBApplicationIcon, touchesMoved, withEvent);
	CHHook(2, SBApplicationIcon, touchesEnded, withEvent);
	CHLoadLateClass(SBIconController);
	CHAutoreleasePoolForScope();
	iconMappings = [[NSMutableDictionary alloc] initWithContentsOfFile:@kSettingsFilePath] ?: [[NSMutableDictionary alloc] init];
}
