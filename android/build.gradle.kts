buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Bu versiyalar səndə fərqli ola bilər, olduğu kimi saxla
        classpath("com.android.tools.build:gradle:8.4.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0")

        // BILAL, BU XƏTTİ ƏLAVƏ ET! Firebase Google Servisləri üçün MÜTLƏQDİR.
        classpath("com.google.gms:google-services:4.4.2") // Kotlin DSL sintaksisi
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Bu hissə səndə build.gradle.kts-də var idi, olduğu kimi saxlayırıq:
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}