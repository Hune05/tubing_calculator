import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 🚀 [고침] 배포용 서명. 예전에는 늘 디버그 키로 서명해, 다른 컴퓨터에서 빌드한 앱은
// 서명이 달라 업데이트가 안 되고 지우고 다시 깔아야 했다. android/key.properties가
// 있으면 그 키(한 곳에 보관한 .jks)로 서명한다. 없으면 예전처럼 디버그 키로.
// 만드는 법은 docs/배포_서명_버전.md.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.tubing_calculator"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // 🔥 flutter_local_notifications 최신 버전을 위한 디슈가링 활성화
        isCoreLibraryDesugaringEnabled = true
        
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.tubing_calculator"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        
        // 🔥 FCM 알림 및 최신 패키지들의 안정적인 작동을 위해 최소 SDK를 23으로 변경
        minSdk = flutter.minSdkVersion 
        
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 64비트 폰용만(10-09, 사용자 결정): 32비트 폰·PC 에뮬레이터용 부품을 빼서 약 27MB 줄인다.
            // 아주 오래된 32비트 폰에는 설치되지 않는다. 디버그 빌드는 그대로(에뮬레이터용).
            ndk {
                abiFilters += listOf("arm64-v8a")
            }
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 🔥 [수정됨] 에러에서 요구한 대로 2.1.4 버전으로 올림!
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // 🔥 구글 ML Kit 스캐너 언어팩 추가 (R8 빌드 에러 해결용) 🔥
    // 출퇴근 위젯 단추가 앱을 열지 않고 근태를 적을 때 쓴다(ClockPunch.kt). 버전은 firebase_core 플러그인과 같은 BoM.
    implementation(platform("com.google.firebase:firebase-bom:34.9.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")

    implementation("com.google.mlkit:text-recognition-korean:16.0.0")
    implementation("com.google.mlkit:text-recognition-chinese:16.0.0")
    implementation("com.google.mlkit:text-recognition-japanese:16.0.0")
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.0")
}
