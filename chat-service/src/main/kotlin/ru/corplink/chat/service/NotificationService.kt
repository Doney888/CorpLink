package ru.corplink.chat.service

import java.util.UUID

interface NotificationService {
    fun sendPushNotification(recipientId: UUID, messageText: String)
}

class MockNotificationService : NotificationService {
    override fun sendPushNotification(recipientId: UUID, messageText: String) {
        println("[MOCK NOTIFICATION] Отправка PUSH для пользователя $recipientId: \"$messageText\"")
    }
}