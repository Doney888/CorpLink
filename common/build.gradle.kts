plugins {
    kotlin("jvm")
}

val exposedVersion = "0.50.0"

dependencies {
    implementation("com.fasterxml.jackson.core:jackson-annotations:2.17.1")

    implementation("org.jetbrains.exposed:exposed-core:$exposedVersion")
    implementation("org.jetbrains.exposed:exposed-jdbc:$exposedVersion")
    implementation("org.postgresql:postgresql:42.7.3")

    implementation("com.zaxxer:HikariCP:5.1.0")
}