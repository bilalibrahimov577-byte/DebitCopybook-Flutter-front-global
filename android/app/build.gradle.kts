// Gərəkli Java kitabxanalarını import edirik
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// local.properties faylından versiya məlumatlarını oxumaq üçün funksiya
fun localProperties(): Properties {
    val properties = Properties()
    val localPropertiesFile = project.rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        properties.load(FileInputStream(localPropertiesFile))
    }
    return properties
}

android {
    namespace = "com.bilalibrahimov.borcdefteri"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = "upload"
            keyPassword = "bilal577" // key.properties faylındakı parol
            storeFile = file("upload-keystore.jks") // Faylın adı
            storePassword = "bilal577" // key.properties faylındakı parol
        }
    }


    defaultConfig {
        applicationId = "com.bilalibrahimov.borcdefteri"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = localProperties().getProperty("flutter.versionCode")?.toInt() ?: 1
        versionName = localProperties().getProperty("flutter.versionName")
    }

    buildTypes {
        release {
            // Nəşr versiyası üçün "release" imzasını istifadə etdiyini bildirir
            signingConfig = signingConfigs.getByName("release")

            // Bu sətirlər release versiyasında kodu kiçildir və optimizasiya edir
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Proyektin kitabxanaları (dependencies) buraya əlavə olunur
}