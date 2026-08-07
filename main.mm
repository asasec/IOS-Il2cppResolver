#import <UIKit/UIKit.h>
#include "IL2CPP_Resolver.hpp"
#include <fstream>
#include <thread>
#include <dlfcn.h>

using namespace IL2CPP;

// Tip Tanımları
typedef void* (*DomainGet_t)();
typedef void** (*DomainGetAssemblies_t)(void* domain, size_t* size);
typedef void* (*AssembliesGetImage_t)(void* assembly);
typedef const char* (*ImageGetName_t)(void* image);
typedef int (*ImageGetClassCount_t)(void* image);
typedef void* (*ImageGetClass_t)(void* image, int index);
typedef void* (*ClassGetMethods_t)(void* klass, void** iter);

typedef const char* (*il2cpp_class_get_name_t)(void* klass);
typedef const char* (*il2cpp_class_get_namespace_t)(void* klass);
typedef const char* (*il2cpp_method_get_name_t)(void* method);

void showNativeAlert(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
        
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *win in scene.windows) {
                        if (win.isKeyWindow) {
                            window = win;
                            break;
                        }
                    }
                }
            }
        }
        if (!window) {
            window = [UIApplication sharedApplication].windows.firstObject;
        }
        [window.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}

void shareDumpFile(NSString *filePath) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
        
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *win in scene.windows) {
                        if (win.isKeyWindow) {
                            window = win;
                            break;
                        }
                    }
                }
            }
        }
        if (!window) {
            window = [UIApplication sharedApplication].windows.firstObject;
        }
        
        UIViewController *rootVC = window.rootViewController;
        if (activityVC.popoverPresentationController) {
            activityVC.popoverPresentationController.sourceView = rootVC.view;
            activityVC.popoverPresentationController.sourceRect = CGRectMake(rootVC.view.bounds.size.width / 2, rootVC.view.bounds.size.height / 2, 0, 0);
            activityVC.popoverPresentationController.permittedArrowDirections = 0;
        }
        [rootVC presentViewController:activityVC animated:YES completion:nil];
    });
}

void ExecuteIl2CppDump() {
    @try {
        if (!Globals.m_GameFramework) {
            dispatch_async(dispatch_get_main_queue(), ^{
                showNativeAlert(@"Hata", @"Oyun modülü yüklenmedi!");
            });
            return;
        }

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths firstObject];
        NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"il2cpp_dump.txt"];
        
        std::ofstream dumpFile([filePath UTF8String], std::ios::out | std::ios::trunc);
        if (!dumpFile.is_open()) {
            dispatch_async(dispatch_get_main_queue(), ^{
                showNativeAlert(@"Kayıt Hatası", [NSString stringWithFormat:@"Documents dizinine yazılamadı:\n%@", filePath]);
            });
            return;
        }

        dumpFile << "=== IL2CPP Class, Method & Offset Dump ===\n\n";

        DomainGet_t f_DomainGet = (DomainGet_t)Functions.m_DomainGet;
        DomainGetAssemblies_t f_DomainGetAssemblies = (DomainGetAssemblies_t)Functions.m_DomainGetAssemblies;
        AssembliesGetImage_t f_AssembliesGetImage = (AssembliesGetImage_t)Functions.m_AssembliesGetImage;
        ImageGetName_t f_ImageGetName = (ImageGetName_t)Functions.m_ImageGetName;
        ImageGetClassCount_t f_ImageGetClassCount = (ImageGetClassCount_t)Functions.m_ImageGetClassCount;
        ImageGetClass_t f_ImageGetClass = (ImageGetClass_t)Functions.m_ImageGetClass;
        ClassGetMethods_t f_ClassGetMethods = (ClassGetMethods_t)Functions.m_ClassGetMethods;

        il2cpp_class_get_name_t f_ClassName = (il2cpp_class_get_name_t)dlsym(Globals.m_GameFramework, "il2cpp_class_get_name");
        il2cpp_class_get_namespace_t f_ClassNamespace = (il2cpp_class_get_namespace_t)dlsym(Globals.m_GameFramework, "il2cpp_class_get_namespace");
        il2cpp_method_get_name_t f_MethodName = (il2cpp_method_get_name_t)dlsym(Globals.m_GameFramework, "il2cpp_method_get_name");

        void* domain = f_DomainGet();
        size_t size = 0;
        void** assemblies = f_DomainGetAssemblies(domain, &size);
        if (!assemblies || size == 0) {
            dumpFile.close();
            dispatch_async(dispatch_get_main_queue(), ^{
                showNativeAlert(@"Dump Hatası", @"Assembly listesi alınamadı!");
            });
            return;
        }

        int totalClasses = 0;
        int totalMethods = 0;
        uint64_t baseAddress = (uint64_t)Globals.m_GameFramework;

        for (size_t i = 0; i < size; ++i) {
            void* assembly = assemblies[i];
            if (!assembly) continue;

            void* image = f_AssembliesGetImage ? f_AssembliesGetImage(assembly) : nullptr;
            if (!image) continue;

            const char* imageName = f_ImageGetName ? f_ImageGetName(image) : "Unknown";
            int classCount = f_ImageGetClassCount ? f_ImageGetClassCount(image) : 0;
            totalClasses += classCount;

            dumpFile << "\n========================================\n";
            dumpFile << "[Assembly: " << (imageName ? imageName : "Unknown") << "]\n";
            dumpFile << "========================================\n";

            for (int j = 0; j < classCount; ++j) {
                void* klass = f_ImageGetClass ? f_ImageGetClass(image, j) : nullptr;
                if (!klass) continue;
                
                const char* className = f_ClassName ? f_ClassName(klass) : "Unknown";
                const char* classNamespace = f_ClassNamespace ? f_ClassNamespace(klass) : "";
                
                dumpFile << "\n  Class: " << (classNamespace && classNamespace[0] ? classNamespace : "") << "." << (className ? className : "Unknown") << "\n";

                void* iter = nullptr;
                while (void* method = f_ClassGetMethods ? f_ClassGetMethods(klass, &iter) : nullptr) {
                    if (!method) continue;
                    totalMethods++;

                    const char* methodName = f_MethodName ? f_MethodName(method) : "Unknown";
                    
                    struct MethodInfo_Internal {
                        void* methodPointer;
                        void* invoker_pointer;
                        const char* name;
                        void* klass;
                        void* return_type;
                        void* parameters;
                    };
                    
                    uint64_t methodPointer = (uint64_t)((MethodInfo_Internal*)method)->methodPointer;
                    uint64_t relativeOffset = 0;
                    if (methodPointer > baseAddress) {
                        relativeOffset = methodPointer - baseAddress;
                    }

                    dumpFile << "    - Method: " << (methodName ? methodName : "Unknown") 
                             << " | Addr: 0x" << std::hex << methodPointer 
                             << " | Offset: 0x" << relativeOffset << std::dec << "\n";
                }
            }
        }

        dumpFile.flush();
        dumpFile.close();

        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IL2CPP Dump Bitti"
                                                                            message:[NSString stringWithFormat:@"Sınıf: %d | Metot: %d\nDosya Documents klasörüne kaydedildi.", totalClasses, totalMethods]
                                                                     preferredStyle:UIAlertControllerStyleAlert];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"Dosyalara Kaydet (Paylaş)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                shareDumpFile(filePath);
            }]];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleCancel handler:nil]];
            
            UIWindow *window = nil;
            if (@available(iOS 13.0, *)) {
                for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if (scene.activationState == UISceneActivationStateForegroundActive) {
                        for (UIWindow *win in scene.windows) {
                            if (win.isKeyWindow) {
                                window = win;
                                break;
                            }
                        }
                    }
                }
            }
            if (!window) {
                window = [UIApplication sharedApplication].windows.firstObject;
            }
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    }
    @catch (NSException *exception) {
        dispatch_async(dispatch_get_main_queue(), ^{
            showNativeAlert(@"Hata", [NSString stringWithFormat:@"Exception: %@", exception.reason]);
        });
    }
}

@interface ImGuiStyleMenuView : UIView
@property (nonatomic, strong) UIView *mobileMenuWindow;
@property (nonatomic, strong) UIButton *floatingIcon;
@property (nonatomic, strong) UIButton *dumpButton;
@end

@implementation ImGuiStyleMenuView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        self.mobileMenuWindow = [[UIView alloc] initWithFrame:CGRectMake(50, 80, 270, 110)];
        self.mobileMenuWindow.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:0.97];
        self.mobileMenuWindow.layer.cornerRadius = 16.0;
        self.mobileMenuWindow.layer.borderWidth = 1.5;
        self.mobileMenuWindow.layer.borderColor = [UIColor colorWithRed:0.30 green:0.60 blue:1.00 alpha:1.0].CGColor;
        self.mobileMenuWindow.layer.shadowColor = [UIColor blackColor].CGColor;
        self.mobileMenuWindow.layer.shadowOffset = CGSizeMake(0, 8);
        self.mobileMenuWindow.layer.shadowOpacity = 0.5;
        self.mobileMenuWindow.layer.shadowRadius = 10.0;
        self.mobileMenuWindow.clipsToBounds = NO;
        self.mobileMenuWindow.hidden = YES;
        [self addSubview:self.mobileMenuWindow];

        UIPanGestureRecognizer *menuPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuPan:)];
        [self.mobileMenuWindow addGestureRecognizer:menuPan];

        UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 270, 40)];
        titleBar.backgroundColor = [UIColor colorWithRed:0.14 green:0.17 blue:0.22 alpha:1.0];
        
        UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:titleBar.bounds byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight cornerRadii:CGSizeMake(16.0, 16.0)];
        CAShapeLayer *maskLayer = [CAShapeLayer layer];
        maskLayer.path = maskPath.CGPath;
        titleBar.layer.mask = maskLayer;
        [self.mobileMenuWindow addSubview:titleBar];

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
        [self.mobileMenuWindow addSubview:self.dumpButton];

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

        // HATA BURADAYDI: @selector:handleIconPan: yerine @selector(handleIconPan:) yapıldı
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
    self.mobileMenuWindow.hidden = YES;
    self.floatingIcon.center = self.mobileMenuWindow.center;
    self.floatingIcon.hidden = NO;
}

- (void)restoreMenu {
    self.floatingIcon.hidden = YES;
    self.mobileMenuWindow.center = self.floatingIcon.center;
    self.mobileMenuWindow.hidden = NO;
}

- (void)dumpButtonTapped:(UIButton *)sender {
    showNativeAlert(@"IL2CPP Dump", @"Dump işlemi başlatıldı, arka planda dosyaya yazılıyor...");
    std::thread(ExecuteIl2CppDump).detach();
}

@end

__attribute__((constructor)) void initializeDumpMenu() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSBundle *bundle = [NSBundle mainBundle];
        NSString *frameworkPath = [[bundle.bundlePath stringByAppendingPathComponent:@"Frameworks/UnityFramework.framework/UnityFramework"] stringByStandardizingPath];
        
        bool initSuccess = IL2CPP::Initialize(true, 40, [frameworkPath UTF8String]);
        if (!initSuccess) {
            initSuccess = IL2CPP::Initialize(true, 10, "UnityFramework");
        }

        if (!initSuccess) {
            showNativeAlert(@"Resolver Hatası", @"UnityFramework yüklenemedi!");
            return;
        }

        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *win in scene.windows) {
                        if (win.isKeyWindow) {
                            window = win;
                            break;
                        }
                    }
                }
            }
        }
        if (!window) {
            window = [UIApplication sharedApplication].windows.firstObject;
        }
        
        if (window) {
            ImGuiStyleMenuView *menuView = [[ImGuiStyleMenuView alloc] initWithFrame:window.bounds];
            menuView.userInteractionEnabled = YES;
            [window addSubview:menuView];
        }
    });
}
