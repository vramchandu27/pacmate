import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Read signing credentials from key.properties (never committed) ────────────
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

android {
    namespace = "com.pacmate.app"
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
        applicationId = "com.pacmate.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Inject Google Maps key from --dart-define at build time
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

    signingConfigs {
        create("release") {
            if (keyPropertiesFile.exists()) {
                keyAlias     = keyProperties["keyAlias"]     as String
                keyPassword  = keyProperties["keyPassword"]  as String
                storeFile    = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use release keystore when key.properties exists, else debug for local testing
            signingConfig = if (keyPropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")

            // R8 full-mode minification + resource shrinking
            isMinifyEnabled   = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // Disable debug symbols
            isDebuggable = false
        }
        debug {
            isMinifyEnabled   = false
            isShrinkResources = false
            isDebuggable      = true
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
