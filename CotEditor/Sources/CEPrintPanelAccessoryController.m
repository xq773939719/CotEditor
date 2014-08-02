/*
 =================================================
 CEPrintAccessoryViewController
 (for CotEditor)
 
 Copyright (C) 2014 CotEditor Project
 http://coteditor.github.io
 =================================================
 
 encoding="UTF-8"
 Created:2014-03-24 by 1024jp
 
 -------------------------------------------------
 
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 
 
 =================================================
 */

#import "CEPrintPanelAccessoryController.h"
#import "CEThemeManager.h"


@interface CEPrintPanelAccessoryController ()

@property (nonatomic) IBOutlet NSPopUpButton *themePopup;


@property (readwrite, nonatomic) NSString *theme;
@property (readwrite, nonatomic) CELineNumberPrintMode lineNumberMode;
@property (readwrite, nonatomic) CEInvisibleCharsPrintMode invisibleCharsMode;

@property (readwrite, nonatomic) BOOL printsHeader;
@property (readwrite, nonatomic) CEPrintInfoType headerOneInfoType;
@property (readwrite, nonatomic) CEAlignmentType headerOneAlignmentType;
@property (readwrite, nonatomic) CEPrintInfoType headerTwoInfoType;
@property (readwrite, nonatomic) CEAlignmentType headerTwoAlignmentType;
@property (readwrite, nonatomic) BOOL printsHeaderSeparator;

@property (readwrite, nonatomic) BOOL printsFooter;
@property (readwrite, nonatomic) CEPrintInfoType footerOneInfoType;
@property (readwrite, nonatomic) CEAlignmentType footerOneAlignmentType;
@property (readwrite, nonatomic) CEPrintInfoType footerTwoInfoType;
@property (readwrite, nonatomic) CEAlignmentType footerTwoAlignmentType;
@property (readwrite, nonatomic) BOOL printsFooterSeparator;

/// printInfoのマージンが更新されたことを知らせるフラグ
@property (nonatomic) BOOL readyToDraw;

@end




#pragma mark -

@implementation CEPrintPanelAccessoryController

#pragma mark Superclass Methods

//=======================================================
// Superclass Methods
//
//=======================================================

// ------------------------------------------------------
/// 初期化
- (instancetype)init
// ------------------------------------------------------
{
    self = [super initWithNibName:@"PrintPanelAccessory" bundle:nil];
    if (self) {
        [self updateThemeList];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        // （プリンタ専用フォント設定は含まない。プリンタ専用フォント設定変更は、プリンタダイアログでは実装しない 20060927）
        [self setLineNumberMode:[defaults integerForKey:k_key_printLineNumIndex]];
        [self setInvisibleCharsMode:[defaults integerForKey:k_key_printInvisibleCharIndex]];
        [self setPrintsHeader:[defaults boolForKey:k_key_printHeader]];
        [self setHeaderOneInfoType:[defaults integerForKey:k_key_headerOneStringIndex]];
        [self setHeaderOneAlignmentType:[defaults integerForKey:k_key_headerOneAlignIndex]];
        [self setHeaderTwoInfoType:[defaults integerForKey:k_key_headerTwoStringIndex]];
        [self setHeaderTwoAlignmentType:[defaults integerForKey:k_key_headerTwoAlignIndex]];
        [self setPrintsHeaderSeparator:[defaults boolForKey:k_key_printHeaderSeparator]];
        [self setPrintsFooter:[defaults boolForKey:k_key_printFooter]];
        [self setFooterOneInfoType:[defaults integerForKey:k_key_footerOneStringIndex]];
        [self setFooterOneAlignmentType:[defaults integerForKey:k_key_footerOneAlignIndex]];
        [self setFooterTwoInfoType:[defaults integerForKey:k_key_footerTwoStringIndex]];
        [self setFooterTwoAlignmentType:[defaults integerForKey:k_key_footerTwoAlignIndex]];
        [self setPrintsFooterSeparator:[defaults boolForKey:k_key_printFooterSeparator]];
        
        // テーマを使用する場合はセットしておく
        switch ([defaults integerForKey:k_key_printColorIndex]) {
            case CEBlackColorPrint:
                break;
            case CESameAsDocumentColorPrint:
                [self setTheme:[defaults stringForKey:k_key_defaultTheme]];
                break;
            default:
                [self setTheme:[defaults stringForKey:k_key_printTheme]];
        }
        
        // マージンに関わるキー値を監視する
        for (NSString *key in [self keyPathsForValuesAffectingMargin]) {
            [self addObserver:self forKeyPath:key options:0 context:NULL];
        }
        
        [self updateThemeList];
    }
    return self;
}


// ------------------------------------------------------
/// あとかたづけ
- (void)dealloc
// ------------------------------------------------------
{
    // 監視していたキー値を取り除く
    for (NSString *key in [self keyPathsForValuesAffectingMargin]) {
        [self removeObserver:self forKeyPath:key];
    }
}


// ------------------------------------------------------
/// printInfoがセットされた （新たにプリントシートが表示される）
- (void)setRepresentedObject:(id)representedObject
// ------------------------------------------------------
{
    [super setRepresentedObject:representedObject];
    
    // printInfoの値をヘッダ／フッタのマージンに反映させる
    [self updateVerticalOffset];
    
    // 現在のテーマラインナップを反映させる
    [self updateThemeList];
}


// ------------------------------------------------------
/// 監視しているキー値が変更された
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
// ------------------------------------------------------
{
    if ([[self keyPathsForValuesAffectingMargin] containsObject:keyPath]) {
        [self updateVerticalOffset];
    }
}



#pragma mark Protocol

//=======================================================
// NSPrintPanelAccessorizing Protocol
//
//=======================================================

// ------------------------------------------------------
/// プレビューに影響するキーのセットを返す
- (NSSet *)keyPathsForValuesAffectingPreview
// ------------------------------------------------------
{
    return [NSSet setWithArray:@[@"theme",
                                 @"lineNumberMode",
                                 @"invisibleCharsMode",
                                 @"printsHeader",
                                 @"headerOneAlignmentType",
                                 @"headerTwoAlignmentType",
                                 @"footerOneAlignmentType",
                                 @"footerTwoAlignmentType",
                                 
                                 // ヘッダ／フッタの設定に合わせてprintInfoのマージンを書き換えるため、
                                 // 直接設定の変更を監視するのではなくマージンの書き換え完了フラグを監視する
                                 @"readyToDraw"
                                 ]];
}


// ------------------------------------------------------
/// ローカライズ済みの設定説明を返す
-(NSArray *)localizedSummaryItems
// ------------------------------------------------------
{
    // 現時点ではこのアクセサリビューでの設定値はプリントパネルにあるプリセットに対応していない (2014-03-29 1024jp)
    // (ただし、リストに表示はされる)
    // プリセットにアプリケーション独自の設定を保存するためには、KVOに準拠しつつ[printInfo printSettings]で全ての値を管理する必要がある。
    
    NSMutableArray *items = [NSMutableArray array];
    NSString *description = @"";
    
    [items addObject:[self localizedSummaryItemWithName:@"Color"
                                            description:[self theme]]];
    
    switch ([self lineNumberMode]) {
        case CENoLinePrint:
            description = @"Don't Print";
            break;
        case CESameAsDocumentLinePrint:
            description = @"Same as Document's Setting";
            break;
        case CEDoLinePrint:
            description = @"Print";
            break;
    }
    [items addObject:[self localizedSummaryItemWithName:@"Line Number"
                                            description:description]];
    
    switch ([self invisibleCharsMode]) {
        case CENoInvisibleCharsPrint:
            description = @"Don't Print";
            break;
        case CESameAsDocumentInvisibleCharsPrint:
            description = @"Same as Document's Setting";
            break;
        case CEAllInvisibleCharsPrint:
            description = @"Print All";
            break;
    }
    [items addObject:[self localizedSummaryItemWithName:@"Invisible Characters"
                                            description:description]];
    
    [items addObject:[self localizedSummaryItemWithName:@"Header Footer"
                                            description:([self printsHeader] ? @"On" : @"Off")]];
    
    if ([self printsHeader]) {
        [items addObject:[self localizedSummaryItemWithName:@"Header Line 1"
                                                description:[self printInfoDescription:[self headerOneInfoType]]]];
        [items addObject:[self localizedSummaryItemWithName:@"Header Line 1 Alignment"
                                                description:[self alignmentDescription:[self headerOneAlignmentType]]]];
        [items addObject:[self localizedSummaryItemWithName:@"Header Line 2"
                                                description:[self printInfoDescription:[self headerTwoInfoType]]]];
        [items addObject:[self localizedSummaryItemWithName:@"Header Line 2 Alignment"
                                                description:[self alignmentDescription:[self headerTwoAlignmentType]]]];
    }
    [items addObject:[self localizedSummaryItemWithName:@"Print Header Separator"
                                            description:([self printsHeaderSeparator] ? @"On" : @"Off")]];
    
    [items addObject:[self localizedSummaryItemWithName:@"Print Footer"
                                            description:([self printsFooter] ? @"On" : @"Off")]];
    if ([self printsFooter]) {
        [items addObject:[self localizedSummaryItemWithName:@"Footer Line 1"
                                                description:[self printInfoDescription:[self footerOneInfoType]]]];
        [items addObject:[self localizedSummaryItemWithName:@"Footer Line 1 Alignment"
                                                description:[self alignmentDescription:[self footerOneAlignmentType]]]];
        [items addObject:[self localizedSummaryItemWithName:@"Footer Line 2"
                                                description:[self printInfoDescription:[self footerTwoInfoType]]]];
        [items addObject:[self localizedSummaryItemWithName:@"Footer Line 2 Alignment"
                                                description:[self alignmentDescription:[self footerTwoAlignmentType]]]];
    }
    [items addObject:[self localizedSummaryItemWithName:@"Print Footer Separator"
                                            description:([self printsFooterSeparator] ? @"On" : @"Off")]];
    
    return items;
}



#pragma mark Private Methods

//=======================================================
// Private method
//
//=======================================================

// ------------------------------------------------------
/// localizedSummaryItems で返す辞書を生成
- (NSDictionary *)localizedSummaryItemWithName:(NSString *)name description:(NSString *)description
// ------------------------------------------------------
{
    return @{NSPrintPanelAccessorySummaryItemNameKey: NSLocalizedStringFromTable(name, k_printLocalizeTable, nil),
             NSPrintPanelAccessorySummaryItemDescriptionKey: NSLocalizedStringFromTable(description, k_printLocalizeTable, nil)};
}


// ------------------------------------------------------
/// マージンを再計算する
- (void)updateVerticalOffset
// ------------------------------------------------------
{
    // ヘッダの高さ（文書を印刷しない高さ）を得る
    CGFloat headerHeight = 0;
    if ([self printsHeader]) {
        if ([self headerOneInfoType] != CENoPrintInfo) {
            headerHeight += k_headerFooterLineHeight;
        }
        if ([self headerTwoInfoType] != CENoPrintInfo) {
            headerHeight += k_headerFooterLineHeight;
        }
    }
    // ヘッダと本文との距離をセパレータも勘案して決定する（フッタは本文との間が開くことが多いため、入れない）
    if (headerHeight > 0) {
        headerHeight += (CGFloat)[[NSUserDefaults standardUserDefaults] doubleForKey:k_key_headerFooterFontSize] - k_headerFooterLineHeight;
        
        headerHeight += [self printsHeaderSeparator] ? k_separatorPadding : k_noSeparatorPadding;
    } else {
        if ([self printsHeaderSeparator]) {
            headerHeight += k_separatorPadding;
        }
    }
    
    // フッタの高さ（同）を得る
    CGFloat footerHeight = 0;
    if ([self printsFooter]) {
        if ([self footerOneInfoType] != CENoPrintInfo) {
            footerHeight += k_headerFooterLineHeight;
        }
        if ([self footerTwoInfoType] != CENoPrintInfo) {
            footerHeight += k_headerFooterLineHeight;
        }
    }
    if ((footerHeight == 0) && [self printsFooterSeparator]) {
        footerHeight += k_separatorPadding;
    }
    
    // printView が flip しているので入れ替えている
    NSPrintInfo *printInfo = [self representedObject];
    [printInfo setTopMargin:k_printHFVerticalMargin + footerHeight];
    [printInfo setBottomMargin:k_printHFVerticalMargin + headerHeight];
    
    // プレビューの更新を依頼
    [self setReadyToDraw:YES];
}


// ------------------------------------------------------
/// ヘッダー／フッターの表示情報タイプから文字列を返す
- (NSString *)printInfoDescription:(CEPrintInfoType)type
// ------------------------------------------------------
{
    switch (type) {
        case CENoPrintInfo:
            return @"None";
        
        case CESyntaxNamePrintInfo:
            return @"Syntax Name";
            
        case CEDocumentNamePrintInfo:
            return @"Document Name";
            
        case CEFilePathPrintInfo:
            return @"File Path";
            
        case CEPrintDatePrintInfo:
            return @"Print Date";
            
        case CEPageNumberPrintInfo:
            return @"Page Number";
    }
}


// ------------------------------------------------------
/// 行揃えタイプから文字列を返す
- (NSString *)alignmentDescription:(CEAlignmentType)type
// ------------------------------------------------------
{
    switch (type) {
        case CEAlignLeft:
            return @"Left";
            
        case CEAlignCenter:
            return @"Center";
            
        case CEAlignRight:
            return @"Right";
    }
}


// ------------------------------------------------------
/// マージンに影響するキーのセットを返す
- (NSSet *)keyPathsForValuesAffectingMargin
// ------------------------------------------------------
{
    return [NSSet setWithArray:@[@"printsHeader",
                                 @"headerOneInfoType",
                                 @"headerTwoInfoType",
                                 @"printsHeaderSeparator",
                                 @"printsFooter",
                                 @"footerOneInfoType",
                                 @"footerTwoInfoType",
                                 @"printsFooterSeparator"]];
}


// ------------------------------------------------------
/// テーマの一覧を更新する
- (void)updateThemeList
// ------------------------------------------------------
{
    [[self themePopup] removeAllItems];
    
    [[self themePopup] addItemWithTitle:NSLocalizedString(@"Black and White", nil)];
    
    [[[self themePopup] menu] addItem:[NSMenuItem separatorItem]];
    
    [[self themePopup] addItemWithTitle:NSLocalizedString(@"Theme", nil)];
    [[[self themePopup] itemWithTitle:NSLocalizedString(@"Theme", nil)] setAction:nil];
    
    NSArray *themeNames = [[CEThemeManager sharedManager] themeNames];
    for (NSString *themeName in themeNames) {
        [[self themePopup] addItemWithTitle:themeName];
        [[[self themePopup] lastItem] setIndentationLevel:1];
    }
    
    // 選択すべきテーマがなかったら白黒にする
    if (![themeNames containsObject:[self theme]]) {
        [[self themePopup] selectItemAtIndex:0];
    } else {
        [[self themePopup] selectItemWithTitle:[self theme]];
    }
}

@end
