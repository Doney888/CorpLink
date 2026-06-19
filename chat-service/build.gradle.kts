plugins {
    kotlin("jvm")
    id("io.ktor.plugin")
}

val ktorVersion = "2.3.11"
val exposedVersion = "0.50.0"

dependencies {
    implementation(project(":common"))

    // Ktor
    implementation("io.ktor:ktor-server-core-jvm:$ktorVersion")
    implementation("io.ktor:ktor-server-netty-jvm:$ktorVersion")
    implementation("io.ktor:ktor-server-content-negotiation-jvm:$ktorVersion")
    implementation("io.ktor:ktor-serialization-jackson-jvm:$ktorVersion")
    implementation("io.ktor:ktor-server-swagger-jvm:$ktorVersion")

    // Auth
    implementation("io.ktor:ktor-server-auth-jvm:$ktorVersion")
    implementation("io.ktor:ktor-server-auth-jwt-jvm:$ktorVersion")

    // Database
    implementation("org.jetbrains.exposed:exposed-core:$exposedVersion")
    implementation("org.jetbrains.exposed:exposed-dao:$exposedVersion")
    implementation("org.jetbrains.exposed:exposed-jdbc:$exposedVersion")
    implementation("org.jetbrains.exposed:exposed-java-time:$exposedVersion")
    implementation("org.postgresql:postgresql:42.7.3")

    // Redis
    implementation("redis.clients:jedis:5.1.2")

    // Logging
    implementation("ch.qos.logback:logback-classic:1.5.6")
    implementation(kotlin("stdlib-jdk8"))
}

application {
    mainClass.set("ru.corplink.chat.ApplicationKt")
}
