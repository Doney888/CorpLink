package ru.corplink.chat.service

import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.transactions.transaction
import ru.corplink.chat.database.MessagesTable
import ru.corplink.common.dto.CreateChatRequest
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.util.UUID
import org.jetbrains.exposed.sql.select
import org.jetbrains.exposed.sql.SortOrder

object ChatService {
    private val notificationService: NotificationService = MockNotificationService()
    private val httpClient = HttpClient.newHttpClient()

    fun createChat(request: CreateChatRequest) {
        transaction {
            val sqlQuery = "CALL sp_create_group_chat('${request.creatorId}', '${request.title}', ${request.type}::smallint);"
            exec(sqlQuery)
        }
    }

    fun sendMessage(chatId: UUID, senderId: UUID, text: String): Boolean {
        val verifyUrl = "http://localhost:5001/api/users/$senderId/verify"
        val request = HttpRequest.newBuilder()
            .uri(URI.create(verifyUrl))
            .GET()
            .build()

        return try {
            val response = httpClient.send(request, HttpResponse.BodyHandlers.ofString())

            if (response.statusCode() == 200) {
                transaction {
                    MessagesTable.insert {
                        it[MessagesTable.chatId] = chatId
                        it[MessagesTable.senderId] = senderId
                        it[content] = text
                        it[sentAt] = java.time.LocalDateTime.now()
                    }
                }

                notificationService.sendPushNotification(senderId, "Новое сообщение в чате: $text")
                true
            } else {
                false
            }
        } catch (e: Exception) {
            println("Ошибка межсервисного взаимодействия: ${e.message}")
            false
        }
    }

    fun getMessages(chatId: UUID): List<Map<String, Any>> {
        return transaction {
            MessagesTable.select { MessagesTable.chatId eq chatId }
                .orderBy(MessagesTable.sentAt, SortOrder.DESC)
                .map {
                    mapOf(
                        "id" to it[MessagesTable.id].toString(),
                        "senderId" to it[MessagesTable.senderId].toString(),
                        "content" to it[MessagesTable.content],
                        "sentAt" to it[MessagesTable.sentAt].toString()
                    )
                }
        }
    }
}