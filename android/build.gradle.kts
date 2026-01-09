allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    apply(from = "${rootProject.projectDir}/namespace_fix.gradle")
}
subprojects {
    project.evaluationDependsOn(":app")
    
    // Force SDK version for all plugins to fix mismatch errors
    val configureAndroid = {
        val android = project.extensions.findByName("android")
        if (android != null) {
            // Use reflection to avoid import issues with BaseExtension
             try {
                 val method = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                 method.invoke(android, 36)
             } catch (e: Exception) {
                 println("Failed to force compileSdk for ${project.name}: $e")
             }
        }
    }

    if (project.state.executed) {
        configureAndroid()
    } else {
        project.afterEvaluate { configureAndroid() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
