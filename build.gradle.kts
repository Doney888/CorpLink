plugins {
    kotlin("jvm") version "1.9.23" apply false
    id("io.ktor.plugin") version "2.3.11" apply false
}

allprojects {
    repositories {
        mavenCentral()
    }
}