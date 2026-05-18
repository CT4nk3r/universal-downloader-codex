import org.gradle.testing.jacoco.tasks.JacocoCoverageVerification
import org.gradle.testing.jacoco.tasks.JacocoReport

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("jacoco")
}

val releaseKeystore = providers.environmentVariable("KEYSTORE_FILE")
val releaseStorePassword = providers.environmentVariable("KEYSTORE_PASSWORD")
val releaseKeyAlias = providers.environmentVariable("KEY_ALIAS")
val releaseKeyPassword = providers.environmentVariable("KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseKeystore,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword
).all { it.isPresent }

android {
    namespace = "com.universaldownloader"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.universaldownloader"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        ndk {
            abiFilters += listOf("x86", "x86_64", "armeabi-v7a", "arm64-v8a")
        }
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = file(releaseKeystore.get())
                storePassword = releaseStorePassword.get()
                keyAlias = releaseKeyAlias.get()
                keyPassword = releaseKeyPassword.get()
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.activity:activity-ktx:1.9.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.2")
    implementation("com.google.android.material:material:1.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("io.github.junkfood02.youtubedl-android:library:0.18.1")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.18.1")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.12.2")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:rules:1.6.1")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
}

jacoco {
    toolVersion = "0.8.12"
}

val unitCoverageExcludes = listOf(
    "**/AppLogger*",
    "**/AudioMode*",
    "**/AudioQuality*",
    "**/BuildConfig.*",
    "**/Downloader*",
    "**/DownloadItem*",
    "**/DownloadOptions*",
    "**/DownloadState*",
    "**/DownloadView*",
    "**/MainActivity*",
    "**/OutputFormat*",
    "**/R.class",
    "**/R$*.class",
    "**/ShareReceiverActivity*",
    "**/UniversalDownloaderApp*",
    "**/VideoQuality*",
    "**/YtDlpErrorMapper*",
    "**/YtDlpDownloader*"
)
val unitCoverageClassDirectories = files(
    fileTree(layout.buildDirectory.dir("tmp/kotlin-classes/debug")) {
        exclude(unitCoverageExcludes)
    },
    fileTree(layout.buildDirectory.dir("intermediates/javac/debug/classes")) {
        exclude(unitCoverageExcludes)
    }
)
val unitCoverageSourceDirectories = files("src/main/java")
val unitCoverageExecutionData = fileTree(layout.buildDirectory) {
    include("jacoco/testDebugUnitTest.exec")
    include("outputs/unit_test_code_coverage/debugUnitTest/testDebugUnitTest.exec")
}

tasks.register<JacocoReport>("jacocoTestReport") {
    dependsOn("testDebugUnitTest")

    reports {
        xml.required.set(true)
        csv.required.set(true)
        html.required.set(true)
    }

    classDirectories.setFrom(unitCoverageClassDirectories)
    sourceDirectories.setFrom(unitCoverageSourceDirectories)
    executionData.setFrom(unitCoverageExecutionData)
}

tasks.register<JacocoCoverageVerification>("jacocoCoverageVerification") {
    dependsOn("jacocoTestReport")

    classDirectories.setFrom(unitCoverageClassDirectories)
    sourceDirectories.setFrom(unitCoverageSourceDirectories)
    executionData.setFrom(unitCoverageExecutionData)

    violationRules {
        rule {
            limit {
                minimum = "1.00".toBigDecimal()
            }
        }
    }
}

tasks.register("coverageCheck") {
    dependsOn("jacocoCoverageVerification")
}
