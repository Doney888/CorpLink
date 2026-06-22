package ru.corplink.identity

import io.ktor.http.*
import io.ktor.serialization.jackson.*
import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import io.ktor.server.plugins.contentnegotiation.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import ru.corplink.common.database.DatabaseFactory
import ru.corplink.common.dto.RegisterUserRequest
import ru.corplink.identity.service.UserService
import ru.corplink.common.dto.LoginRequest
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
import io.ktor.server.plugins.swagger.*

fun main() {
    embeddedServer(Netty, port = 5001, host = "0.0.0.0", module = Application::identityModule)
        .start(wait = true)
}

fun Application.identityModule() {
    try {
        DatabaseFactory.init()
        log.info("Успешное подключение к PostgreSQL")
    } catch (e: Exception) {
        log.error("Ошибка подключения к PostgreSQL: ${e.message}")
    }

    install(ContentNegotiation) {
        jackson {}
    }

    routing {

        swaggerUI(path = "swagger", swaggerFile = "openapi.yaml")

        get("/api/health") {
            call.respond(mapOf("status" to "ok", "service" to "identity-service"))
        }

        post("/api/auth/register") {
            try {
                val request = call.receive<RegisterUserRequest>()

                val newUser = UserService.register(request)

                if (newUser != null) {
                    call.respond(HttpStatusCode.Created, newUser)
                } else {
                    call.respond(HttpStatusCode.BadRequest, mapOf("error" to "Не удалось зарегистрировать пользователя"))
                }
            } catch (e: Exception) {
                call.respond(HttpStatusCode.InternalServerError, mapOf("error" to e.message))
            }
        }

        post("/api/auth/login") {
            try {
                val request = call.receive<LoginRequest>()
                val user = UserService.login(request)

                if (user != null) {
                    val mockToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.user_id_${user.id}"

                    call.respond(HttpStatusCode.OK, mapOf(
                        "accessToken" to mockToken,
                        "user" to user
                    ))
                } else {
                    call.respond(HttpStatusCode.Unauthorized, mapOf("error" to "Неверный email или пароль"))
                }
            } catch (e: Exception) {
                call.respond(HttpStatusCode.InternalServerError, mapOf("error" to e.message))
            }
        }

        get("/api/users/{id}/verify") {
            val userIdStr = call.parameters["id"]
            if (userIdStr.isNullOrBlank()) {
                call.respond(HttpStatusCode.BadRequest, mapOf("error" to "Не указан ID пользователя"))
                return@get
            }

            try {
                val userId = java.util.UUID.fromString(userIdStr)
                val userExists = org.jetbrains.exposed.sql.transactions.transaction {
                    ru.corplink.identity.database.UsersTable
                        .selectAll()
                        .where { ru.corplink.identity.database.UsersTable.id eq userId }
                        .any()
                }

                if (userExists) {
                    call.respond(HttpStatusCode.OK, mapOf("exists" to true, "userId" to userIdStr))
                } else {
                    call.respond(HttpStatusCode.NotFound, mapOf("exists" to false, "error" to "Пользователь не найден"))
                }
            } catch (e: Exception) {
                call.respond(HttpStatusCode.BadRequest, mapOf("error" to "Неверный формат UUID"))
            }
        }
    }
}