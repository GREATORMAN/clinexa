import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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
}

subprojects {
    project.evaluationDependsOn(":app")
}

// CLINEXA_JVM_TARGET_FIX_V9
// Do not rewrite Android JavaCompile tasks here. AGP owns their Android
// bootclasspath. Align each Kotlin task with the Java target already chosen
// by that plugin instead.
gradle.projectsEvaluated {
    subprojects {
        tasks.withType<KotlinCompile>().configureEach {
            val javaTaskName = name.replace("Kotlin", "JavaWithJavac")
            val javaTask = tasks.findByName(javaTaskName) as? JavaCompile
            val javaTarget = javaTask?.targetCompatibility ?: "17"
            val kotlinTarget = when (javaTarget) {
                "1.8", "8" -> JvmTarget.JVM_1_8
                "11" -> JvmTarget.JVM_11
                "17" -> JvmTarget.JVM_17
                "21" -> JvmTarget.JVM_21
                else -> JvmTarget.JVM_17
            }
            compilerOptions {
                jvmTarget.set(kotlinTarget)
            }
        }
    }
}
