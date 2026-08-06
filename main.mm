#import <UIKit/UIKit.h>
#include "IL2CPP_Resolver.hpp"
#include <fstream>
#include <thread>

// Namespace tanımlamasını ekliyoruz
using namespace IL2CPP;

void ExecuteIl2CppDump() {
    if (!Globals.m_GameFramework) {
        dispatch_async(dispatch_get_main_queue(), ^{
            showNativeAlert(@"Hata", @"Oyun modülü henüz yüklenmedi!");
        });
        return;
    }

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"il2cpp_dump.txt"];
    
    std::ofstream dumpFile([filePath fileSystemRepresentation]);
    if (!dumpFile.is_open()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            showNativeAlert(@"Hata", @"Dump dosyası oluşturulamadı!");
        });
        return;
    }

    dumpFile << "=== IL2CPP Class, Method & Offset Dump ===\n\n";

    size_t size = 0;
    void** assemblies = Functions.m_DomainGetAssemblies(Functions.m_DomainGet(), &size);
    if (!assemblies) {
        dumpFile.close();
        dispatch_async(dispatch_get_main_queue(), ^{
            showNativeAlert(@"Dump Hatası", @"Assembly listesi alınamadı!");
        });
        return;
    }

    int totalClasses = 0;
    int totalMethods = 0;

    for (size_t i = 0; i < size; ++i) {
        void* assembly = assemblies[i];
        if (!assembly) continue;

        void* image = Functions.m_AssembliesGetImage(assembly);
        if (!image) continue;

        const char* imageName = Functions.m_ImageGetName(image);
        int classCount = Functions.m_ImageGetClassCount(image);
        totalClasses += classCount;

        dumpFile << "\n========================================\n";
        dumpFile << "[Assembly: " << (imageName ? imageName : "Unknown") << "]\n";
        dumpFile << "========================================\n";

        for (int j = 0; j < classCount; ++j) {
            void* klass = Functions.m_ImageGetClass(image, j);
            if (!klass) continue;
            
            const char* className = il2cpp_class_get_name((Il2CppClass*)klass);
            const char* classNamespace = il2cpp_class_get_namespace((Il2CppClass*)klass);
            
            dumpFile << "\n  Class: " << (classNamespace && classNamespace[0] ? classNamespace : "") << "." << (className ? className : "Unknown") << "\n";

            void* iter = nullptr;
            while (void* method = Functions.m_ClassGetMethods(klass, &iter)) {
                if (!method) continue;
                totalMethods++;

                const char* methodName = il2cpp_method_get_name((const MethodInfo*)method);
                void* methodPointer = ((MethodInfo*)method)->methodPointer;
                
                uint64_t relativeOffset = 0;
                if (methodPointer && Globals.m_GameFramework) {
                    relativeOffset = (uint64_t)methodPointer - (uint64_t)Globals.m_GameFramework;
                }

                dumpFile << "    - Method: " << (methodName ? methodName : "Unknown") 
                         << " | Addr: " << methodPointer 
                         << " | Offset: 0x" << std::hex << relativeOffset << std::dec << "\n";
            }
        }
    }

    dumpFile.close();

    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *message = [NSString stringWithFormat:@"Dump tamamlandı!\nSınıf: %d | Metot: %d\nKonum: Documents/il2cpp_dump.txt", totalClasses, totalMethods];
        showNativeAlert(@"IL2CPP Dump", message);
    });
}

@interface ImGuiStyleMenuView : UIView
@property (nonatomic, strong) UIView *menuWindow;
@property (nonatomic, strong) UIButton *floatingIcon;
@property (nonatomic, strong) UIButton *dumpButton;
@end

@implementation ImGuiStyleMenuView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        self.menuWindow = [[UIView alloc] initWithFrame:CGRectMake(50, 80, 270, 110)];
        self.menuWindow.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:0.97];
        self.menuWindow.layer.cornerRadius = 16.0;
        self.menuWindow.layer.borderWidth = 1.5;
        self.menuWindow.layer.borderColor = [UIColor colorWithRed:0.30 green:0.60 blue:1.00 alpha:1.0].CGColor;
        self.menuWindow.layer.shadowColor = [UIColor blackColor].CGColor;
        self.menuWindow.layer.shadowOffset = CGSizeMake(0, 8);
        self.menuWindow.layer.shadowOpacity = 0.5;
        self.menuWindow.layer.shadowRadius = 10.0;
        self.menuWindow.clipsToBounds = NO;
        self.menuWindow.hidden = YES;
        [self addSubview:self.menuWindow];

        UIPanGestureRecognizer *menuPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuPan:)];
        [self.menuWindow addGestureRecognizer:menuPan];

        UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 270, 40)];
        titleBar.backgroundColor = [UIColor colorWithRed:0.14 green:0.17 blue:0.22 alpha:1.0];
        
        UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:titleBar.bounds byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight cornerRadii:CGSizeMake(16.0, 16.0)];
        CAShapeLayer *maskLayer = [CAShapeLayer layer];
        maskLayer.path = maskPath.CGPath;
        titleBar.layer.mask = maskLayer;
        [self.menuWindow addSubview:titleBar];

        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, 200, 40)];
        titleLabel.text = @"🐻 IL2CPP Dump Menu";
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = [UIFont boldSystemFontOfSize:13];
        [titleBar addSubview:titleLabel];

        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(230, 8, 24, 24);
        [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor colorWithRed:1.0 green:0.35 blue:0.35 alpha:1.0] forState:UIControlStateNormal];
        closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [closeBtn addTarget:self action:@selector(minimizeMenu) forControlEvents:UIControlEventTouchUpInside];
        [titleBar addSubview:closeBtn];

        self.dumpButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.dumpButton.frame = CGRectMake(18, 56, 234, 38);
        self.dumpButton.backgroundColor = [UIColor colorWithRed:0.20 green:0.60 blue:1.00 alpha:1.0];
        [self.dumpButton setTitle:@"IL2CPP Dump Başlat" forState:UIControlStateNormal];
        [self.dumpButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.dumpButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        self.dumpButton.layer.cornerRadius = 8.0;
        [self.dumpButton addTarget:self action:@selector(dumpButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.menuWindow addSubview:self.dumpButton];

        self.floatingIcon = [UIButton buttonWithType:UIButtonTypeSystem];
        self.floatingIcon.frame = CGRectMake(40, 100, 54, 54);
        self.floatingIcon.backgroundColor = [UIColor colorWithRed:0.10 green:0.10 blue:0.13 alpha:0.92];
        [self.floatingIcon setTitle:@"🐻" forState:UIControlStateNormal];
        self.floatingIcon.titleLabel.font = [UIFont systemFontOfSize:28];
        self.floatingIcon.layer.cornerRadius = 27.0;
        self.floatingIcon.layer.borderWidth = 2.0;
        self.floatingIcon.layer.borderColor = [UIColor colorWithRed:0.30 green:0.60 blue:1.00 alpha:1.0].CGColor;
        self.floatingIcon.layer.shadowColor = [UIColor blackColor].CGColor;
        self.floatingIcon.layer.shadowOffset = CGSizeMake(0, 4);
        self.floatingIcon.layer.shadowOpacity = 0.6;
        self.floatingIcon.layer.shadowRadius = 8.0;
        self.floatingIcon.hidden = NO;
        [self.floatingIcon addTarget:self action:@selector(restoreMenu) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.floatingIcon];

        UIPanGestureRecognizer *iconPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleIconPan:)];
        [self.floatingIcon addGestureRecognizer:iconPan];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self) {
        return nil;
    }
    return hitView;
}

- (void)handleMenuPan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self];
    CGPoint center = gesture.view.center;
    gesture.view.center = CGPointMake(center.x + translation.x, center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self];
}

- (void)handleIconPan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self];
    CGPoint center = gesture.view.center;
    gesture.view.center = CGPointMake(center.x + translation.x, center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self];
}

- (void)minimizeMenu {
    self.menuWindow.hidden = YES;
    self.floatingIcon.center = self.menuWindow.center;
    self.floatingIcon.hidden = NO;
}

- (void)restoreMenu {
    self.floatingIcon.hidden = YES;
    self.menuWindow.center = self.floatingIcon.center;
    self.menuWindow.hidden = NO;
}

- (void)dumpButtonTapped:(UIButton *)sender {
    showNativeAlert(@"IL2CPP Dump", @"Dump işlemi başlatıldı, dosyaya yazılıyor...");
    std::thread(ExecuteIl2CppDump).detach();
}

@end
