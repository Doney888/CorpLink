package ru.corplink.common.dto

data class SendMessageRequest(
    val senderId: String = "",
    val content: String = ""
)