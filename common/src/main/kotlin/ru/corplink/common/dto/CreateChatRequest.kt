package ru.corplink.common.dto

import java.util.UUID

data class CreateChatRequest(
    val creatorId: UUID,
    val title: String,
    val type: Short
)