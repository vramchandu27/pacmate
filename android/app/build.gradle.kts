import java.util.Base64

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.pacmate"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        
        applicationId = "com.example.pacmate"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as? String)
            ?.split(",")
            ?.associate { entry ->
                val decoded = String(Base64.getDecoder().decode(entry))
                val parts = decoded.split("=", limit = 2)
                parts[0] to (if (parts.size > 1) parts[1] else "")
            } ?: emptyMap<String, String>()

        manifestPlaceholders["GOOGLE_MAPS_KEY"] =
            dartDefines["GOOGLE_MAPS_KEY"] ?: ""
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

// Disable Crashlytics mapping file upload — avoids SSL errors on this machine.
tasks.whenTaskAdded {
    if (name.startsWith("uploadCrashlyticsMappingFile")) enabled = false
}
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}