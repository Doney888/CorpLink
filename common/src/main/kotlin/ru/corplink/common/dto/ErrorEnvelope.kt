package ru.corplink.common.dto

import java.time.LocalDateTime

data class ErrorEnvelope(
    val errorCode: String,
    val message: String,
    val details: List<String>? = null,
    val timestamp: String = LocalDateTime.now().toString()
)