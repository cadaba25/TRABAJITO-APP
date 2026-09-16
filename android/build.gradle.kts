allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ── compileSdk fijado a una plataforma que existe de verdad ────────────────
//
// Por qué hace falta: `flutter.compileSdkVersion` resuelve a la más nueva que
// conozca el Flutter SDK — hoy la 37. Pero el SDK instalado en esta máquina
// tiene la carpeta `android-37.0` (una preview versionada) y Gradle busca
// literalmente `android-37`. La build muere con
// "Failed to find target with hash string 'android-37'", y además muere en un
// plugin (`flutter_secure_storage`), no en la app, así que el mensaje
// despista bastante.
//
// Se fija a 36, que está instalada y es estable.
//
// ESTE BLOQUE VA ANTES de `evaluationDependsOn(":app")` a propósito: ese
// `evaluationDependsOn` obliga a evaluar los subproyectos, y cualquier intento
// de tocar `compileSdk` después falla con "It is too late to set compileSdk"
// o con "Cannot run Project.afterEvaluate when the project is already
// evaluated". El orden aquí no es estético: es lo que hace que funcione.
//
// Cuando exista una plataforma llamada exactamente `android-37`, se puede
// borrar este bloque y volver a `flutter.compileSdkVersion`.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
            compileSdk = 36
        }
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
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
