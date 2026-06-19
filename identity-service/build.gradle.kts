plugins {
    kotlin("jvm")
    id("io.ktor.plugin")
}

val ktorVersion = "2.3.11"
val exposedVersion = "0.50.0"

dependencies {
    // Ссылка на нашу общую папку с DTO
    implementation(project(":common"))

    // 1. Веб-фреймворк Ktor (Сервер, Роутинг, JSON, Swagger)
    implementation("io.ktor:ktor-server-core-jvm:$ktorVersion")
    implementation("io.ktor:ktor-server-netty-jvm:$ktorVersion")
    implementation("io.ktor:ktor-server-content-negotiation-jvm:$ktorVersion")
    implementation("io.ktor:ktor-serialization-jackson-jvm:$ktorVersion")
    implementation("io.ktor:ktor-server-swagger-jvm:$ktorVersion")

    // JWT Аутентификация
    implementation("io.ktor:ktor-server-auth-jvm:$ktorVersion")
    implementation("io.ktor:ktor-server-auth-jwt-jvm:$ktorVersion")

    // 2. База данных (Exposed ORM и драйвер PostgreSQL)
    implementation("org.jetbrains.exposed:exposed-core:$exposedVersion")
    implementation("org.jetbrains.exposed:exposed-dao:$exposedVersion")
    implementation("org.jetbrains.exposed:exposed-jdbc:$exposedVersion")
    implementation("org.jetbrains.exposed:exposed-java-time:$exposedVersion")
    implementation("org.postgresql:postgresql:42.7.3")

    // 3. NoSQL (Redis клиент)
    implementation("redis.clients:jedis:5.1.2")

    // Логирование
    implementation("ch.qos.logback:logback-classic:1.5.6")
}

application {
    mainClass.set("ru.corplink.identity.ApplicationKt")
}