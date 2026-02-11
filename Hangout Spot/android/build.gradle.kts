allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Namespace workaround for legacy plugins (blue_thermal_printer)
    afterEvaluate {
        val plugin = project.extensions.findByName("android")
        if (plugin != null) {
            try {
                // Check if namespace is missing using reflection
                val getNamespace = plugin.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespace.invoke(plugin) as String?

                if (currentNamespace == null) {
                    var groupName = project.group.toString()
                    if (groupName.isEmpty() || groupName == "null") {
                         groupName = "com.example.${project.name}"
                    }
                    
                    val validNamespace = groupName.replace("-", "_").replace(" ", "_").lowercase()
                    
                    val setNamespace = plugin.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(plugin, validNamespace)
                    println("Set namespace for ${project.name} to $validNamespace")
                }
            } catch (e: Exception) {
               // Ignore errors, strictly a workaround
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
