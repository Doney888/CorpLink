package ru.corplink.chat

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
import ru.corplink.common.dto.CreateChatRequest
import ru.corplink.chat.service.ChatService
import ru.corplink.common.dto.SendMessageRequest


fun main() {
    embeddedServer(Netty, port = 5002, host = "0.0.0.0", module = Application::chatModule)
        .start(wait = true)
}

fun Application.chatModule() {
    try {
        DatabaseFactory.init()
        log.info("Chat Service успешно подключен к PostgreSQL")
    } catch (e: Exception) {
        log.error("Ошибка подключения к PostgreSQL: ${e.message}")
    }

    install(ContentNegotiation) {
        jackson {}
    }

    routing {
        get("/api/health") {
            call.respond(mapOf("status" to "ok", "service" to "chat-service"))
        }

        post("/api/chats") {
            try {
                val request = call.receive<CreateChatRequest>()

                ChatService.createChat(request)

                call.respond(HttpStatusCode.Created, mapOf(
                    "message" to "Групповой чат успешно создан через хранимую процедуру Postgres!",
                    "title" to request.title
                ))
            } catch (e: Exception) {
                call.respond(HttpStatusCode.InternalServerError, mapOf("error" to e.message))
            }
        }

        post("/api/chats/{chatId}/messages") {
            try {
                val chatIdStr = call.parameters["chatId"]
                if (chatIdStr.isNullOrBlank()) {
                    call.respond(HttpStatusCode.BadRequest, mapOf("error" to "Не указан ID чата"))
                    return@post
                }

                val chatId = java.util.UUID.fromString(chatIdStr)
                val request = call.receive<SendMessageRequest>()

                val senderId = java.util.UUID.fromString(request.senderId)

                val success = ChatService.sendMessage(chatId, senderId, request.content)

                if (success) {
                    call.respond(HttpStatusCode.Created, mapOf(
                        "message" to "Сообщение успешно доставлено и записано!",
                        "content" to request.content
                    ))
                } else {
                    call.respond(HttpStatusCode.BadRequest, mapOf("error" to "Верификация автора не пройдена (пользователь не существует)"))
                }
            } catch (e: Exception) {
                call.respond(HttpStatusCode.InternalServerError, mapOf("error" to e.message))
            }
        }

        get("/api/chats/{chatId}/messages") {
            try {
                val chatIdStr = call.parameters["chatId"]
                if (chatIdStr.isNullOrBlank()) {
                    call.respond(HttpStatusCode.BadRequest, mapOf("error" to "Не указан ID чата"))
                    return@get
                }

                val chatId = java.util.UUID.fromString(chatIdStr)
                val messages = ChatService.getMessages(chatId)

                call.respond(HttpStatusCode.OK, messages)
            } catch (e: Exception) {
                call.respond(HttpStatusCode.InternalServerError, mapOf("error" to e.message))
            }
        }
    }
}