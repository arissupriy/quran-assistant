import org.gradle.api.tasks.Copy
import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.quran_assistant"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.13599879"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.quran_assistant"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Build only 64-bit ABIs to avoid armeabi-v7a issues with whisper-rs-sys
        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Ensure libc++_shared.so is packaged; some Rust deps (e.g., whisper/ggml) link against it
    packaging {
        jniLibs {
            // In case multiple plugins bring libc++_shared, prefer the first
            pickFirsts += listOf("**/libc++_shared.so")
        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }
}

flutter {
    source = "../.."
}

// Copy libc++_shared.so from the NDK into src/main/jniLibs for required ABIs
val copyLibcxxShared by tasks.registering(Copy::class) {
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
    val sdkDir = File(project.rootProject.projectDir, "local.properties").let { propsFile ->
        val props = Properties()
        propsFile.inputStream().use { props.load(it) }
        File(props.getProperty("sdk.dir"))
    }
    val ndkVersion = android.ndkVersion
    val ndkDir = File(sdkDir, "ndk").resolve(ndkVersion)
    val prebuiltHost = "linux-x86_64"

    val mappings = mapOf(
        "arm64-v8a" to "aarch64-linux-android",
        "x86_64" to "x86_64-linux-android"
    )

    val jniLibsRoot = file("src/main/jniLibs")
    into(jniLibsRoot)
    mappings.forEach { (abi, triple) ->
        val src = ndkDir.resolve("toolchains/llvm/prebuilt/${prebuiltHost}/sysroot/usr/lib/${triple}/libc++_shared.so")
        if (src.exists()) {
            from(src) {
                into(abi)
            }
        }
    }
}

tasks.matching { it.name.startsWith("preDebugBuild") || it.name.startsWith("preReleaseBuild") }.configureEach {
    dependsOn(copyLibcxxShared)
}
